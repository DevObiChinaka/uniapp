class Program {
  final int id;
  final String name;

  Program({required this.id, required this.name});

  factory Program.fromJson(Map<String, dynamic> json) {
    return Program(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
