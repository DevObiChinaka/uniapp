import 'package:flutter/material.dart';
import 'package:uniapp/services/biometric_service.dart';
import 'package:uniapp/screens/change_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String universityId;
  final String role;

  const ProfileScreen({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.universityId,
    required this.role,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String firstName;
  late String lastName;
  bool isBiometricEnabled = false;
  final biometricService = BiometricService();

  // Biometric timeout options
  final List<Map<String, dynamic>> _timeoutOptions = [
    {'label': 'Immediately', 'value': 0},
    {'label': 'After 1 min', 'value': 60},
    {'label': 'After 5 min', 'value': 300},
    {'label': 'After 15 min', 'value': 900},
    {'label': 'After 1 hr', 'value': 3600},
  ];
  int _selectedTimeout = 0;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
    firstName = widget.firstName;
    lastName = widget.lastName;
    _loadTimeout();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await biometricService.isBiometricEnabled();
    setState(() => isBiometricEnabled = enabled);
  }

  Future<void> _onToggleBiometric(bool value) async {
    if (value) {
      final hasSupport = await biometricService.hasBiometricSupport();
      if (!hasSupport) {
        _showSnackBar('Biometric not supported on this device');
        return;
      }

      final hasEnrolled = await biometricService.hasBiometricsEnrolled();
      if (!hasEnrolled) {
        _showSnackBar(
          'No biometrics enrolled. Please set up biometrics in your device settings.',
        );
        return;
      }

      final authenticated = await biometricService.authenticate(
        "Enable fingerprint login",
      );
      if (!authenticated) {
        _showSnackBar('Authentication failed. Biometric not enabled.');
        return;
      }

      await biometricService.setBiometricEnabled(true);
      setState(() => isBiometricEnabled = true);
    } else {
      await biometricService.disableBiometric();
      setState(() => isBiometricEnabled = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProfileInfo() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundImage: AssetImage('assets/images/profile_placeholder.png'),
        ),
        const SizedBox(height: 16),
        Text(
          "$firstName $lastName",
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(widget.universityId, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _loadTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTimeout = prefs.getInt('biometric_timeout') ?? 0;
    });
  }

  Future<void> _saveTimeout(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('biometric_timeout', value);
    setState(() {
      _selectedTimeout = value;
    });
  }

  Widget _buildTimeoutDropdown() {
    return ListTile(
      leading: const Icon(Icons.timer),
      title: const Text('Biometric Timeout'),
      subtitle: Text(
        _timeoutOptions.firstWhere(
          (opt) => opt['value'] == _selectedTimeout,
        )['label'],
      ),
      trailing: DropdownButton<int>(
        value: _selectedTimeout,
        items:
            _timeoutOptions
                .map(
                  (opt) => DropdownMenuItem<int>(
                    value: opt['value'],
                    child: Text(opt['label']),
                  ),
                )
                .toList(),
        onChanged: (val) {
          if (val != null) _saveTimeout(val);
        },
      ),
    );
  }

  Widget _buildMenuOptions() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text("Edit Profile"),
          onTap: () async {
            final updated = await Navigator.pushNamed(context, '/edit_profile');
            if (updated is Map && mounted) {
              setState(() {
                firstName = updated['first_name'];
                lastName = updated['last_name'];
              });
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.lock),
          title: const Text("Change Password"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            );
          },
        ),
        SwitchListTile(
          value: isBiometricEnabled,
          title: const Text("Enable Fingerprint Login"),
          secondary: const Icon(Icons.fingerprint),
          onChanged: _onToggleBiometric,
        ),
        _buildTimeoutDropdown(), // <-- Add timeout dropdown to menu
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text("Logout"),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_logged_in', false);
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [_buildProfileInfo(), _buildMenuOptions()]),
      ),
    );
  }
}
