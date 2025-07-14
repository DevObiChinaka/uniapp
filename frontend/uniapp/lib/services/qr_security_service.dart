import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:uniapp/screens/app_constants.dart';

class QrSecurityService {
  /// Generates a secure QR code payload for gate exit
  /// Returns a JSON string with security information
  static String generateSecureQrPayload({
    required String securityId,
    required String gateId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Create the base payload
    final Map<String, dynamic> payload = {
      'security_id': securityId,
      'gate_id': gateId,
      'timestamp': timestamp,
      'expires_at': timestamp + AppConstants.qrTtlSeconds,
    };
    
    // Generate HMAC signature
    final signature = _generateHmacSignature(payload);
    
    // Add signature to payload
    payload['signature'] = signature;
    
    // Return encoded payload
    return jsonEncode(payload);
  }
  
  /// Verifies a QR code payload for authenticity and expiration
  /// Returns a tuple (isValid, message)
  static (bool, String) verifyQrPayload(String payloadJson) {
    try {
      // Parse the JSON payload
      final Map<String, dynamic> payload = jsonDecode(payloadJson);
      
      // Check if all required fields are present
      if (!_hasRequiredFields(payload)) {
        return (false, 'Invalid QR code format');
      }
      
      // Check if QR code has expired
      final int expiresAt = payload['expires_at'];
      final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      if (now > expiresAt) {
        return (false, 'QR code has expired');
      }
      
      // Verify HMAC signature
      final String providedSignature = payload['signature'];
      
      // Remove signature for verification
      final Map<String, dynamic> payloadForVerification = Map.from(payload);
      payloadForVerification.remove('signature');
      
      final String expectedSignature = _generateHmacSignature(payloadForVerification);
      
      if (providedSignature != expectedSignature) {
        return (false, 'Invalid QR code signature');
      }
      
      return (true, 'QR code verified successfully');
    } catch (e) {
      debugPrint('Error verifying QR payload: $e');
      return (false, 'Error processing QR code');
    }
  }
  
  /// Generates an HMAC signature for the payload
  static String _generateHmacSignature(Map<String, dynamic> payload) {
    // Sort the keys to ensure consistent order
    final sortedPayload = Map.fromEntries(
      payload.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    
    // Convert payload to string
    final data = jsonEncode(sortedPayload);
    
    // Generate HMAC using SHA-256
    final key = utf8.encode(AppConstants.hmacSecretKey);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    return digest.toString();
  }
  
  /// Checks if the payload has all required fields
  static bool _hasRequiredFields(Map<String, dynamic> payload) {
    return payload.containsKey('security_id') && 
           payload.containsKey('gate_id') && 
           payload.containsKey('timestamp') && 
           payload.containsKey('expires_at') && 
           payload.containsKey('signature');
  }
}
