import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../app_provider.dart';
import '../../models/program.dart';

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
      appBar: AppBar(title: const Text('Session Configuration')),
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
                Text(
                  'Create a new session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Geofencing Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (val) => setState(
                              () => _latitude = double.tryParse(val),
                            ),
                        validator:
                            (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _longitudeController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged:
                            (val) => setState(
                              () => _longitude = double.tryParse(val),
                            ),
                        validator:
                            (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                if (_isLoadingLocation)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Radius (meters)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        initialValue: _radius.toString(),
                        onChanged:
                            (val) => setState(
                              () => _radius = double.tryParse(val) ?? 50.0,
                            ),
                        validator:
                            (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use My Location'),
                      onPressed: _getCurrentLocation,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
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
                          val == null || val.isEmpty ? 'Select level' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCourseId,
                  decoration: const InputDecoration(
                    labelText: 'Course',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      _courses
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: SizedBox(
                                width: 220, // Adjust as needed for your layout
                                child: Text(
                                  '${c['code']} - ${c['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                          val == null || val.isEmpty ? 'Select course' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _totalSessions.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Total Sessions',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: (_passThreshold * 100).toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'Pass Threshold (%)',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pass threshold';
                    }
                    final percent = double.tryParse(value);
                    if (percent == null || percent < 0 || percent > 100) {
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _startTime == null
                            ? 'Start Time: Not selected'
                            : 'Start Time: ${_startTime!.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                    TextButton(
                      child: const Text('Pick Start'),
                      onPressed: () async {
                        final picked = await showDateTimePicker(
                          context,
                          _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _endTime == null
                            ? 'End Time: Not selected'
                            : 'End Time: ${_endTime!.toLocal().toString().substring(0, 16)}',
                      ),
                    ),
                    TextButton(
                      child: const Text('Pick End'),
                      onPressed: () async {
                        final picked = await showDateTimePicker(
                          context,
                          _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label:
                      _isCreating
                          ? const Text('Creating...')
                          : const Text('Create Session'),
                  onPressed: _isCreating ? null : () => _createSession(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
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
}
