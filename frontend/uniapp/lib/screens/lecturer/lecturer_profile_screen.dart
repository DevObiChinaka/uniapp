import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../app_provider.dart';
import '../../models/models.dart';

class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({Key? key}) : super(key: key);

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  User? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = Provider.of<AppProvider>(context, listen: false);
    try {
      await provider.loadUserData();
      final user = provider.getCurrentUser();
      if (user == null) {
        // fallback to cached user
        setState(() {
          _user = provider.getCurrentUser();
          _error = 'No profile data found.';
        });
      } else {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      // fallback to cached user
      setState(() {
        _user = provider.getCurrentUser();
        _error = 'Could not fetch profile. Showing cached info.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (_user == null) {
      return Center(child: Text(_error ?? 'No profile data found.'));
    }
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          _user!.profilePictureUrl != null
                              ? NetworkImage(_user!.profilePictureUrl!)
                              : null,
                      child:
                          _user!.profilePictureUrl == null
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Uploading profile picture...',
                                    ),
                                  ),
                                );
                                final String fileName =
                                    'profile_${_user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                final Reference storageRef = FirebaseStorage
                                    .instance
                                    .ref()
                                    .child('profile_pictures/$fileName');
                                final UploadTask uploadTask = storageRef
                                    .putFile(File(picked.path));
                                final TaskSnapshot snapshot = await uploadTask;
                                final String downloadUrl =
                                    await snapshot.ref.getDownloadURL();
                                final provider = Provider.of<AppProvider>(
                                  context,
                                  listen: false,
                                );
                                await provider.updateUserProfile({
                                  'profile_picture': downloadUrl,
                                });
                                await _fetchProfile();
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
              Text(
                _user!.name,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                        _user!.firstName ?? 'N/A',
                      ),
                      const Divider(),
                      profileRow(
                        Icons.person_outline,
                        'Last Name',
                        _user!.lastName ?? 'N/A',
                      ),
                      const Divider(),
                      profileRow(
                        Icons.account_circle,
                        'Username',
                        _user!.username ?? 'N/A',
                      ),
                      const Divider(),
                      profileRow(Icons.email, 'Email', _user!.email ?? 'N/A'),
                      const Divider(),
                      profileRow(
                        Icons.admin_panel_settings,
                        'Role',
                        _user!.role,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => EditProfileDialog(
                            firstName: _user!.firstName ?? '',
                            lastName: _user!.lastName ?? '',
                            email: _user!.email ?? '',
                            onSave: (firstName, lastName, email) async {
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              try {
                                final provider = Provider.of<AppProvider>(
                                  context,
                                  listen: false,
                                );
                                await provider.updateUserProfile({
                                  'first_name': firstName,
                                  'last_name': lastName,
                                  'email': email,
                                });
                                await _fetchProfile();
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final provider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    final success = await provider.logout();
                    if (success && context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    }
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
      ),
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
