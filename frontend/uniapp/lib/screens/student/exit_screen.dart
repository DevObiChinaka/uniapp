import 'package:flutter/material.dart';

class ExitScreen extends StatelessWidget {
  const ExitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exit & Leave Requests')),
      body: Center(child: Text('Exit and leave request features go here.')),
    );
  }
}
