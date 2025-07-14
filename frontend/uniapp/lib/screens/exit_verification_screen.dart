import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:uniapp/models/models.dart';
import 'package:uniapp/screens/app_provider.dart';
import 'package:uniapp/screens/app_constants.dart';
import 'dart:convert';
import 'dart:async';

class ExitVerificationScreen extends StatefulWidget {
  const ExitVerificationScreen({Key? key}) : super(key: key);

  @override
  State<ExitVerificationScreen> createState() => _ExitVerificationScreenState();
}

class _ExitVerificationScreenState extends State<ExitVerificationScreen> with SingleTickerProviderStateMixin {
  String _qrData = '';
  int _secondsLeft = AppConstants.qrTtlSeconds;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<LeaveRequest> _approvedLeaves = [];
  bool _isLoading = false;
  bool _isVerifying = false;
  String _gateId = 'MAIN_GATE';
  String _searchMode = 'id'; // 'id' or 'name'
  
  // History of verifications made in this session
  List<Map<String, dynamic>> _recentVerifications = [];
  
  // Animation controller for scanner effect
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _loadApprovedLeaves();
    _generateQrCode();
    _startRefreshTimer();
    _startCountdownTimer();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadApprovedLeaves() async {
    setState(() => _isLoading = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final leaves = await appProvider.fetchApprovedLeaves();
      
      setState(() {
        _approvedLeaves = leaves;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading approved leaves: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Error loading approved leaves: $e');
    }
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(
      Duration(seconds: AppConstants.qrTtlSeconds),
      (_) => _generateQrCode(),
    );
  }
  
  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        setState(() {
          _secondsLeft = (_secondsLeft - 1);
          if (_secondsLeft <= 0) {
            _secondsLeft = AppConstants.qrTtlSeconds;
          }
        });
      },
    );
  }
  
  void _generateQrCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = _createPayload();
    
    // Create signature with HMAC
    final signature = _generateSignature(payload, timestamp.toString());
    
    // Create final QR data
    final qrData = {
      'type': 'exit',  // Indicate this is for exit
      'payload': payload,
      'timestamp': timestamp,
      'signature': signature,
    };
    
    setState(() {
      _qrData = jsonEncode(qrData);
      _secondsLeft = AppConstants.qrTtlSeconds;
    });
  }
  
  String _createPayload() {
    // Create the exit gate payload
    final payload = jsonEncode({
      'gate_id': _gateId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    return payload;
  }
  
  String _generateSignature(String payload, String timestamp) {
    final dataToSign = payload + timestamp;
    final hmac = Hmac(sha256, utf8.encode(AppConstants.hmacSecretKey));
    final digest = hmac.convert(utf8.encode(dataToSign));
    return digest.toString();
  }
  
  Future<void> _verifyStudentExit(String universityId) async {
    if (universityId.isEmpty) {
      _showSnackBar('Please enter a valid university ID');
      return;
    }
    
    setState(() => _isVerifying = true);
    
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final result = await appProvider.verifyExitRequest(
        universityId: universityId,
        gateId: _gateId,
      );
      
      // Add to recent verifications
      _addToRecentVerifications(
        universityId: universityId,
        name: result.studentName ?? 'Unknown',
        allowed: result.allowed,
        message: result.message,
        timestamp: DateTime.now(),
      );
      
      // Show the result dialog
      if (mounted) {
        _showVerificationResultDialog(result);
      }
      
      // Clear search field
      _searchController.clear();
      _searchQuery = '';
      
    } catch (e) {
      print('Error verifying exit: $e');
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }
  
  void _addToRecentVerifications({
    required String universityId,
    required String name,
    required bool allowed,
    required String message,
    required DateTime timestamp,
  }) {
    setState(() {
      _recentVerifications.insert(0, {
        'universityId': universityId,
        'name': name,
        'allowed': allowed,
        'message': message,
        'timestamp': timestamp,
      });
      
      // Keep only the last 10 verifications
      if (_recentVerifications.length > 10) {
        _recentVerifications = _recentVerifications.sublist(0, 10);
      }
    });
  }
  
  void _showVerificationResultDialog(ExitResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.allowed ? Icons.check_circle : Icons.cancel,
              color: result.allowed ? Colors.green : Colors.red,
            ),
            SizedBox(width: 8),
            Text(result.allowed ? 'Exit Approved' : 'Exit Denied'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.studentName != null) ...[
              Text(
                'Student: ${result.studentName}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
            ],
            Text('Status: ${result.allowed ? 'Authorized to exit' : 'Not authorized'}'),
            SizedBox(height: 8),
            Text('Reason: ${result.message}'),
            SizedBox(height: 16),
            Center(
              child: Icon(
                result.allowed ? Icons.exit_to_app : Icons.block,
                size: 48,
                color: result.allowed ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
          if (result.allowed)
            ElevatedButton.icon(
              icon: Icon(Icons.check),
              label: Text('Confirm Exit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _showSnackBar('Exit confirmed');
              },
            ),
        ],
      ),
    );
  }
  
  void _showGateSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select Exit Gate'),
        children: [
          _buildGateOption('MAIN_GATE', 'Main Gate'),
          _buildGateOption('NORTH_GATE', 'North Gate'),
          _buildGateOption('SOUTH_GATE', 'South Gate'),
          _buildGateOption('EAST_GATE', 'East Gate'),
          _buildGateOption('WEST_GATE', 'West Gate'),
        ],
      ),
    );
  }
  
  Widget _buildGateOption(String id, String name) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => _gateId = id);
        _generateQrCode();
        Navigator.pop(context);
      },
      child: Row(
        children: [
          Icon(
            Icons.door_front_door,
            color: _gateId == id ? Colors.blue : Colors.grey,
          ),
          SizedBox(width: 8),
          Text(name),
          if (_gateId == id) ...[
            Spacer(),
            Icon(Icons.check, color: Colors.blue),
          ],
        ],
      ),
    );
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }
  
  List<LeaveRequest> get _filteredLeaves {
    if (_searchQuery.isEmpty) return _approvedLeaves;
    
    return _approvedLeaves.where((leave) {
      if (_searchMode == 'id') {
        return leave.userId.toLowerCase().contains(_searchQuery.toLowerCase());
      } else {
        // This assumes you have the student name - you might need to adjust this
        return false; // Implement name search if student name is available in leave request
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Exit Verification'),
          actions: [
            IconButton(
              icon: Icon(Icons.door_front_door),
              tooltip: 'Change Gate',
              onPressed: _showGateSelectionDialog,
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              tooltip: 'Refresh Data',
              onPressed: () {
                _loadApprovedLeaves();
                _generateQrCode();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.qr_code), text: 'QR Code'),
              Tab(icon: Icon(Icons.search), text: 'Manual Verify'),
              Tab(icon: Icon(Icons.history), text: 'Recent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildQrCodeTab(),
            _buildManualVerifyTab(),
            _buildRecentVerificationsTab(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQrCodeTab() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gate info card
          Card(
            margin: EdgeInsets.only(bottom: 24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.door_front_door, size: 32, color: Colors.blue),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Gate',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _gateId.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text('Change'),
                    onPressed: _showGateSelectionDialog,
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // QR Code container with animation
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // QR Code
                        _qrData.isNotEmpty
                            ? QrImageView(
                                data: _qrData,
                                version: QrVersions.auto,
                                size: 240.0,
                              )
                            : CircularProgressIndicator(),
                        
                        // Scanner animation effect
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Positioned(
                              top: 20 + 240 * _animationController.value,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Countdown indicator
                  Container(
                    width: 280,
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _secondsLeft / AppConstants.qrTtlSeconds,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _secondsLeft > AppConstants.qrTtlSeconds / 2 
                                ? Colors.green 
                                : Colors.orange
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Code refreshes in $_secondsLeft seconds',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Instructions
          Container(
            margin: EdgeInsets.only(top: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. Have the student scan this QR code\n'
                  '2. Student will verify their identity with face recognition\n'
                  '3. System will check for approved leave or emergency exit\n'
                  '4. You will receive verification result on student\'s device',
                  style: TextStyle(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildManualVerifyTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _searchMode == 'id' 
                          ? 'Enter university ID' 
                          : 'Enter student name',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                SizedBox(width: 8),
                // Mode toggle
                ChoiceChip(
                  label: Text('ID'),
                  selected: _searchMode == 'id',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _searchMode = 'id');
                    }
                  },
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Name'),
                  selected: _searchMode == 'name',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _searchMode = 'name');
                    }
                  },
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            margin: EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.verified_user),
                  label: Text('Verify Exit'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _isVerifying 
                      ? null 
                      : () => _verifyStudentExit(_searchController.text.trim()),
                ),
              ],
            ),
          ),
          
          // List of approved leave requests
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _approvedLeaves.isEmpty
                    ? Center(
                        child: Text(
                          'No approved leave requests found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Students with Approved Leave',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _filteredLeaves.length,
                              itemBuilder: (context, index) {
                                final leave = _filteredLeaves[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade100,
                                      child: Icon(Icons.person, color: Colors.blue),
                                    ),
                                    title: Text('ID: ${leave.userId}'),
                                    subtitle: Text(
                                      'Valid: ${_formatDate(leave.startDate)} to ${_formatDate(leave.endDate)}'
                                    ),
                                    trailing: TextButton(
                                      child: Text('Verify'),
                                      onPressed: () => _verifyStudentExit(leave.userId),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentVerificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Exit Verifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _recentVerifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No recent verifications',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentVerifications.length,
                    itemBuilder: (context, index) {
                      final verification = _recentVerifications[index];
                      final DateTime timestamp = verification['timestamp'];
                      final bool allowed = verification['allowed'];
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: allowed ? Colors.green.shade200 : Colors.red.shade200,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: allowed 
                                ? Colors.green.shade100 
                                : Colors.red.shade100,
                            child: Icon(
                              allowed ? Icons.check : Icons.close,
                              color: allowed ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(verification['name']),
                              Spacer(),
                              Text(
                                _formatTime(timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${verification['universityId']}'),
                              Text(
                                verification['message'],
                                style: TextStyle(
                                  color: allowed ? Colors.green.shade700 : Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            _showVerificationResultDialog(
                              ExitResult(
                                allowed: verification['allowed'],
                                message: verification['message'],
                                studentName: verification['name'],
                                studentPhotoUrl: null,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  String _formatTime(DateTime time) {
    return '${_padZero(time.hour)}:${_padZero(time.minute)}';
  }
  
  String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }
}
