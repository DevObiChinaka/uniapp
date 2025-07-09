import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';


class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if device supports biometric authentication and has enrolled biometrics
  Future<bool> hasBiometricSupport() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

    /// Prompts the user for biometric authentication
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          // biometricOnly: true,
        ),
      );
    } catch (e, stacktrace) {
      debugPrint('Biometric auth error: $e');
      debugPrint('$stacktrace');
      return false;
    }
  }

  Future<bool> hasBiometricsEnrolled() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }



  /// Saves biometric enabled flag in shared preferences
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Reads biometric enabled flag from shared preferences
  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Removes biometric enabled flag (disables biometric)
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('biometric_enabled');
  }
}
