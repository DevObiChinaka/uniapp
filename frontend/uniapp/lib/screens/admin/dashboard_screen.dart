// Dashboard screen for admin
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/admin/summary_card.dart';
import '../app_provider.dart';
import '../../models/models.dart';
// ignore: unused_import
import '../../utils/utils.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final adminUser = provider.getCurrentUser();
        final String adminName = adminUser?.name ?? 'Admin';
        final String? profileImageUrl = adminUser?.profilePictureUrl;

        // Count users by role
        final students =
            provider.allStudents.where((u) => u.role == 'student').toList();
        final lecturers =
            provider.allStudents.where((u) => u.role == 'lecturer').toList();
        final security =
            provider.allStudents.where((u) => u.role == 'security').toList();

        // Recent activity: show 5 most recent logs
        final List<SystemLog> recentLogs = List.from(provider.systemLogs)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final List<SystemLog> recentActivity = recentLogs.take(5).toList();

        return SafeArea(
          child: Column(
            children: [
              AppBar(
                title: Text('SALMS Admin'),
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
                // backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Welcome message
                      Text(
                        'Welcome, $adminName!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SummaryCard(
                        icon: Icons.school,
                        label: 'Students',
                        value: students.length.toString(),
                        color: Colors.indigo,
                      ),
                      SummaryCard(
                        icon: Icons.person,
                        label: 'Lecturers',
                        value: lecturers.length.toString(),
                        color: Colors.green,
                      ),
                      SummaryCard(
                        icon: Icons.shield,
                        label: 'Security',
                        value: security.length.toString(),
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 32),
                      // Recent Activity
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (recentActivity.isEmpty)
                        Text(
                          'No recent activity.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ...recentActivity.map(
                        (log) => ListTile(
                          leading: Icon(
                            _logIcon(log.type),
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(log.event),
                          subtitle: Text(log.timeAgo),
                          trailing:
                              log.details != null
                                  ? Icon(Icons.info_outline, color: Colors.grey)
                                  : null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: Navigate to full system logs screen
                          },
                          child: Text('View All'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _logIcon(String type) {
    switch (type) {
      case 'security':
        return Icons.security;
      case 'exit':
        return Icons.exit_to_app;
      case 'attendance':
        return Icons.how_to_reg;
      default:
        return Icons.info;
    }
  }
}
