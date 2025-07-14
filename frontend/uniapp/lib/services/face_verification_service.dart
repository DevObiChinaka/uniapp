import 'package:flutter/material.dart';
import 'package:uniapp/services/face_service.dart';
import 'package:uniapp/screens/app_constants.dart';

class FaceVerificationService {
  final FaceService _faceService;

  FaceVerificationService(this._faceService);
  
  /// Attempts to verify a face with retry mechanism and user guidance
  /// Returns true if verification is successful, false otherwise
  /// Parameters:
  ///   - faceId: The stored faceId to verify against
  ///   - maxRetries: Maximum number of attempts (default: 3)
  Future<bool> verifyFaceWithRetry(String faceId, {int maxRetries = 3}) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        // Attempt face verification
        final verification = await _faceService.verifyFace(faceId);
        
        // Check if verification meets confidence threshold
        if (verification.isIdentical && 
            verification.confidence >= AppConstants.faceConfidenceThreshold) {
          return true;
        }
        
        // If verification failed, provide guidance based on failure type
        if (verification.message.contains("No face detected")) {
          debugPrint("Retry attempt ${attempts+1}: No face detected");
        } else if (verification.confidence < AppConstants.faceConfidenceThreshold) {
          debugPrint("Retry attempt ${attempts+1}: Low confidence (${verification.confidence})");
        }
        
        attempts++;
        
        // Wait before retry
        await Future.delayed(Duration(seconds: 1));
      } catch (e) {
        debugPrint("Face verification error: $e");
        attempts++;
      }
    }
    
    // All attempts failed
    return false;
  }
  
  /// After max retries, offer alternative verification method
  /// This could be implemented by the app for fallback options
  Future<bool> fallbackVerification() async {
    // This could be implemented with:
    // 1. Manual verification by lecturer or admin
    // 2. Alternative biometric (fingerprint)
    // 3. One-time password
    // 4. Security questions
    
    // For now, just return false to indicate failure
    return false;
  }
}
