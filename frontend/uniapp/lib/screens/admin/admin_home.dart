// Main entry for admin section with bottom navigation
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';

import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'leave_requests_screen.dart';
import 'system_logs_screen.dart';
import 'profile_screen.dart';

class AdminHome extends StatefulWidget {
  @override
  _AdminHomeState createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    DashboardScreen(),
    StudentsScreen(),
    LeaveRequestsScreen(),
    SystemLogsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Fetch all admin data on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll(context);
    });
  }

  Future<void> _refreshAll(BuildContext context) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await Future.wait([
      provider.fetchAllStudents(),
      provider.fetchAllLeaveRequests(),
      provider.fetchSystemLogs(),
      provider.loadUserData(),
    ]);
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    // If Profile tab is selected, refresh user data
    if (index == 4) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedIndex == 4) {
            // Only refresh user data if Profile tab is active
            final provider = Provider.of<AppProvider>(context, listen: false);
            await provider.loadUserData();
          } else {
            await _refreshAll(context);
          }
        },
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Students'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note),
            label: 'Leave Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'System Logs',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
