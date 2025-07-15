import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/utils/utils.dart';
import 'package:uniapp/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart' as routes;

class AdminDashboard extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String universityId;
  final String token;
  final String role;

  const AdminDashboard({
    Key? key,
    required this.firstName,
    required this.lastName,
    required this.universityId,
    required this.token,
    required this.role,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Students', 'Leave Requests', 'System Logs'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.fetchAllStudents();
    provider.fetchAllLeaveRequests();
    provider.fetchSystemLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome, ${widget.firstName} 👋',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final shouldLogout =
                  await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('CANCEL'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('LOGOUT'),
                            ),
                          ],
                        ),
                  ) ??
                  false;

              if (shouldLogout) {
                final provider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );
                final success = await provider.logout();

                if (success && mounted) {
                  // Navigate to login screen
                  context.go(routes.AppRoutes.login);
                }
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FutureBuilder<String?>(
              future: SharedPreferences.getInstance().then(
                (prefs) => prefs.getString('profile_image_path'),
              ),
              builder: (context, snapshot) {
                final imagePath = snapshot.data;
                final hasImage =
                    imagePath != null && File(imagePath).existsSync();

                return GestureDetector(
                  onTap: () {
                    context.push(
                      routes.AppRoutes.editProfile,
                      extra: {
                        'firstName': widget.firstName,
                        'lastName': widget.lastName,
                        'universityId': widget.universityId,
                        'role': widget.role,
                      },
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage:
                        hasImage
                            ? FileImage(File(imagePath))
                            : const AssetImage(
                                  'assets/images/avatar_placeholder.png',
                                )
                                as ImageProvider,
                  ),
                );
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          isScrollable: true,
          indicatorColor: Colors.white,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.indigo.shade50, Colors.white, Colors.blue.shade50],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStudentsTab(),
            _buildLeaveRequestsTab(),
            _buildSystemLogsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return LoadingSpinner();

        // Debug: Print the students count
        debugPrint('Students count: ${provider.allStudents.length}');
        
        if (provider.allStudents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No students found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Students will appear here when they register',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.allStudents.length,
          itemBuilder: (context, index) {
            final student = provider.allStudents[index];
            return _buildStudentCard(student, provider);
          },
        );
      },
    );
  }

  Widget _buildStudentCard(User student, AppProvider provider) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Icon(Icons.person, color: Colors.indigo),
        ),
        title: Text(
          student.name,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.program ?? 'No program'),
            SizedBox(height: 4),
            Text(
              student.campusTag ?? 'No status',
              style: TextStyle(
                color:
                    student.campusTag == 'on-campus'
                        ? Colors.green
                        : Colors.blue,
              ),
            ),
          ],
        ),
        trailing: _buildCampusTagDropdown(student, provider),
      ),
    );
  }

  Widget _buildCampusTagDropdown(User student, AppProvider provider) {
    return DropdownButton<String>(
      value: student.campusTag ?? 'off-campus',
      items:
          ['on-campus', 'off-campus']
              .map(
                (tag) => DropdownMenuItem(
                  value: tag,
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tag == 'on-campus' ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) {
          provider.updateCampusTag(student.id, value == 'on-campus');
        }
      },
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
    );
  }

  Widget _buildLeaveRequestsTab() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return LoadingSpinner();

        debugPrint('Leave requests count: ${provider.allLeaveRequests.length}');
        
        if (provider.allLeaveRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No leave requests found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Leave requests will appear here when submitted',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.allLeaveRequests.length,
          itemBuilder: (context, index) {
            final leave = provider.allLeaveRequests[index];
            return _buildLeaveRequestCard(leave, provider);
          },
        );
      },
    );
  }

  Widget _buildLeaveRequestCard(LeaveRequest leave, AppProvider provider) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: StatusTag(leave.status.value),
        title: Text(
          '${Utils.formatDate(leave.startDate)} - ${Utils.formatDate(leave.endDate)}',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          leave.reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${leave.userId}'),
                SizedBox(height: 8),
                Text('Submitted: ${Utils.formatDateTime(leave.submittedAt)}'),
                if (leave.reviewedAt != null) ...[
                  SizedBox(height: 8),
                  Text('Reviewed: ${Utils.formatDateTime(leave.reviewedAt!)}'),
                ],
                if (leave.reviewComments != null) ...[
                  SizedBox(height: 8),
                  Text('Comments: ${leave.reviewComments}'),
                ],
                SizedBox(height: 16),
                if (leave.status == 'pending')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            () => provider.updateLeaveStatus(
                              leave.id,
                              LeaveRequestStatus.approved,
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(Icons.check, size: 20),
                        label: Text('Approve'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showDenyDialog(leave, provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(Icons.close, size: 20),
                        label: Text('Deny'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDenyDialog(LeaveRequest leave, AppProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Deny Leave Request',
              style: TextStyle(color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Are you sure you want to deny this request?'),
                SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Reason for denial (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  provider.updateLeaveStatus(
                    leave.id,
                    LeaveRequestStatus.denied,
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Confirm Denial'),
              ),
            ],
          ),
    );
  }

  Widget _buildSystemLogsTab() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return LoadingSpinner();

        debugPrint('System logs count: ${provider.systemLogs.length}');
        
        if (provider.systemLogs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No system logs found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'System activities will be logged here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: provider.systemLogs.length,
          itemBuilder: (context, index) {
            final log = provider.systemLogs[index];
            return _buildLogItem(log);
          },
        );
      },
    );
  }

  Widget _buildLogItem(SystemLog log) {
    Color logColor;
    IconData logIcon;

    switch (log.type) {
      case 'security':
        logColor = Colors.red;
        logIcon = Icons.security;
        break;
      case 'exit':
        logColor = Colors.blue;
        logIcon = Icons.exit_to_app;
        break;
      case 'attendance':
        logColor = Colors.green;
        logIcon = Icons.how_to_reg;
        break;
      default:
        logColor = Colors.grey;
        logIcon = Icons.info;
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: logColor.withOpacity(0.2),
          ),
          child: Icon(logIcon, color: logColor, size: 24),
        ),
        title: Text(log.event, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Utils.formatDateTime(log.timestamp)),
            if (log.details != null)
              Text(
                log.details!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Text(
          log.timeAgo,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }
}
