// Profile screen for admin
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
// import '../../models/models.dart';
import '../app_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final user = provider.getCurrentUser();
        if (user == null) {
          return Center(child: Text('No profile data found.'));
        }
        debugPrint('ProfileScreen user.email: \\${user.email}');
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Profile picture
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[300],
                        backgroundImage:
                            user.profilePictureUrl != null
                                ? NetworkImage(user.profilePictureUrl!)
                                : null,
                        child:
                            user.profilePictureUrl == null
                                ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[600],
                                )
                                : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 512,
                                maxHeight: 512,
                                imageQuality: 80,
                              );
                              if (picked != null) {
                                try {
                                  // TODO: Upload to Firebase Storage and get URL
                                  // For now, just show a snackbar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Uploading profile picture...',
                                      ),
                                    ),
                                  );
                                  // Simulate upload delay
                                  await Future.delayed(Duration(seconds: 2));
                                  // TODO: Replace with actual upload logic and updateUserProfile call
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Profile picture updated!'),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to upload profile picture',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  user.name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Details
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profileRow(
                          Icons.person,
                          'First Name',
                          user.firstName ?? 'N/A',
                        ),
                        const Divider(),
                        profileRow(
                          Icons.person_outline,
                          'Last Name',
                          user.lastName ?? 'N/A',
                        ),
                        const Divider(),
                        profileRow(
                          Icons.account_circle,
                          'Username',
                          user.username ?? 'N/A',
                        ),
                        const Divider(),
                        profileRow(Icons.email, 'Email', user.email ?? 'N/A'),
                        const Divider(),
                        profileRow(
                          Icons.admin_panel_settings,
                          'Role',
                          user.role,
                        ),
                      ],
                    ),
                  ),
                ),
                // Edit profile button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => EditProfileDialog(
                              firstName: user.firstName ?? '',
                              lastName: user.lastName ?? '',
                              email: user.email ?? '',
                              onSave: (firstName, lastName, email) async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                );
                                try {
                                  await provider.updateUserProfile({
                                    'first_name': firstName,
                                    'last_name': lastName,
                                    'email': email,
                                  });
                                  await provider.loadUserData();
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Profile updated successfully',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update profile'),
                                    ),
                                  );
                                }
                              },
                            ),
                      );
                    },
                    icon: Icon(Icons.edit),
                    label: Text('Edit Profile'),
                  ),
                ),
                const SizedBox(height: 16),
                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement logout logic
                    },
                    icon: Icon(Icons.logout),
                    label: Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget profileRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, color: Colors.grey[600], size: 20),
      SizedBox(width: 12),
      Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 16))),
    ],
  );
}

class EditProfileDialog extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final void Function(String, String, String) onSave;

  const EditProfileDialog({
    Key? key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName);
    _lastNameController = TextEditingController(text: widget.lastName);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _firstNameController,
              decoration: InputDecoration(labelText: 'First Name'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _lastNameController,
              decoration: InputDecoration(labelText: 'Last Name'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              _firstNameController.text.trim(),
              _lastNameController.text.trim(),
              _emailController.text.trim(),
            );
            Navigator.of(context).pop();
          },
          child: Text('Save'),
        ),
      ],
    );
  }
}
