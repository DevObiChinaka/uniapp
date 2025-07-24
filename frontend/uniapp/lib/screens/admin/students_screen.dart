// Students screen for admin
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../app_provider.dart';
import '../../widgets/admin/student_list_item.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _searchText = '';
  final TextEditingController _controller = TextEditingController();
  List<User> _suggestions = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(List<User> students) {
    setState(() {
      _searchText = _controller.text.trim();
      if (_searchText.isEmpty) {
        _suggestions = students;
      } else {
        _suggestions =
            students
                .where(
                  (s) => (s.universityId ?? '').toLowerCase().contains(
                    _searchText.toLowerCase(),
                  ),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final students =
            provider.allStudents.where((u) => u.role == 'student').toList();
        if (_suggestions.isEmpty && _searchText.isEmpty) {
          _suggestions = students;
        }
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: 'Search by Matriculation Number',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => _onSearchChanged(students),
                ),
              ),
              Expanded(
                child:
                    _suggestions.isEmpty
                        ? Center(child: Text('No students found.'))
                        : ListView.builder(
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final student = _suggestions[index];
                            return StudentListItem(
                              student: student,
                              onTap:
                                  () => _showStudentDetails(context, student),
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

  void _showStudentDetails(BuildContext context, User student) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    bool isOnCampus = student.isOnCampus;
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(student.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matriculation Number: ${student.universityId ?? 'N/A'}',
                      ),
                      Text('Program: ${student.program ?? 'N/A'}'),
                      Text('Email: ${student.email ?? 'N/A'}'),
                      Text('Status: ${student.campusTag ?? 'N/A'}'),
                      Row(
                        children: [
                          Icon(
                            isOnCampus ? Icons.location_on : Icons.location_off,
                            color: isOnCampus ? Colors.green : Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(isOnCampus ? 'On Campus' : 'Off Campus'),
                          Spacer(),
                          Switch(
                            value: isOnCampus,
                            onChanged: (value) async {
                              setState(() => isOnCampus = value);
                              await provider.updateCampusTag(student.id, value);
                            },
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }
}
