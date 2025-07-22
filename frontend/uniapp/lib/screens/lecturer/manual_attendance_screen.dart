import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';

class ManualAttendanceScreen extends StatefulWidget {
  final Session session;
  const ManualAttendanceScreen({Key? key, required this.session})
    : super(key: key);

  @override
  _ManualAttendanceScreenState createState() => _ManualAttendanceScreenState();
}

class _ManualAttendanceScreenState extends State<ManualAttendanceScreen> {
  List<User> _allStudents = [];
  List<User> _selectedStudents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      _allStudents = await provider.fetchAllStudents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load students: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleStudent(User student) {
    setState(() {
      if (_selectedStudents.contains(student)) {
        _selectedStudents.remove(student);
      } else {
        _selectedStudents.add(student);
      }
    });
  }

  Future<void> _saveAttendance() async {
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No students selected')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.markManualAttendance(
        studentIds: _selectedStudents.map((s) => s.id).toList(),
        // sessionId removed, now uses active session from AppProvider
        program: widget.session.program,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance saved for ${_selectedStudents.length} students',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Attendance')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected: ${_selectedStudents.length}/${_allStudents.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedStudents.length ==
                                  _allStudents.length) {
                                _selectedStudents.clear();
                              } else {
                                _selectedStudents = List.from(_allStudents);
                              }
                            });
                          },
                          child: Text(
                            _selectedStudents.length == _allStudents.length
                                ? 'Deselect All'
                                : 'Select All',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _allStudents.length,
                      itemBuilder: (context, index) {
                        final student = _allStudents[index];
                        final isSelected = _selectedStudents.contains(student);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              student.name.isNotEmpty ? student.name[0] : '?',
                            ),
                          ),
                          title: Text(student.name),
                          subtitle: Text(
                            'ID: ${student.universityId ?? student.id}',
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (val) => _toggleStudent(student),
                          ),
                          onTap: () => _toggleStudent(student),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAttendance,
        label: const Text('Save Attendance'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}
