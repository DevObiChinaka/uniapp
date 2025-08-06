import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import '../app_provider.dart';
import '../../models/models.dart';
import '../../routes/app_routes.dart';
import '../change_password_screen.dart';

class LecturerProfileScreen extends StatefulWidget {
  const LecturerProfileScreen({super.key});

  @override
  State<LecturerProfileScreen> createState() => _LecturerProfileScreenState();
}

class _LecturerProfileScreenState extends State<LecturerProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _loggingOut = false;
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading profile...',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                _error ?? 'No profile data found.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchProfile,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loggingOut ? null : _handleLogout,
            icon:
                _loggingOut
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Icon(Icons.logout),
            tooltip: _loggingOut ? 'Logging out...' : 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Header Section with Profile Picture
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(height: 20),
                    // Profile Picture with Edit Button
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                _user!.profilePictureUrl != null
                                    ? NetworkImage(_user!.profilePictureUrl!)
                                    : null,
                            child:
                                _user!.profilePictureUrl == null
                                    ? Icon(
                                      Icons.person,
                                      size: 70,
                                      color: Colors.grey[600],
                                    )
                                    : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.camera_alt,
                                color: Theme.of(context).primaryColor,
                                size: 22,
                              ),
                              onPressed: () async {
                                await _updateProfilePicture();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    // Name and Role
                    Text(
                      _user!.name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _user!.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),

              // Content Section
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Information Card
                    _buildProfileInfoCard(),

                    SizedBox(height: 24),

                    // Action Buttons - Only Change Password
                    _buildActionButtons(),

                    SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateProfilePicture() async {
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
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Uploading profile picture...'),
              ],
            ),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );

        final String fileName =
            'profile_${_user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference storageRef = FirebaseStorage.instance.ref().child(
          'profile_pictures/$fileName',
        );
        final UploadTask uploadTask = storageRef.putFile(File(picked.path));
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        final provider = Provider.of<AppProvider>(context, listen: false);
        await provider.updateUserProfile({'profile_picture': downloadUrl});

        await _fetchProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Profile picture updated successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Failed to upload profile picture'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildProfileInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => _buildEditProfileDialog(),
                      );
                    },
                    icon: Icon(
                      Icons.edit,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    tooltip: 'Edit Profile',
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.person,
              label: 'First Name',
              value: _user!.firstName ?? 'N/A',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Last Name',
              value: _user!.lastName ?? 'N/A',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.account_circle,
              label: 'Username',
              value: _user!.username ?? 'N/A',
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _user!.email ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            Icon(
              Icons.settings_outlined,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Change Password Button - Styled as a Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      color: Colors.grey[700],
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Update your account password',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey[400],
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    setState(() {
      _loggingOut = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final success = await provider.logout();

      if (success && mounted) {
        context.go(AppRoutes.login);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Text('Failed to logout. Please try again.'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  Widget _buildEditProfileDialog() {
    return EditProfileDialog(
      firstName: _user!.firstName ?? '',
      lastName: _user!.lastName ?? '',
      email: _user!.email ?? '',
      onSave: (firstName, lastName, email) async {
        try {
          final provider = Provider.of<AppProvider>(context, listen: false);
          await provider.updateUserProfile({
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
          });

          await _fetchProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Profile updated successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text('Failed to update profile'),
                  ],
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
  bool _isLoading = false;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.edit,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person,
                hint: 'Enter your first name',
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
                hint: 'Enter your last name',
              ),
              SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                hint: 'Enter your email address',
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
              _isLoading
                  ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Please fill in all fields'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      widget.onSave(
        _firstNameController.text.trim(),
        _lastNameController.text.trim(),
        _emailController.text.trim(),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('An error occurred'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
