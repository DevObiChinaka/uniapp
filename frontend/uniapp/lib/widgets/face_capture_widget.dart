import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// import 'dart:io'; // Removed unused import
import 'package:flutter/foundation.dart';

class FaceCaptureWidget extends StatefulWidget {
  final Function(XFile) onCaptureComplete;
  final bool showOverlay;
  final Duration captureDelay;
  final bool autoCaptureEnabled;

  const FaceCaptureWidget({
    super.key,
    required this.onCaptureComplete,
    this.showOverlay = true,
    this.captureDelay = const Duration(seconds: 2),
    this.autoCaptureEnabled = true,
  });

  @override
  _FaceCaptureWidgetState createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _initialized = false;
  bool _capturing = false;
  bool _frontCameraAvailable = false;
  int _countdownSeconds = 0;
  Timer? _captureTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _frontCameraAvailable =
          frontCamera.lensDirection == CameraLensDirection.front;

      // Initialize controller
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _initialized = true;

          // Start auto-capture countdown if enabled
          if (widget.autoCaptureEnabled) {
            _startAutoCaptureCountdown();
          }
        });
      }
    } catch (e) {
      _showError('Failed to initialize camera: $e');
    }
  }

  void _startAutoCaptureCountdown() {
    _countdownSeconds = 3;

    // Cancel any existing timers
    _countdownTimer?.cancel();
    _captureTimer?.cancel();

    // Start countdown timer
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        _captureImage();
      }
    });
  }

  Future<void> _captureImage() async {
    if (_capturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final image = await _cameraController!.takePicture();
      widget.onCaptureComplete(image);
    } catch (e) {
      _showError('Failed to capture image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    debugPrint('FaceCaptureWidget error: $message');
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _captureTimer?.cancel();
    _cameraController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _cameraController == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Camera preview
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Face position overlay
        if (widget.showOverlay)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 2),
              shape: BoxShape.circle,
            ),
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.width * 0.6,
          ),

        // Warning if not using front camera
        if (!_frontCameraAvailable)
          Positioned(
            bottom: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Front camera not available',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),

        // Countdown display
        if (_countdownSeconds > 0)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black45,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _countdownSeconds.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Loading indicator during capture
        if (_capturing)
          Container(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),

        // Manual capture button if auto-capture is disabled
        if (!widget.autoCaptureEnabled)
          Positioned(
            bottom: 16,
            child: FloatingActionButton(
              onPressed: _captureImage,
              backgroundColor: Colors.blue,
              child: Icon(Icons.camera),
            ),
          ),

        // Retry button
        if (_countdownSeconds == 0 && widget.autoCaptureEnabled)
          Positioned(
            bottom: 16,
            child: TextButton.icon(
              onPressed: _startAutoCaptureCountdown,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
      ],
    );
  }
}
