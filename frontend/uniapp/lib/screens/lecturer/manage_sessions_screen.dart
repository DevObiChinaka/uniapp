import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/attendance_management_screen.dart';

class ManageSessionsScreen extends StatefulWidget {
  const ManageSessionsScreen({super.key});

  @override
  State<ManageSessionsScreen> createState() => _ManageSessionsScreenState();
}

class _ManageSessionsScreenState extends State<ManageSessionsScreen> {
  bool _isLoading = false;
  String? _error;
  List<Session> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final user = provider.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      final username = user.username;
      if (username == null) {
        throw Exception('Username not found for current user');
      }

      final sessions = await provider.fetchLecturerSessions(username);
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load sessions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No sessions found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final isActive = session.endTime == null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(session.courseId ?? 'Unknown Course'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Program: ${session.program}'),
                  Text('Level: ${session.level}'),
                  Text(
                    'Status: ${isActive ? 'Active' : 'Ended'}',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.group),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => AttendanceManagementScreen(
                                sessionId: session.id,
                                program: session.program,
                              ),
                        ),
                      );
                    },
                    tooltip: 'Manage Attendance',
                  ),
                  if (isActive)
                    IconButton(
                      icon: const Icon(Icons.stop),
                      onPressed: () async {
                        final shouldEnd = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('End Session'),
                                content: const Text(
                                  'Are you sure you want to end this session?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('End Session'),
                                  ),
                                ],
                              ),
                        );

                        if (shouldEnd == true) {
                          final provider = Provider.of<AppProvider>(
                            context,
                            listen: false,
                          );
                          final success = await provider.endSession(session.id);

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Session ended successfully'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to end session'),
                              ),
                            );
                          }
                        }
                      },
                      tooltip: 'End Session',
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
