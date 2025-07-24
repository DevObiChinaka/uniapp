import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/utils.dart';

class LeaveRequestItem extends StatelessWidget {
  final LeaveRequest leave;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const LeaveRequestItem({
    super.key,
    required this.leave,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Icon(Icons.event_note, color: Colors.indigo),
        ),
        title: Text(
          leave.studentName ?? 'Unknown Student',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Matriculation Number: ${leave.studentUniversityId ?? 'N/A'}'),
            Text(
              'Period: ${Utils.formatDate(leave.startDate)} - ${Utils.formatDate(leave.endDate)}',
            ),
            Text('Reason: ${leave.reason}'),
            Text(
              'Status: ${leave.status.value.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _statusColor(leave.status.value),
              ),
            ),
          ],
        ),
        trailing:
            leave.status == LeaveRequestStatus.pending
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: onApprove,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: onReject,
                    ),
                  ],
                )
                : null,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
