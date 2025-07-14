import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/utils/utils.dart';

class EmergencyExitScreen extends StatefulWidget {
  const EmergencyExitScreen({Key? key}) : super(key: key);

  @override
  _EmergencyExitScreenState createState() => _EmergencyExitScreenState();
}

class _EmergencyExitScreenState extends State<EmergencyExitScreen> {
  final _formKey = GlobalKey<FormState>();
  String _reason = '';
  bool _isSubmitting = false;

  Future<void> _submitEmergencyExit() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final success = await appProvider.requestEmergencyExit(_reason);
      
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Emergency exit request sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send emergency exit request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Exit'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Emergency Exit Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use this form only for genuine emergencies that require immediate campus exit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red[800]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Reason for emergency exit',
                  border: OutlineInputBorder(),
                  hintText: 'Explain the emergency situation',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for your emergency exit request';
                  }
                  if (value.trim().length < 10) {
                    return 'Please provide more details about the emergency';
                  }
                  return null;
                },
                onSaved: (value) => _reason = value!.trim(),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitEmergencyExit,
                child: _isSubmitting
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      )
                    : Text('Submit Emergency Exit Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
