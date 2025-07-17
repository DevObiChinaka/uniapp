import 'package:flutter/material.dart';
import '../../models/models.dart';

class StudentListItem extends StatelessWidget {
  final User student;
  final VoidCallback onTap;
  const StudentListItem({Key? key, required this.student, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.indigo.shade100,
        backgroundImage:
            student.profilePictureUrl != null
                ? NetworkImage(student.profilePictureUrl!)
                : null,
        child:
            student.profilePictureUrl == null
                ? Icon(Icons.person, color: Colors.indigo)
                : null,
      ),
      title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('Matric No: ${student.universityId ?? 'N/A'}'),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}
