// System Logs screen for admin
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore: unused_import
import '../../models/models.dart';
import '../app_provider.dart';
import '../../utils/utils.dart';

class SystemLogsScreen extends StatefulWidget {
  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  String _searchText = '';
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final logs =
            provider.systemLogs
                .where(
                  (log) =>
                      _searchText.isEmpty ||
                      log.event.toLowerCase().contains(
                        _searchText.toLowerCase(),
                      ) ||
                      (log.details?.toLowerCase().contains(
                            _searchText.toLowerCase(),
                          ) ??
                          false),
                )
                .toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Search logs',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchText = val.trim()),
                ),
              ),
              Expanded(
                child:
                    logs.isEmpty
                        ? Center(child: Text('No system logs found.'))
                        : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  _logIcon(log.type),
                                  color: Theme.of(context).primaryColor,
                                ),
                                title: Text(
                                  log.event,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(Utils.formatDateTime(log.timestamp)),
                                    if (log.details != null)
                                      Text(
                                        log.details!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  log.timeAgo,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          },
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
