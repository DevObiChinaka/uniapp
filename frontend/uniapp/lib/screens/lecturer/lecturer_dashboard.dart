import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/program.dart';

class LecturerDashboard extends StatefulWidget {
  const LecturerDashboard({super.key});

  @override
  State<LecturerDashboard> createState() => _LecturerDashboardState();
}

class _LecturerDashboardState extends State<LecturerDashboard> {
  Future<List<Session>>? _sessionsFuture;
  String? _lecturerUsername;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    (() async {
      await appProvider.loadUserData();
      await appProvider.fetchPrograms();
      setState(() {
        _lecturerUsername =
            appProvider.getCurrentUser()?.username ?? appProvider.userId ?? '';
        _sessionsFuture = appProvider.fetchLecturerSessions(_lecturerUsername!);
      });
    })();
  }

  Future<void> _refreshDashboard() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.loadUserData();
    await appProvider.fetchPrograms();
    setState(() {
      _lecturerUsername =
          appProvider.getCurrentUser()?.username ?? appProvider.userId ?? '';
      _sessionsFuture = appProvider.fetchLecturerSessions(_lecturerUsername!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    String getProgramName(String programId) {
      final programObj = appProvider.programs.firstWhere(
        (p) => p.id.toString() == programId,
        orElse: () => Program(id: 0, name: programId),
      );
      return programObj.name;
    }

    return RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: FutureBuilder<List<Session>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (_sessionsFuture == null ||
              snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: Text('Lecturer Home')),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text('Lecturer Home')),
              body: Center(child: Text('Error loading dashboard')),
            );
          }
          final sessions = snapshot.data ?? [];
          final Session? activeSession =
              sessions.where((s) => s.isActive).isNotEmpty
                  ? sessions.firstWhere((s) => s.isActive)
                  : null;
          final attendanceStats = appProvider.getUserAttendanceStats();
          return Scaffold(
            appBar: AppBar(title: Text('Lecturer Home')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  if (activeSession != null) ...[
                    Text(
                      'Active Session:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Card(
                      child: ListTile(
                        title: Text(getProgramName(activeSession.program)),
                        subtitle: Text(
                          'Started: ${activeSession.startTime.toString()}',
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  Text(
                    'Attendance Stats:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...attendanceStats.entries.map(
                    (e) => ListTile(
                      title: Text(getProgramName(e.key)),
                      trailing: Text('Count: ${e.value}'),
                    ),
                  ),
                  SizedBox(height: 16),
                  if (sessions.isNotEmpty) ...[
                    Text(
                      'Recent Sessions:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...sessions
                        .take(3)
                        .map(
                          (session) => Card(
                            child: ListTile(
                              title: Text(getProgramName(session.program)),
                              subtitle: Text(
                                'Started: ${session.startTime.toString()}',
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
