import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';
import 'leave_request_details_screen.dart';
import 'submit_leave_request_screen.dart';

class AllLeaveRequestsScreen extends StatefulWidget {
  const AllLeaveRequestsScreen({super.key});

  @override
  State<AllLeaveRequestsScreen> createState() => _AllLeaveRequestsScreenState();
}

class _AllLeaveRequestsScreenState extends State<AllLeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLeaveRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveRequests() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.fetchLeaveRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Leave Requests'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToSubmitLeaveRequest(context),
            tooltip: 'Submit New Request',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Denied'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLeaveRequests,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final allRequests = provider.leaveRequests;

            if (provider.isLoading && allRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildRequestsList(context, allRequests, 'All'),
                _buildRequestsList(
                  context,
                  allRequests
                      .where((r) => r.status == LeaveRequestStatus.pending)
                      .toList(),
                  'Pending',
                ),
                _buildRequestsList(
                  context,
                  allRequests
                      .where((r) => r.status == LeaveRequestStatus.approved)
                      .toList(),
                  'Approved',
                ),
                _buildRequestsList(
                  context,
                  allRequests
                      .where((r) => r.status == LeaveRequestStatus.denied)
                      .toList(),
                  'Denied',
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToSubmitLeaveRequest(context),
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Submit New Request',
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    List<LeaveRequest> requests,
    String category,
  ) {
    if (requests.isEmpty) {
      return _buildEmptyState(context, category);
    }

    // Sort requests by submission date (newest first)
    requests.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildLeaveRequestCard(context, request, index == 0);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String category) {
    IconData icon;
    String title;
    String subtitle;

    switch (category.toLowerCase()) {
      case 'pending':
        icon = Icons.pending;
        title = 'No Pending Requests';
        subtitle = 'You have no pending leave requests at the moment.';
        break;
      case 'approved':
        icon = Icons.check_circle;
        title = 'No Approved Requests';
        subtitle = 'You have no approved leave requests.';
        break;
      case 'denied':
        icon = Icons.cancel;
        title = 'No Denied Requests';
        subtitle = 'You have no denied leave requests.';
        break;
      default:
        icon = Icons.event_note;
        title = 'No Leave Requests';
        subtitle = 'You haven\'t submitted any leave requests yet.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (category.toLowerCase() == 'all') ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _navigateToSubmitLeaveRequest(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Submit Your First Request'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveRequestCard(
    BuildContext context,
    LeaveRequest request,
    bool isLatest,
  ) {
    final statusColor = _getStatusColor(request.status);
    final duration = request.endDate.difference(request.startDate).inDays + 1;
    final isActive =
        request.status == LeaveRequestStatus.approved &&
        DateTime.now().isAfter(request.startDate) &&
        DateTime.now().isBefore(request.endDate.add(const Duration(days: 1)));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isLatest ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            isLatest
                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToLeaveRequestDetails(context, request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isLatest) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'LATEST',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (isActive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                request.status.value.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateFormat('MMM d').format(request.startDate)} - ${DateFormat('MMM d, y').format(request.endDate)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$duration day${duration > 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM d').format(request.submittedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.reason,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (request.reviewComments != null &&
                  request.reviewComments!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          request.reviewComments!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(LeaveRequestStatus status) {
    switch (status) {
      case LeaveRequestStatus.pending:
        return Colors.orange;
      case LeaveRequestStatus.approved:
        return Colors.green;
      case LeaveRequestStatus.denied:
        return Colors.red;
    }
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
            _fetchLeaveRequests();
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
}
