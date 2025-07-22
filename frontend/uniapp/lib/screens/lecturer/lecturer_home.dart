import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import 'lecturer_dashboard.dart';
import 'lecturer_sessions_screen.dart';
import 'lecturer_configuration_screen.dart';
import 'lecturer_attendance_screen.dart';
import 'lecturer_profile_screen.dart';

class LecturerHome extends StatefulWidget {
  const LecturerHome({Key? key}) : super(key: key);

  @override
  State<LecturerHome> createState() => _LecturerHomeState();
}

class _LecturerHomeState extends State<LecturerHome> {
  int _selectedIndex = 0;
  bool _userLoaded = false;

  final List<Widget> _screens = [
    LecturerDashboard(),
    LecturerSessionsScreen(),
    LecturerConfigurationScreen(),
    LecturerAttendanceScreen(),
    LecturerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.loadUserData().then((_) {
      setState(() {
        _userLoaded = true;
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_userLoaded) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Sessions'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Config'),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
