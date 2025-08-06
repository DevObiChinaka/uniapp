import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/student/dashboard_screen.dart' as student;
import '../screens/student/attendance_screen.dart' as student;
import '../screens/student/exit_screen.dart' as student;
import '../screens/student/profile_screen.dart' as student;
import '../screens/lecturer/lecturer_home.dart';
import '../screens/security_dashboard.dart';
import '../screens/admin/admin_home.dart';
import '../screens/emergency_exit_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/biometric_login_screen.dart' as biometric;
import 'app_routes.dart' as routes;
import '../main.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: routes.AppRoutes.splash,
    routes: [
      GoRoute(
        path: routes.AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: routes.AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: routes.AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: routes.AppRoutes.biometricLogin,
        builder: (context, state) => const biometric.BiometricLoginScreen(),
      ),
      // GoRoute(
      //   path: '/student/dashboard',
      //   builder: (context, state) => const student.DashboardScreen(),
      // ),
      GoRoute(
        path: '/student/attendance',
        builder: (context, state) => const student.AttendanceScreen(),
      ),
      // Student exit route is commented out for now. Uncomment when backend and UI are ready.
      // GoRoute(
      //   path: '/student/exit',
      //   builder: (context, state) => const student.ExitScreen(),
      // ),
      GoRoute(
        path: '/student/profile',
        builder: (context, state) => const student.ProfileScreen(),
      ),
      GoRoute(
        path: routes.AppRoutes.studentDashboard,
        builder: (context, state) => const student.StudentHome(),
      ),
      GoRoute(
        path: routes.AppRoutes.lecturerDashboard,
        builder: (context, state) {
          // Pass extra if needed to LecturerHome
          return LecturerHome();
        },
      ),
      GoRoute(
        path: routes.AppRoutes.securityDashboard,
        builder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>? ?? {};
          final token = extra['token'] as String? ?? '';
          final role = extra['role'] as String? ?? '';

          return SecurityDashboard(token: token, role: role);
        },
      ),
      GoRoute(
        path: routes.AppRoutes.adminDashboard,
        builder: (context, state) => AdminHome(),
      ),
      GoRoute(
        path: routes.AppRoutes.emergencyExit,
        builder: (context, state) => const EmergencyExitScreen(),
      ),
      // Add other routes as needed
    ],
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: Center(child: Text('No route defined for ${state.uri}')),
        ),
  );
}
