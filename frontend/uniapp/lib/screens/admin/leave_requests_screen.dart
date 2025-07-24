// Leave Requests screen for admin
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../app_provider.dart';
import '../../widgets/admin/leave_request_item.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final allRequests = provider.allLeaveRequests;
        final pending =
            allRequests
                .where((l) => l.status == LeaveRequestStatus.pending)
                .toList();
        final approved =
            allRequests
                .where((l) => l.status == LeaveRequestStatus.approved)
                .toList();
        final denied =
            allRequests
                .where((l) => l.status == LeaveRequestStatus.denied)
                .toList();

        return SafeArea(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(context, pending, provider),
                    _buildList(context, approved, provider),
                    _buildList(context, denied, provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<LeaveRequest> requests,
    AppProvider provider,
  ) {
    if (requests.isEmpty) {
      return Center(child: Text('No leave requests found.'));
    }
    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final leave = requests[index];
        return LeaveRequestItem(
          leave: leave,
          onApprove:
              leave.status == LeaveRequestStatus.pending
                  ? () async {
                    await provider.updateLeaveStatus(
                      leave.id,
                      LeaveRequestStatus.approved,
                    );
                    setState(() {});
                  }
                  : null,
          onReject:
              leave.status == LeaveRequestStatus.pending
                  ? () => _showDenyDialog(context, provider, leave)
                  : null,
        );
      },
    );
  }

  void _showDenyDialog(
    BuildContext context,
    AppProvider provider,
    LeaveRequest leave,
  ) {
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
                onPressed: () async {
                  final comments = controller.text.trim();
                  await provider.updateLeaveStatusWithComments(
                    leave.id,
                    LeaveRequestStatus.denied,
                    comments.isEmpty ? null : comments,
                  );
                  setState(() {});
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Confirm Denial'),
              ),
            ],
          ),
    );
  }
}
