import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class AuthService {
  Future<Map<String, dynamic>> login({
    required String usernameOrId,
    required String password,
    required String role,
  }) async {
    final payload = {
      'identifier': usernameOrId.trim(), // unified identifier
      'password': password,
      'role': role,
    };

    final response = await ApiService.postAndDecode('/login/', payload);
    final status = response['statusCode'];
    final data = response['body'];

    if (status == 200 && data.containsKey('access')) {
      final user = data['user'];
      final access = data['access'];
      final refresh = data['refresh'];
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', data['access']);
      await prefs.setString('refresh', data['refresh']);
      await prefs.setString('role', user['role']);
      await prefs.setString('first_name', user['first_name']);
      await prefs.setString('last_name', user['last_name']);

      if (role == 'student') {
        await prefs.setString('university_id', user['university_id'] ?? '');
      } else {
        await prefs.setString('username', user['username'] ?? '');
        await prefs.setBool('is_superadmin', user['is_superadmin'] ?? false);
      }

      await prefs.setBool('has_logged_in', true); // for biometric tracking

      // Register FCM token after successful login
      await _registerFcmToken();

      return {
        'success': true,
        'data': {
          'first_name': user['first_name'],
          'last_name': user['last_name'],
          'university_id': user['university_id'] ?? '',
          'username': user['username'] ?? '',
          'access': access, // ✅ Correct
          'refresh': refresh,
          'role': user['role'],
        },
      };
    } else {
      return {'success': false, 'message': data['detail'] ?? 'Login failed'};
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();

      if (fcmToken != null) {
        final response = await ApiService.postAuthenticated('/fcm/', {
          'token': fcmToken,
        });

        if (response.statusCode == 200) {
          print('FCM token registered successfully');
        } else {
          print('FCM token registration failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }
}
