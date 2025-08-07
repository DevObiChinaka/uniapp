import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import 'package:intl/intl.dart';

class ExitHistoryScreen extends StatefulWidget {
  const ExitHistoryScreen({super.key});

  @override
  State<ExitHistoryScreen> createState() => _ExitHistoryScreenState();
}

class _ExitHistoryScreenState extends State<ExitHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchExitHistory();
    });
  }

  Future<void> _fetchExitHistory() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.fetchExitHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exit History'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExitHistory,
        child: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final exitHistory = provider.exitHistory;

            if (provider.isLoading && exitHistory.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (exitHistory.isEmpty) {
              return _buildEmptyState(context);
            }

            return _buildExitHistoryList(context, exitHistory);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.exit_to_app, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Exit History',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your campus exit records will appear here.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExitHistoryList(
    BuildContext context,
    List<ExitLog> exitHistory,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exitHistory.length,
      itemBuilder: (context, index) {
        final exitLog = exitHistory[index];
        return _buildExitLogCard(context, exitLog);
      },
    );
  }

  Widget _buildExitLogCard(BuildContext context, ExitLog exitLog) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: exitLog.statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          exitLog.allowed ? Icons.check_circle : Icons.cancel,
                          color: exitLog.statusColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Campus Exit ${exitLog.statusText}',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: exitLog.statusColor,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'MMM d, y • h:mm a',
                              ).format(exitLog.timestamp),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: exitLog.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    exitLog.timeAgo,
                    style: TextStyle(
                      color: exitLog.statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(context, 'Reason', exitLog.reason),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    context,
                    'Face Verification',
                    exitLog.faceVerified ? 'Verified' : 'Not Verified',
                  ),
                ),
                if (exitLog.qrData.isNotEmpty)
                  Expanded(
                    child: _buildDetailRow(
                      context,
                      'QR Code',
                      exitLog.qrData.length > 10
                          ? '${exitLog.qrData.substring(0, 10)}...'
                          : exitLog.qrData,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
