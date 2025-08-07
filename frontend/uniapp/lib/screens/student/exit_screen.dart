import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';
import 'submit_leave_request_screen.dart';
import 'leave_request_details_screen.dart';
import 'exit_qr_screen.dart';
import 'exit_history_screen.dart';
import 'all_leave_requests_screen.dart';

class ExitScreen extends StatefulWidget {
  const ExitScreen({super.key});

  @override
  State<ExitScreen> createState() => _ExitScreenState();
}

class _ExitScreenState extends State<ExitScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.fetchLeaveRequests();
    await provider.fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exit & Leave Requests'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _navigateToExitHistory(context),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final user = provider.getCurrentUser();
          final isLoading = provider.isLoading;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campus Status Card
                  _buildCampusStatusCard(context, user),
                  const SizedBox(height: 20),

                  // Quick Stats
                  _buildQuickStats(context, provider),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActions(context, provider),
                  const SizedBox(height: 20),

                  // Recent Leave Requests
                  _buildRecentLeaveRequests(context, provider),
                  const SizedBox(height: 20),

                  // Active Leave/Exit QR
                  _buildActiveExitSection(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCampusStatusCard(BuildContext context, User? user) {
    final isOnCampus = user?.isOnCampus ?? false;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isOnCampus
                    ? [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ]
                    : [
                      Colors.orange.withOpacity(0.1),
                      Colors.orange.withOpacity(0.05),
                    ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isOnCampus
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOnCampus ? Icons.location_on : Icons.location_off,
                color: isOnCampus ? Colors.green : Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnCampus ? 'Currently On Campus' : 'Currently Off Campus',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isOnCampus ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOnCampus
                        ? 'You can submit leave requests to exit campus'
                        : 'Use approved leave requests to re-enter campus',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, AppProvider provider) {
    final leaveRequests = provider.leaveRequests;
    final totalRequests = leaveRequests.length;
    final pendingRequests =
        leaveRequests
            .where((r) => r.status == LeaveRequestStatus.pending)
            .length;
    final approvedRequests =
        leaveRequests
            .where((r) => r.status == LeaveRequestStatus.approved)
            .length;
    final activeLeave = leaveRequests.any(
      (r) =>
          r.status == LeaveRequestStatus.approved &&
          DateTime.now().isAfter(r.startDate) &&
          DateTime.now().isBefore(r.endDate.add(const Duration(days: 1))),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                Icons.event_note,
                totalRequests.toString(),
                'Total Requests',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                Icons.pending,
                pendingRequests.toString(),
                'Pending',
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                Icons.check_circle,
                approvedRequests.toString(),
                'Approved',
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                activeLeave ? Icons.directions_run : Icons.home,
                activeLeave ? 'YES' : 'NO',
                'Active Leave',
                activeLeave ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Submit Leave\nRequest',
                Icons.assignment_add,
                Colors.blue,
                () => _navigateToSubmitLeaveRequest(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Exit\nHistory',
                Icons.history,
                Colors.orange,
                () => _navigateToExitHistory(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Emergency\nExit',
                Icons.warning,
                Colors.red,
                () => _showEmergencyExitDialog(context, provider),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentLeaveRequests(BuildContext context, AppProvider provider) {
    final leaveRequests = provider.leaveRequests.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Leave Requests',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (leaveRequests.isNotEmpty)
              TextButton(
                onPressed: () => _navigateToAllLeaveRequests(context),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (leaveRequests.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No leave requests yet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submit your first leave request to get started',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...leaveRequests.map(
            (request) => _buildLeaveRequestCard(context, request),
          ),
      ],
    );
  }

  Widget _buildLeaveRequestCard(BuildContext context, LeaveRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case LeaveRequestStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case LeaveRequestStatus.denied:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case LeaveRequestStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(
          request.reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${DateFormat('MMM dd').format(request.startDate)} - ${DateFormat('MMM dd').format(request.endDate)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                request.status.value.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _navigateToLeaveRequestDetails(context, request),
      ),
    );
  }

  Widget _buildActiveExitSection(BuildContext context, AppProvider provider) {
    // Find any approved leave request that is currently active
    LeaveRequest? approvedLeave;
    for (final request in provider.leaveRequests) {
      if (request.status == LeaveRequestStatus.approved &&
          DateTime.now().isAfter(request.startDate) &&
          DateTime.now().isBefore(
            request.endDate.add(const Duration(days: 1)),
          )) {
        approvedLeave = request;
        break;
      }
    }

    final hasActiveLeave = approvedLeave != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exit Authorization',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                hasActiveLeave
                    ? _buildActiveLeaveSection(context, approvedLeave)
                    : _buildNoActiveLeaveSection(context),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveLeaveSection(BuildContext context, LeaveRequest leave) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified_user, color: Colors.green, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'Exit Authorized',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Valid until ${DateFormat('MMM dd, yyyy').format(leave.endDate)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _navigateToExitQrScreen(context, leave),
            icon: const Icon(Icons.qr_code),
            label: const Text('Generate Exit QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActiveLeaveSection(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.lock_outline, color: Colors.grey[400], size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'No Active Exit Authorization',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Submit and get approval for a leave request to enable campus exit',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _navigateToSubmitLeaveRequest(context),
            icon: const Icon(Icons.add),
            label: const Text('Submit Leave Request'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToSubmitLeaveRequest(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const SubmitLeaveRequestScreen(),
          ),
        )
        .then((result) {
          if (result == true) {
            // Refresh data if a leave request was successfully submitted
            _refreshData();
          }
        });
  }

  void _navigateToLeaveRequestDetails(
    BuildContext context,
    LeaveRequest request,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LeaveRequestDetailsScreen(leaveRequest: request),
      ),
    );
  }

  void _navigateToExitQrScreen(BuildContext context, LeaveRequest leave) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExitQRScreen(leaveRequest: leave),
      ),
    );
  }

  void _navigateToExitHistory(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ExitHistoryScreen()));
  }

  void _navigateToAllLeaveRequests(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AllLeaveRequestsScreen()),
    );
  }

  void _showEmergencyExitDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Emergency Exit'),
            ],
          ),
          content: const Text(
            'Emergency exit should only be used in urgent situations. This will be logged and may require explanation. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showComingSoonDialog('Emergency Exit QR');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed'),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feature),
          content: Text(
            '$feature functionality will be implemented in the next phase.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
