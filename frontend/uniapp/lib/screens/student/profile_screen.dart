import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../app_provider.dart';
import '../../routes/app_routes.dart';
import '../change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final user = provider.getCurrentUser();
          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No profile data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadUserData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          debugPrint('StudentProfileScreen user.email: ${user.email}');
          debugPrint(
            'StudentProfileScreen user.universityId: ${user.universityId}',
          );
          debugPrint(
            'StudentProfileScreen user.program: ${user.program?.name}',
          );
          debugPrint('StudentProfileScreen user.level: ${user.level}');
          debugPrint(
            'StudentProfileScreen user.isOnCampus: ${user.isOnCampus}',
          );

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
                              icon: const Icon(
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
                                      const SnackBar(
                                        content: Text(
                                          'Uploading profile picture...',
                                        ),
                                      ),
                                    );
                                    // Simulate upload delay
                                    await Future.delayed(
                                      const Duration(seconds: 2),
                                    );
                                    // TODO: Replace with actual upload logic and updateUserProfile call
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile picture updated!',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Student details card
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
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
                          profileRow(Icons.email, 'Email', user.email ?? 'N/A'),
                          const Divider(),
                          profileRow(Icons.badge, 'Role', user.role),
                        ],
                      ),
                    ),
                  ),
                  // Academic details card
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Academic Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          profileRow(
                            Icons.school,
                            'University ID',
                            user.universityId ?? 'N/A',
                          ),
                          const Divider(),
                          profileRow(
                            Icons.book,
                            'Program',
                            user.program?.name ?? 'N/A',
                          ),
                          const Divider(),
                          profileRow(Icons.grade, 'Level', user.level ?? 'N/A'),
                        ],
                      ),
                    ),
                  ),
                  // Campus status card (read-only for students)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campus Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          profileRow(
                            user.isOnCampus
                                ? Icons.location_on
                                : Icons.location_off,
                            'Campus Status',
                            user.isOnCampus ? 'On Campus' : 'Off Campus',
                          ),
                          if (user.lastActivity != null) ...[
                            const Divider(),
                            profileRow(
                              Icons.access_time,
                              'Last Activity',
                              _formatLastActivity(user.lastActivity!),
                            ),
                          ],
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
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  try {
                                    await provider.updateUserProfile({
                                      'first_name': firstName,
                                      'last_name': lastName,
                                      'email': email,
                                    });
                                    await provider.loadUserData();
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile updated successfully',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to update profile',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Change Password button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ChangePasswordScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock),
                      label: const Text('Change Password'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Logout button
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
                          context.go(AppRoutes.login);
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
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
      ),
    );
  }

  String _formatLastActivity(DateTime lastActivity) {
    final now = DateTime.now();
    final difference = now.difference(lastActivity);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'over a week ago';
    }
  }
}

Widget profileRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, color: Colors.grey[600], size: 20),
      const SizedBox(width: 12),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
    ],
  );
}

class EditProfileDialog extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final void Function(String, String, String) onSave;

  const EditProfileDialog({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.onSave,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();

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
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'First name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Last name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSave(
                _firstNameController.text.trim(),
                _lastNameController.text.trim(),
                _emailController.text.trim(),
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
