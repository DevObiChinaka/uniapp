import 'package:flutter/foundation.dart';
import 'program.dart' as prog;

@immutable
class Course {
  final String id;
  final String name;
  final List<prog.Program> programs;
  final String level;

  const Course({
    required this.id,
    required this.name,
    required this.programs,
    required this.level,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final programsJson = json['programs'] as List<dynamic>? ?? [];
    final programs =
        programsJson
            .map(
              (p) =>
                  p is Map<String, dynamic>
                      ? prog.Program.fromJson(p)
                      : prog.Program(id: 0, name: p.toString()),
            )
            .toList();
    return Course(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      programs: programs,
      level: json['level']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'programs': programs.map((p) => p.toJson()).toList(),
      'level': level,
    };
  }
}
