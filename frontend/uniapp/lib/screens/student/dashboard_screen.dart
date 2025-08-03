import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import 'attendance_screen.dart';
import 'exit_screen.dart';
import 'profile_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _selectedIndex = 0;
  bool _userLoaded = false;

  final List<Widget> _screens = [
    _StudentDashboardContent(),
    AttendanceScreen(),
    ExitScreen(),
    ProfileScreen(),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: 'Exit'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StudentDashboardContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final studentUser = provider.getCurrentUser();
        final String studentName = studentUser?.name ?? 'Student';
        final String? profileImageUrl = studentUser?.profilePictureUrl;

        // Attendance summary (stub)
        final int attendanceCount = provider.attendanceRecords.length;
        final int leaveCount = provider.leaveRequests.length;
        // Exit summary and history not available, so omit exitCount and exit history for now
        // final int exitCount = provider.exitRecords?.length ?? 0;

        // Recent activity (stub)
        final recentAttendance = provider.attendanceRecords.take(5).toList();

        return SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text('SALMS Student'),
                centerTitle: false,
                actions: [
                  IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Notifications coming soon!')),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                ],
                elevation: 0,
                foregroundColor: Colors.indigo,
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await provider.loadUserData();
                    // Use a default or current sessionId for refresh
                    final sessionId =
                        recentAttendance.isNotEmpty
                            ? recentAttendance.first.sessionId
                            : '';
                    await provider.fetchAttendanceRecords(sessionId);
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  profileImageUrl != null
                                      ? NetworkImage(profileImageUrl)
                                      : null,
                              child:
                                  profileImageUrl == null
                                      ? Icon(Icons.person, size: 32)
                                      : null,
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  studentUser?.universityId ?? '',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _SummaryCard(
                              label: 'Attendance',
                              value: attendanceCount.toString(),
                              icon: Icons.qr_code,
                              color: Colors.green,
                            ),
                            _SummaryCard(
                              label: 'Leave',
                              value: leaveCount.toString(),
                              icon: Icons.event_available,
                              color: Colors.orange,
                            ),
                            // _SummaryCard(
                            //   label: 'Exit',
                            //   value: exitCount.toString(),
                            //   icon: Icons.exit_to_app,
                            //   color: Colors.red,
                            // ),
                            // For future: exit history list
                            // final recentExits = provider.exitRecords?.take(5).toList() ?? [];
                            // ...recentExits.map((record) => ListTile(
                            //   leading: Icon(Icons.exit_to_app, color: Colors.red),
                            //   title: Text('Exit: ${record.exitType}'),
                            //   subtitle: Text('Time: ${record.timestamp.toLocal().toString().substring(0, 19)}'),
                            // )),
                          ],
                        ),
                        SizedBox(height: 32),
                        Text(
                          'Recent Attendance',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        ...recentAttendance.map(
                          (record) => ListTile(
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            title: Text('Session: ${record.sessionId}'),
                            subtitle: Text(
                              'Time: ${record.timestamp.toLocal().toString().substring(0, 19)}',
                            ),
                          ),
                        ),
                        if (recentAttendance.isEmpty)
                          Text('No recent attendance records.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Container(
        width: 100,
        height: 100,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: color),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
