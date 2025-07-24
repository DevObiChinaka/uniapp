import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import 'flagged_students_screen.dart';

class ManageAttendanceScreen extends StatelessWidget {
  final Session session;
  const ManageAttendanceScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final attendanceRecords =
        appProvider.attendanceRecords
            .where((r) => r.sessionId == session.id)
            .toList();

    // Use allStudents for user lookup (per AppProvider API)
    final Map<String, User> userMap = {
      for (var user in appProvider.allStudents) user.id: user,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Attendance')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.warning, color: Colors.white),
                label: const Text('View Flagged Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => FlaggedStudentsScreen(sessionId: session.id),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: attendanceRecords.length,
              itemBuilder: (context, index) {
                final record = attendanceRecords[index];
                final user = userMap[record.userId];
                // Always show both name and university ID, fallback to record.userId if missing
                final studentName =
                    user != null && user.name.isNotEmpty
                        ? user.name
                        : 'Unknown';
                final universityId =
                    user?.universityId?.isNotEmpty == true
                        ? user!.universityId!
                        : record.userId.length >= 6
                        ? record.userId.substring(0, 6)
                        : record.userId;
                return ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('ID: $universityId'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: $studentName'),
                      Text('Marked at: ${record.timestamp}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Remove Attendance'),
                              content: const Text(
                                'Are you sure you want to remove this attendance record?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        appProvider.removeAttendanceRecord(record.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Attendance record removed.'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
