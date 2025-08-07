import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_provider.dart';
import '../../models/models.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen>
    with AutomaticKeepAliveClientMixin {
  List<SecurityLog> _logs = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  DateTime? _selectedDate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSecurityLogs();
  }

  Future<void> _loadSecurityLogs() async {
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);

      // Get security logs from API
      final logsData = await provider.coreServices.getSecurityLogs(
        date: _selectedDate?.toIso8601String().split('T').first,
        type: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      debugPrint('Security logs loaded: ${logsData.length} logs');

      final logs =
          logsData.map((data) {
            return SecurityLog(
              id:
                  data['id']?.toString() ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              timestamp:
                  data['timestamp'] != null
                      ? DateTime.parse(data['timestamp'])
                      : DateTime.now(),
              type: data['type']?.toString() ?? 'system',
              studentId: data['student_id']?.toString(),
              studentName: data['student_name']?.toString(),
              action:
                  data['action']?.toString() ??
                  data['message']?.toString() ??
                  'Unknown action',
              securityOfficer:
                  data['security_officer']?.toString() ??
                  data['processed_by']?.toString() ??
                  'System',
              status: data['status']?.toString() ?? 'completed',
            );
          }).toList();

      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading security logs: $e');
      setState(() => _isLoading = false);
    }
  }

  List<SecurityLog> get _filteredLogs {
    var filtered = _logs;

    // Filter by type
    if (_selectedFilter != 'all') {
      filtered = filtered.where((log) => log.type == _selectedFilter).toList();
    }

    // Filter by date
    if (_selectedDate != null) {
      filtered =
          filtered.where((log) {
            return log.timestamp.year == _selectedDate!.year &&
                log.timestamp.month == _selectedDate!.month &&
                log.timestamp.day == _selectedDate!.day;
          }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Security Logs',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Logs',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSecurityLogs,
        child: Column(
          children: [
            // Filter Bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Expanded(child: _buildFilterChip('All', 'all')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildFilterChip('Exits', 'exit')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildFilterChip('Returns', 'return')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildFilterChip('System', 'system')),
                ],
              ),
            ),

            // Date Filter
            if (_selectedDate != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Colors.blue[50],
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Showing logs for ${DateFormat('MMM dd, yyyy').format(_selectedDate!)}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedDate = null),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),

            // Logs List
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredLogs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return _buildLogCard(log);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildLogCard(SecurityLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLogIcon(log.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.action,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM dd, yyyy • HH:mm:ss',
                        ).format(log.timestamp),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(log.status),
              ],
            ),

            if (log.studentName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '${log.studentName} (${log.studentId})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'exit':
        icon = Icons.exit_to_app;
        color = Colors.orange;
        break;
      case 'return':
        icon = Icons.login;
        color = Colors.green;
        break;
      case 'system':
        icon = Icons.settings;
        color = Colors.blue;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'denied':
        color = Colors.red;
        label = 'Denied';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Completed';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No security logs found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Security activities will appear here'
                : 'No logs found for the selected filter',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadSecurityLogs,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Filter Logs'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Select Date'),
                  subtitle: Text(
                    _selectedDate == null
                        ? 'All dates'
                        : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                  ),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                if (_selectedDate != null)
                  ListTile(
                    title: const Text('Clear Date Filter'),
                    trailing: const Icon(Icons.clear),
                    onTap: () {
                      setState(() => _selectedDate = null);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

// Security Log Model
class SecurityLog {
  final String id;
  final DateTime timestamp;
  final String type; // 'exit', 'return', 'system'
  final String? studentId;
  final String? studentName;
  final String action;
  final String securityOfficer;
  final String status; // 'approved', 'denied', 'completed'

  SecurityLog({
    required this.id,
    required this.timestamp,
    required this.type,
    this.studentId,
    this.studentName,
    required this.action,
    required this.securityOfficer,
    required this.status,
  });

  factory SecurityLog.fromJson(Map<String, dynamic> json) {
    return SecurityLog(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: json['type'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      action: json['action'],
      securityOfficer: json['security_officer'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'student_id': studentId,
      'student_name': studentName,
      'action': action,
      'security_officer': securityOfficer,
      'status': status,
    };
  }
}
