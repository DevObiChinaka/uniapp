// Entire file can be deleted as AdminHome is now the main admin dashboard.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/utils/utils.dart';
import 'package:uniapp/widgets/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../routes/app_routes.dart' as routes;

class AdminDashboard extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String universityId;
  final String token;
  final String role;
  final String? username;

  const AdminDashboard({
    Key? key,
    required this.firstName,
    required this.lastName,
    required this.universityId,
    required this.token,
    required this.role,
    this.username,
  }) : super(key: key);

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  final List<String> _tabs = [
    'Students',
    'Leave Requests',
    'System Logs',
    'Profile',
  ];

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

  Future<void> _selectAndUploadImage() async {
    if (_isUploadingImage) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Upload to Firebase Storage
      final String fileName =
          'profile_${widget.universityId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures/$fileName',
      );

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new image URL
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.updateUserProfile({'profile_picture': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
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
            _buildProfileTab(),
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
          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchAllStudents();
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
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
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchAllStudents();
          },
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            itemCount: provider.allStudents.length,
            itemBuilder: (context, index) {
              final student = provider.allStudents[index];
              return _buildStudentCard(student, provider);
            },
          ),
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
            Text('ID: ${student.universityId ?? 'No ID'}'),
            SizedBox(height: 4),
            Text(student.program ?? 'No program'),
            SizedBox(height: 4),
            Text(
              student.isOnCampus ? 'on-campus' : 'off-campus',
              style: TextStyle(
                color: student.isOnCampus ? Colors.green : Colors.blue,
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
      value: student.isOnCampus ? 'on-campus' : 'off-campus',
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
          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchAllLeaveRequests();
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
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
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchAllLeaveRequests();
          },
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            itemCount: provider.allLeaveRequests.length,
            itemBuilder: (context, index) {
              final leaveRequest = provider.allLeaveRequests[index];
              return _buildLeaveRequestCard(leaveRequest, provider);
            },
          ),
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
                Text('Student: ${leave.studentName ?? 'Unknown Student'}'),
                Text('Matric Number: ${leave.studentUniversityId ?? 'N/A'}'),
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
                if (leave.status == LeaveRequestStatus.pending)
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
                  final comments = controller.text.trim();
                  provider.updateLeaveStatusWithComments(
                    leave.id,
                    LeaveRequestStatus.denied,
                    comments.isEmpty ? null : comments,
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
          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchSystemLogs();
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Center(
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
                        'Pull down to refresh',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await provider.fetchSystemLogs();
          },
          child: ListView.builder(
            physics: AlwaysScrollableScrollPhysics(),
            itemCount: provider.systemLogs.length,
            itemBuilder: (context, index) {
              final log = provider.systemLogs[index];
              return _buildLogItem(log);
            },
          ),
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

  Widget _buildProfileTab() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Create admin user object from widget properties
        final adminUser = User(
          id:
              widget.role == 'admin'
                  ? (widget.username ?? widget.token)
                  : widget.universityId,
          name: '${widget.firstName} ${widget.lastName}',
          role: widget.role,
          isOnCampus: false, // Default value for admin
          universityId: widget.role == 'admin' ? null : widget.universityId,
        );

        return RefreshIndicator(
          onRefresh: () async {
            // Refresh data by re-fetching students and other data
            await provider.fetchAllStudents();
            await provider.fetchAllLeaveRequests();
            await provider.fetchSystemLogs();
          },
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Image Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            adminUser.profilePictureUrl != null
                                ? NetworkImage(adminUser.profilePictureUrl!)
                                : null,
                        child:
                            adminUser.profilePictureUrl == null
                                ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[600],
                                )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed:
                                _isUploadingImage
                                    ? null
                                    : _selectAndUploadImage,
                            icon:
                                _isUploadingImage
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Profile Information Cards
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),

                        _buildProfileInfoRow(
                          context,
                          'First Name',
                          widget.firstName,
                          Icons.person,
                          onEdit:
                              () => _editProfile(
                                context,
                                provider,
                                'firstName',
                                widget.firstName,
                              ),
                        ),

                        Divider(),

                        _buildProfileInfoRow(
                          context,
                          'Last Name',
                          widget.lastName,
                          Icons.person,
                          onEdit:
                              () => _editProfile(
                                context,
                                provider,
                                'lastName',
                                widget.lastName,
                              ),
                        ),

                        Divider(),

                        _buildProfileInfoRow(
                          context,
                          'Full Name',
                          '${widget.firstName} ${widget.lastName}',
                          Icons.badge,
                          canEdit: false,
                        ),

                        Divider(),

                        _buildProfileInfoRow(
                          context,
                          widget.role == 'admin'
                              ? 'Admin Username'
                              : 'University ID',
                          widget.role == 'admin'
                              ? (adminUser.username ?? adminUser.id)
                              : (adminUser.universityId ?? ''),
                          Icons.account_circle,
                          canEdit: false,
                        ),

                        Divider(),

                        _buildProfileInfoRow(
                          context,
                          'Role',
                          widget.role.toUpperCase(),
                          Icons.admin_panel_settings,
                          canEdit: false,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Campus Status Card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  adminUser.isOnCampus
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  color:
                                      adminUser.isOnCampus
                                          ? Colors.green
                                          : Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Campus Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            Switch(
                              value: adminUser.isOnCampus,
                              onChanged: (value) {
                                _toggleCampusStatus(context, provider, value);
                              },
                              activeColor: Colors.green,
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        Text(
                          adminUser.isOnCampus
                              ? 'Currently on campus'
                              : 'Currently off campus',
                          style: TextStyle(
                            color:
                                adminUser.isOnCampus
                                    ? Colors.green
                                    : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _logout(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    VoidCallback? onEdit,
    bool canEdit = true,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (canEdit && onEdit != null)
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  void _editProfile(
    BuildContext context,
    AppProvider provider,
    String field,
    String currentValue,
  ) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit ${field.toUpperCase()}'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: field.toUpperCase(),
                border: OutlineInputBorder(),
              ),
              textCapitalization:
                  field == 'name'
                      ? TextCapitalization.words
                      : TextCapitalization.none,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newValue = controller.text.trim();
                  if (newValue.isNotEmpty && newValue != currentValue) {
                    Navigator.pop(context);

                    // Show loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updating $field...')),
                    );

                    // TODO: Implement API call to update profile
                    // For now, just show success message
                    await Future.delayed(Duration(seconds: 1));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$field updated successfully!')),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
                child: Text('Save'),
              ),
            ],
          ),
    );
  }

  void _toggleCampusStatus(
    BuildContext context,
    AppProvider provider,
    bool isOnCampus,
  ) async {
    try {
      // Show loading state
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Updating campus status...')));

      // TODO: Implement API call to update campus status
      // For now, just show success message
      await Future.delayed(Duration(seconds: 1));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Campus status updated to ${isOnCampus ? "on-campus" : "off-campus"}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update campus status')));
    }
  }

  void _logout(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Logout'),
            content: Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  provider.logout();
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Logout', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }
}
