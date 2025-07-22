import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';

class FlaggedStudentsScreen extends StatelessWidget {
  final String sessionId;
  const FlaggedStudentsScreen({Key? key, required this.sessionId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final flaggedStudents = appProvider.getFlaggedStudentsForSession(sessionId);

    return Scaffold(
      appBar: AppBar(title: const Text('Flagged Students')),
      body:
          flaggedStudents.isEmpty
              ? const Center(
                child: Text('No flagged students for this session.'),
              )
              : ListView.separated(
                itemCount: flaggedStudents.length,
                separatorBuilder: (_, __) => Divider(height: 1),
                itemBuilder: (context, index) {
                  final student = flaggedStudents[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        student.name.isNotEmpty ? student.name[0] : '?',
                      ),
                    ),
                    title: Text(
                      student.name,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('ID: ${student.universityId ?? student.id}'),
                    trailing: const Icon(Icons.warning, color: Colors.red),
                  );
                },
              ),
    );
  }
}
