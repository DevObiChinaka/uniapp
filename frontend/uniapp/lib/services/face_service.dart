import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/app_constants.dart';

class FaceService {
  final Dio _dio = Dio();
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  final _operationLock = _AsyncLock();

  Future<void> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  Future<void> initialize() async {
    await _ensureCameraPermission();
    if (_isInitialized) return;
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      _cameras = await availableCameras();
      await _initializeCameraController();
      _isInitialized = true;
      _initCompleter!.complete();
      debugPrint('FaceService initialized');
    } on PlatformException catch (e) {
      debugPrint('Platform error during initialization: $e');
      _initCompleter!.completeError(e);
      throw SystemException('Camera initialization failed: ${e.message}');
    } catch (e) {
      debugPrint('Initialization error: $e');
      _initCompleter!.completeError(e);
      throw AppException('FaceService initialization failed');
    }
  }

  Future<String?> registerFace() async {
    return _operationLock.run(() async {
      await _ensureInitialized();
      try {
        final image = await _captureImage();
        final faces = await _detectFaces(image);
        final face = _validateSingleFace(faces);

        if (AppConstants.enableLivenessCheck) {
          final isLive = await _checkLiveness();
          if (!isLive) throw LivenessException('Liveness check failed');
        }

        return face.faceId;
      } on FaceException catch (e) {
        debugPrint('Face registration failed: $e');
        return null;
      }
    });
  }

  Future<FaceVerificationResult> verifyFace(String faceId) async {
    return _operationLock.run(() async {
      await _ensureInitialized();
      try {
        final image = await _captureImage();
        final faces = await _detectFaces(image);
        if (faces.isEmpty) return _verificationFailure('No face detected');

        final result = await _verifyWithAzure(faceId, faces.first.faceId!);

        return FaceVerificationResult(
          isIdentical: result['isIdentical'] ?? false,
          confidence: (result['confidence'] ?? 0).toDouble(),
          message:
              result['isIdentical'] == true
                  ? 'Verification successful'
                  : 'Face mismatch',
        );
      } on FaceException catch (e) {
        return _verificationFailure('Verification error: ${e.message}');
      } catch (e) {
        debugPrint('Unexpected verification error: $e');
        return _verificationFailure('System error');
      }
    });
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      if (_initCompleter != null) {
        await _initCompleter!.future;
      } else {
        await initialize();
      }
    }
  }

  Future<List<DetectedFace>> _detectFaces(Uint8List imageBytes) async {
    try {
      // Using the full endpoint with the face/v1.0 path
      final url = '${AppConstants.faceApiEndpoint}face/v1.0/detect';
      final response = await _dio.post(
        url,
        data: Stream.fromIterable(imageBytes.map((b) => [b])),
        options: Options(
          headers: {
            'Ocp-Apim-Subscription-Key': AppConstants.faceApiKey1,
            'Content-Type': 'application/octet-stream',
          },
        ),
        queryParameters: {
          'returnFaceId': 'true',
          'returnFaceLandmarks': 'false',
          'returnFaceAttributes': AppConstants.faceDetectionAttributes,
          'recognitionModel': 'recognition_04',
          'detectionModel': 'detection_03',
        },
      );
      final data = response.data as List;
      return data.map((json) => DetectedFace.fromJson(json)).toList();
    } on DioException catch (e) {
      debugPrint('Face detection error: ${e.message}');
      throw FaceException('Detection service error');
    }
  }

  Future<Map<String, dynamic>> _verifyWithAzure(
    String faceId1,
    String faceId2,
  ) async {
    final url = '${AppConstants.faceApiEndpoint}face/v1.0/verify';
    try {
      final response = await _dio.post(
        url,
        data: {
          'faceId1': faceId1, 
          'faceId2': faceId2,
          'recognitionModel': 'recognition_04'
        },
        options: Options(
          headers: {
            'Ocp-Apim-Subscription-Key': AppConstants.faceApiKey1,
            'Content-Type': 'application/json',
          },
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('Face verify error: ${e.message}');
      throw FaceException('Verification service error');
    }
  }

  DetectedFace _validateSingleFace(List<DetectedFace> faces) {
    if (faces.isEmpty) throw FaceException('No faces detected');
    if (faces.length > 1) throw FaceException('Multiple faces detected');
    return faces.first;
  }

  FaceVerificationResult _verificationFailure(String message) {
    return FaceVerificationResult(
      isIdentical: false,
      confidence: 0,
      message: message,
    );
  }

  Future<bool> _checkLiveness() async {
    final List<InputImage> images = [];
    for (int i = 0; i < 3; i++) {
      final bytes = await _captureImage();
      final filePath = await _saveToTempFile(bytes);
      images.add(InputImage.fromFilePath(filePath));
      await Future.delayed(const Duration(milliseconds: 700));
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true,
        enableClassification: true,
      ),
    );

    final dynamics = <double>[];
    for (final image in images) {
      final faces = await detector.processImage(image);
      if (faces.isEmpty) return false;
      final face = faces.first;
      dynamics.add(face.leftEyeOpenProbability ?? 0);
      dynamics.add(face.rightEyeOpenProbability ?? 0);
      dynamics.add(face.headEulerAngleY ?? 0);
    }

    final eyeVariance =
        (dynamics[0] - dynamics[2]).abs() + (dynamics[1] - dynamics[3]).abs();
    final headMovement = (dynamics[4] - dynamics[6]).abs();

    return eyeVariance > 0.3 || headMovement > 8;
  }

  Future<String> _saveToTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<Uint8List> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCameraController();
    }
    try {
      final image = await _cameraController!.takePicture().timeout(
        const Duration(seconds: 5),
      );
      final bytes = await image.readAsBytes();
      return _compressImage(bytes);
    } on CameraException catch (e) {
      debugPrint('Camera error: ${e.description}');
      throw CaptureException('Camera capture failed');
    } on TimeoutException {
      debugPrint('Image capture timed out');
      throw CaptureException('Capture timeout');
    }
  }

  Uint8List _compressImage(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) throw FormatException('Invalid image data');
      final resized = img.copyResize(image, width: 640, maintainAspect: true);
      return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    } catch (e) {
      debugPrint('Image compression failed, using original: $e');
      return bytes;
    }
  }

  Future<void> _initializeCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) {
      throw AppException('No cameras available');
    }
    _cameraController = CameraController(
      _cameras!.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _cameraController!.initialize();
    debugPrint('Camera controller initialized');
  }

  CameraController? get cameraController => _cameraController;

  Future<void> dispose() async {
    await _cameraController?.dispose();
    _cameraController = null;
    _isInitialized = false;
    _initCompleter = null;
    debugPrint('FaceService disposed');
  }
}

class DetectedFace {
  final String? faceId;
  DetectedFace({this.faceId});
  factory DetectedFace.fromJson(Map<String, dynamic> json) =>
      DetectedFace(faceId: json['faceId'] as String?);
}

class _AsyncLock {
  Future<void>? _lock;

  Future<T> run<T>(Future<T> Function() operation) async {
    while (_lock != null) {
      await _lock;
    }
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      return await operation();
    } finally {
      completer.complete();
      _lock = null;
    }
  }
}

class FaceVerificationResult {
  final bool isIdentical;
  final double confidence;
  final String message;

  FaceVerificationResult({
    required this.isIdentical,
    required this.confidence,
    required this.message,
  });
}

class AppException implements Exception {
  final String message;
  AppException(this.message);
}

class SystemException extends AppException {
  SystemException(super.message);
}

class SecurityException extends AppException {
  SecurityException(super.message);
}

class FaceException extends AppException {
  FaceException(super.message);
}

class CaptureException extends AppException {
  CaptureException(super.message);
}

class LivenessException extends AppException {
  LivenessException(super.message);
}

class ApiException implements Exception {
  final int statusCode;
  ApiException(this.statusCode);
}
