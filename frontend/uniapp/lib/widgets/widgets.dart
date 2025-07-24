import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import '../models/models.dart';
import '../utils/utils.dart';

class FaceCaptureWidget extends StatefulWidget {
  final Function(Uint8List) onImageCaptured;
  final bool showPreview;

  const FaceCaptureWidget({super.key, 
    required this.onImageCaptured,
    this.showPreview = true,
  });

  @override
  _FaceCaptureWidgetState createState() => _FaceCaptureWidgetState();
}

class _FaceCaptureWidgetState extends State<FaceCaptureWidget> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras.first, ResolutionPreset.medium);

    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _isInitialized = true);
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);
    try {
      final image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();
      widget.onImageCaptured(bytes);
    } catch (e) {
      print('Error capturing image: $e');
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: CameraPreview(_controller!),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Text(
            'Position your face in the frame',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        if (widget.showPreview)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: FloatingActionButton(
            onPressed: _isCapturing ? null : _captureImage,
            backgroundColor: _isCapturing ? Colors.grey : Colors.blue,
            child: Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }
}

class BleStatusIndicator extends StatelessWidget {
  final bool isActive;
  final String statusText;

  const BleStatusIndicator({super.key, required this.isActive, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
        SizedBox(width: 8),
        Text(statusText),
      ],
    );
  }
}

class NotificationCard extends StatelessWidget {
  final AppNotification notification;

  const NotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Utils.notificationColor(notification.type).withOpacity(0.2),
          ),
          child: Icon(
            Utils.notificationIcon(notification.type),
            color: Utils.notificationColor(notification.type),
          ),
        ),
        title: Text(notification.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            SizedBox(height: 4),
            Text(
              notification.timeAgo,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing:
            !notification.read
                ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                )
                : null,
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  final String status;

  const StatusTag(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'approved':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'denied':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      case 'pending':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class LoadingSpinner extends StatelessWidget {
  final String? message;

  const LoadingSpinner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(message!, style: TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

class QrScannerOverlay extends StatelessWidget {
  final Color borderColor;

  const QrScannerOverlay({super.key, this.borderColor = Colors.green});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.width * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          top:
              MediaQuery.of(context).size.height / 2 -
              MediaQuery.of(context).size.width * 0.35 +
              16,
          left:
              MediaQuery.of(context).size.width / 2 -
              MediaQuery.of(context).size.width * 0.35 +
              16,
          child: Text(
            'Position QR code in frame',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
