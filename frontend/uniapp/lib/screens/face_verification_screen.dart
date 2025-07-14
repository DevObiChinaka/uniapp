import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../screens/app_provider.dart';
import '../screens/app_constants.dart';
import '../widgets/face_capture_widget.dart';
import 'dart:io';

class FaceVerificationScreen extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Function(bool success, String? message) onVerificationComplete;
  
  const FaceVerificationScreen({
    Key? key,
    this.title,
    this.subtitle,
    required this.onVerificationComplete,
  }) : super(key: key);

  @override
  _FaceVerificationScreenState createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  String _statusMessage = 'Position your face in the frame';
  double _progressValue = 0.0;
  XFile? _capturedImage;
  bool _verificationSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _errorMessage;
  int _attempts = 0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Handle verification with retry mechanism
  Future<void> _processVerification(AppProvider provider, XFile image) async {
    setState(() {
      _capturedImage = image;
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Use the enhanced face verification service with retry
      final faceVerificationService = FaceVerificationService(provider.faceService);
      final success = await faceVerificationService.verifyFaceWithRetry(
        provider.faceId!,
        maxRetries: 3,
      );
      
      if (success) {
        setState(() {
          _verificationSuccess = true;
          _errorMessage = null;
        });
        
        // Wait a moment to show success before proceeding
        await Future.delayed(Duration(seconds: 1));
        
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        // All retries failed
        _handleVerificationError('Face verification failed after multiple attempts');
        
        // Show fallback options
        _showFallbackOptions();
      }
    } catch (e) {
      _handleVerificationError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  void _handleVerificationError(String message) {
    setState(() {
      _verificationSuccess = false;
      _errorMessage = message;
      _attempts++;
    });
  }
  
  void _showFallbackOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verification Failed'),
        content: Text('Would you like to try an alternative verification method?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset for another try
              setState(() {
                _capturedImage = null;
                _attempts = 0;
              });
            },
            child: Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to alternative verification method
              Navigator.pushReplacementNamed(context, '/alternative_verification');
            },
            child: Text('Alternative Method'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text(widget.title ?? 'Face Verification', 
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Status section
              Container(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      widget.subtitle ?? 'Please verify your identity to continue',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _isProcessing ? _progressValue : null,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _verificationSuccess ? Colors.green : Colors.blue,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _verificationSuccess ? Colors.green : Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorMessage != null) ...{
                      SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    },
                  ],
                ),
              ),
              
              // Camera preview section
              Expanded(
                child: _capturedImage != null && _isProcessing
                    ? Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_capturedImage!.path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (_verificationSuccess)
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 100,
                              ),
                          ],
                        ),
                      )
                    : Container(
                        margin: EdgeInsets.all(16),
                        child: FaceCaptureWidget(
                          onCaptureComplete: (XFile image) {
                            _processVerification(provider, image);
                          },
                          showOverlay: true,
                          autoCaptureEnabled: !_isProcessing,
                        ),
                      ),
              ),
              
              // Instructions
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Make sure:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildInstructionItem(
                      icon: Icons.face,
                      text: 'Your face is clearly visible',
                    ),
                    _buildInstructionItem(
                      icon: Icons.wb_sunny,
                      text: 'You are in a well-lit area',
                    ),
                    _buildInstructionItem(
                      icon: Icons.remove_red_eye,
                      text: 'You are looking directly at the camera',
                    ),
                    SizedBox(height: 16),
                    if (!_isProcessing)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _capturedImage = null;
                            _statusMessage = 'Position your face in the frame';
                          });
                        },
                        icon: Icon(Icons.refresh, color: Colors.white70),
                        label: Text(
                          'Retry',
                          style: TextStyle(color: Colors.white70),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInstructionItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
