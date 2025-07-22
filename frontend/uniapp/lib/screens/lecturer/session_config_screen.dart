import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../models/program.dart';

class SessionConfigScreen extends StatefulWidget {
  final Session session;
  const SessionConfigScreen({Key? key, required this.session})
    : super(key: key);

  @override
  State<SessionConfigScreen> createState() => _SessionConfigScreenState();
}

class _SessionConfigScreenState extends State<SessionConfigScreen> {
  late TextEditingController _programController;
  late TextEditingController _totalSessionsController;
  late TextEditingController _passThresholdController;
  bool _isSaving = false;

  List<Program> _programs = [];
  String? _selectedProgramId;

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    (() async {
      await appProvider.fetchPrograms();
      setState(() {
        _programs = appProvider.programs;
        _selectedProgramId = widget.session.program;
      });
    })();
    _programController = TextEditingController(text: widget.session.program);
    _totalSessionsController = TextEditingController(
      text: widget.session.totalSessions.toString(),
    );
    _passThresholdController = TextEditingController(
      text: (widget.session.passThreshold * 100).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _programController.dispose();
    _totalSessionsController.dispose();
    _passThresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final program = _selectedProgramId ?? _programController.text.trim();
    final totalSessions = int.tryParse(_totalSessionsController.text.trim());
    final passThresholdRaw = double.tryParse(
      _passThresholdController.text.trim(),
    );
    final passThreshold =
        passThresholdRaw != null ? passThresholdRaw / 100 : null;

    if (program.isEmpty ||
        totalSessions == null ||
        passThreshold == null ||
        passThreshold <= 0 ||
        passThreshold > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid session details.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final updatedSession = widget.session.copyWith(
        program: program,
        totalSessions: totalSessions,
        passThreshold: passThreshold,
      );
      await appProvider.updateSession(updatedSession);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session updated successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Configuration')),
      body:
          _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedProgramId,
                      items:
                          _programs
                              .map(
                                (p) => DropdownMenuItem<String>(
                                  value: p.id.toString(),
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedProgramId = val;
                          _programController.text = val ?? '';
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Program'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _totalSessionsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Total Sessions',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passThresholdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Pass Threshold (%)',
                      ),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      onPressed: _isSaving ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
