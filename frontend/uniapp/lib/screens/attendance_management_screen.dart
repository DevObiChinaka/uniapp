import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/models/models.dart';

List<String> _flaggedStudentIds = [];

class AttendanceManagementScreen extends StatefulWidget {
  final String sessionId;
  final String program;

  const AttendanceManagementScreen({
    super.key,
    required this.sessionId,
    required this.program,
  });

  @override
  _AttendanceManagementScreenState createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<User> _selectedStudents = [];
  List<User> _allStudents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadFlaggedStudents();
  }

  void _loadFlaggedStudents() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final flagged = provider.getFlaggedStudentsForSession(widget.sessionId);
    setState(() {
      _flaggedStudentIds = flagged.map((u) => u.id).toList();
    });
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

  List<User> get _filteredStudents {
    if (_searchQuery.isEmpty) return _allStudents;
    return _allStudents.where((student) {
      return student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          student.id.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  bool _isAttending(User student) {
    return _selectedStudents.any((s) => s.id == student.id);
  }

  void _toggleStudentAttendance(User student) {
    setState(() {
      if (_isAttending(student)) {
        _selectedStudents.removeWhere((s) => s.id == student.id);
      } else {
        _selectedStudents.add(student);
      }
    });
  }

  Future<void> _saveManualAttendance() async {
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No students selected')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);

      await provider.markManualAttendance(
        studentIds: _selectedStudents.map((s) => s.id).toList(),
        // sessionId removed, now uses active session from AppProvider
        program: widget.program,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance saved for ${_selectedStudents.length} students',
          ),
        ),
      );

      Navigator.of(context).pop(true); // Return success
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
      appBar: AppBar(
        title: Text('Manage Attendance'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected: ${_selectedStudents.length}/${_allStudents.length}',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final isSelected = _isAttending(student);
                        final isFlagged = _flaggedStudentIds.contains(
                          student.id,
                        );

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(student.name.substring(0, 1)),
                          ),
                          title: Row(
                            children: [
                              Text(
                                student.name,
                                style: TextStyle(
                                  color: isFlagged ? Colors.red : null,
                                  fontWeight:
                                      isFlagged ? FontWeight.bold : null,
                                ),
                              ),
                              if (isFlagged)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Icon(
                                    Icons.warning,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text('ID: ${student.id}'),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              _toggleStudentAttendance(student);
                            },
                          ),
                          onTap: () => _toggleStudentAttendance(student),
                        );
                      },
                    ),
                  ),
                ],
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveManualAttendance,
        label: Text('Save Attendance'),
        icon: Icon(Icons.save),
      ),
    );
  }
}
