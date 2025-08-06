import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../app_provider.dart';

class LecturerConfigurationScreen extends StatefulWidget {
  const LecturerConfigurationScreen({super.key});

  @override
  State<LecturerConfigurationScreen> createState() =>
      _LecturerConfigurationScreenState();
}

class _LecturerConfigurationScreenState
    extends State<LecturerConfigurationScreen> {
  // Removed programs selection
  // Geofencing state
  double? _latitude;
  double? _longitude;
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  bool _isLoadingLocation = false;
  double _radius = 50.0;
  int _totalSessions = 12;
  double _passThreshold = 0.75;
  bool _isCreating = false;
  DateTime? _startTime;
  DateTime? _endTime;
  // Level and course state
  final List<String> _levels = ['100', '200', '300', '400', '500'];
  String? _selectedLevel;
  List<Map<String, dynamic>> _courses = [];
  String? _selectedCourseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      await appProvider.loadUserData();
      await appProvider.fetchPrograms();
    });
  }

  final _sessionFormKey = GlobalKey<FormState>();

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() => _isLoadingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        setState(() => _isLoadingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
        _isLoadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location autofilled from GPS.')),
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _fetchCourses() async {
    Future<void> _getCurrentLocation() async {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied.'),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location autofilled from GPS.')),
      );
    }

    if (_selectedLevel == null) {
      setState(() => _courses = []);
      return;
    }
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final response = await appProvider.coreServices.dio.get(
        '/courses/',
        queryParameters: {'level': _selectedLevel},
      );
      if (response.statusCode == 200 && response.data is List) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(response.data);
          _selectedCourseId = null;
        });
      } else {
        setState(() => _courses = []);
      }
    } catch (e) {
      setState(() => _courses = []);
    }
  }

  Future<void> _createSession(BuildContext context) async {
    if (!_sessionFormKey.currentState!.validate() ||
        _selectedLevel == null ||
        _selectedCourseId == null ||
        _startTime == null ||
        _endTime == null ||
        _latitude == null ||
        _longitude == null) {
      debugPrint('Form validation failed or missing required fields');
      return;
    }
    setState(() => _isCreating = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final lecturerUsername = appProvider.getCurrentUser()?.username ?? '';
    debugPrint('Lecturer username: $lecturerUsername');
    final totalSessions = _totalSessions;
    final passThreshold = _passThreshold;
    final payload = {
      'lecturer': lecturerUsername,
      'level': _selectedLevel,
      'course_id': _selectedCourseId,
      'start_time': _startTime!.toIso8601String(),
      'end_time': _endTime!.toIso8601String(),
      'total_sessions': totalSessions,
      'pass_threshold': passThreshold,
      'latitude': _latitude,
      'longitude': _longitude,
      'radius': _radius,
    };
    debugPrint('Creating session with payload: $payload');
    final result = await appProvider.coreServices.dio.post(
      '/sessions/',
      data: payload,
    );
    debugPrint('Backend response status: ${result.statusCode}');
    debugPrint('Backend response data: ${result.data}');
    setState(() => _isCreating = false);
    if (result.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session created successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to create session: ${result.data['error'] ?? 'Unknown error'}',
          ),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.fetchPrograms();
    // Fetch sessions for the current lecturer using username
    final lecturerUsername = appProvider.getCurrentUser()?.username ?? '';
    debugPrint('Refreshing sessions for lecturer: $lecturerUsername');
    await appProvider.coreServices.dio.get(
      '/sessions/',
      queryParameters: {'username': lecturerUsername},
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Configuration'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _sessionFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.1),
                          Theme.of(context).primaryColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.settings,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Create New Session',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Configure session parameters and location settings',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Course Selection Section
                _buildSectionCard(
                  context,
                  title: 'Course Selection',
                  icon: Icons.school,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      decoration: InputDecoration(
                        labelText: 'Academic Level',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.grade),
                      ),
                      items:
                          _levels
                              .map(
                                (l) => DropdownMenuItem<String>(
                                  value: l,
                                  child: Text('$l Level'),
                                ),
                              )
                              .toList(),
                      onChanged: (val) async {
                        setState(() {
                          _selectedLevel = val;
                          _selectedCourseId = null;
                          _courses = [];
                        });
                        await _fetchCourses();
                      },
                      validator:
                          (val) =>
                              val == null || val.isEmpty
                                  ? 'Please select a level'
                                  : null,
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCourseId,
                      decoration: InputDecoration(
                        labelText: 'Course',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.book),
                      ),
                      isExpanded: true,
                      items:
                          _courses
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id'].toString(),
                                  child: Text(
                                    '${c['code']} - ${c['name']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCourseId = val;
                        });
                      },
                      validator:
                          (val) =>
                              val == null || val.isEmpty
                                  ? 'Please select a course'
                                  : null,
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Location Settings Section
                _buildSectionCard(
                  context,
                  title: 'Location Settings',
                  icon: Icons.location_on,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latitudeController,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.my_location),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged:
                                (val) => setState(
                                  () => _latitude = double.tryParse(val),
                                ),
                            validator:
                                (val) =>
                                    val == null || val.isEmpty
                                        ? 'Required'
                                        : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _longitudeController,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.place),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged:
                                (val) => setState(
                                  () => _longitude = double.tryParse(val),
                                ),
                            validator:
                                (val) =>
                                    val == null || val.isEmpty
                                        ? 'Required'
                                        : null,
                          ),
                        ),
                      ],
                    ),
                    if (_isLoadingLocation)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Radius (meters)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.radio_button_unchecked),
                              suffixText: 'm',
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: _radius.toString(),
                            onChanged:
                                (val) => setState(
                                  () => _radius = double.tryParse(val) ?? 50.0,
                                ),
                            validator:
                                (val) =>
                                    val == null || val.isEmpty
                                        ? 'Required'
                                        : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon:
                              _isLoadingLocation
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Icon(Icons.my_location),
                          label: Text('Use GPS'),
                          onPressed:
                              _isLoadingLocation ? null : _getCurrentLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Session Parameters Section
                _buildSectionCard(
                  context,
                  title: 'Session Parameters',
                  icon: Icons.tune,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _totalSessions.toString(),
                            decoration: InputDecoration(
                              labelText: 'Total Periods',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.repeat),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter total sessions';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num < 1) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final num = int.tryParse(value);
                              if (num != null) {
                                setState(() => _totalSessions = num);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: (_passThreshold * 100)
                                .toStringAsFixed(1),
                            decoration: InputDecoration(
                              labelText: 'Pass Threshold',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.percent),
                              suffixText: '%',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter pass threshold';
                              }
                              final percent = double.tryParse(value);
                              if (percent == null ||
                                  percent < 0 ||
                                  percent > 100) {
                                return 'Please enter a valid percentage';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final percent = double.tryParse(value);
                              if (percent != null) {
                                setState(() => _passThreshold = percent / 100);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Schedule Section
                _buildSectionCard(
                  context,
                  title: 'Schedule',
                  icon: Icons.schedule,
                  children: [
                    _buildDateTimeSelector(
                      context,
                      'Start Time',
                      _startTime,
                      Icons.play_arrow,
                      () async {
                        final picked = await showDateTimePicker(
                          context,
                          _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                    SizedBox(height: 16),
                    _buildDateTimeSelector(
                      context,
                      'End Time',
                      _endTime,
                      Icons.stop,
                      () async {
                        final picked = await showDateTimePicker(
                          context,
                          _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ],
                ),
                SizedBox(height: 32),

                // Create Session Button
                Container(
                  height: 56,
                  child: ElevatedButton.icon(
                    icon:
                        _isCreating
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Icon(Icons.add_circle, size: 24),
                    label: Text(
                      _isCreating ? 'Creating Session...' : 'Create Session',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed:
                        _isCreating ? null : () => _createSession(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for picking date and time
  Future<DateTime?> showDateTimePicker(
    BuildContext context,
    DateTime? initial,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector(
    BuildContext context,
    String label,
    DateTime? dateTime,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(label),
        subtitle: Text(
          dateTime == null
              ? 'Not selected'
              : dateTime.toLocal().toString().substring(0, 16),
          style: TextStyle(
            color: dateTime == null ? Colors.grey[600] : Colors.black87,
            fontWeight: dateTime == null ? FontWeight.normal : FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.calendar_today, color: Colors.grey[600]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
