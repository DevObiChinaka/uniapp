import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../../models/models.dart';

class ExitQRScreen extends StatefulWidget {
  final LeaveRequest leaveRequest;

  const ExitQRScreen({super.key, required this.leaveRequest});

  @override
  State<ExitQRScreen> createState() => _ExitQRScreenState();
}

class _ExitQRScreenState extends State<ExitQRScreen> {
  String? _qrData;
  Timer? _refreshTimer;
  int _timeRemaining = 300; // 5 minutes in seconds
  bool _isGenerating = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            _generateQRCode();
            _timeRemaining = 300; // Reset to 5 minutes
          }
        });
      }
    });
  }

  Future<void> _generateQRCode() async {
    if (!mounted) return;

    setState(() {
      _isGenerating = true;
      _hasError = false;
    });

    try {
      // For now, generate a demo QR code with leave request data
      // In production, this would call a backend API to generate a secure, time-limited QR code
      final qrData = _generateDemoQRData();

      setState(() {
        _qrData = qrData;
        _isGenerating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isGenerating = false;
        });
      }
    }
  }

  String _generateDemoQRData() {
    // Generate QR data valid only on the leave start date until 5 PM
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Set expiration to 6 PM (18:00) on the leave start date
    final expirationDate = DateTime(
      widget.leaveRequest.startDate.year,
      widget.leaveRequest.startDate.month,
      widget.leaveRequest.startDate.day,
      18, // 5 PM (17:00)
      0, // 0 minutes
      0, // 0 seconds
    );

    return '''
{
  "type": "EXIT_REQUEST",
  "leaveId": "${widget.leaveRequest.id}",
  "userId": "${widget.leaveRequest.studentUniversityId ?? widget.leaveRequest.userId}",
  "timestamp": $timestamp,
  "validUntil": ${expirationDate.millisecondsSinceEpoch},
  "exitDate": "${widget.leaveRequest.startDate.toIso8601String()}",
  "returnDate": "${widget.leaveRequest.endDate.toIso8601String()}",
  "purpose": "AUTHORIZED_EXIT",
  "reason": "${widget.leaveRequest.reason}"
}
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exit QR Code'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateQRCode,
            tooltip: 'Refresh QR Code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 20),

            // QR Code Card
            _buildQRCodeCard(),
            const SizedBox(height: 20),

            // Instructions Card
            _buildInstructionsCard(),
            const SizedBox(height: 20),

            // Timer Card
            _buildTimerCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.1),
              Colors.green.withOpacity(0.05),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exit Authorized',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Leave Request: ${widget.leaveRequest.reason}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_isGenerating)
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Generating QR Code...'),
                    ],
                  ),
                ),
              )
            else if (_hasError)
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to generate QR code',
                      style: TextStyle(color: Colors.red[700]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _generateQRCode,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_qrData != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Present this QR code to security for campus exit',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Instructions',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstruction(
              '1. Present this QR code to security at the exit gate',
            ),
            _buildInstruction('2. Face verification may be required'),
            _buildInstruction('3. QR code auto-refreshes every 5 minutes'),
            _buildInstruction(
              '4. Keep your phone screen bright for better scanning',
            ),
            _buildInstruction(
              '5. Contact security if you encounter any issues',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard() {
    // Calculate time until 5 PM on the exit date
    final exitDate = widget.leaveRequest.startDate;
    final expirationTime = DateTime(
      exitDate.year,
      exitDate.month,
      exitDate.day,
      17, // 5 PM
      0,
      0,
    );

    final now = DateTime.now();
    final timeUntilExpiration = expirationTime.difference(now);

    // Check if QR is valid (today is exit date and before 5 PM)
    final isToday =
        now.year == exitDate.year &&
        now.month == exitDate.month &&
        now.day == exitDate.day;
    final isBeforeExpiration = now.isBefore(expirationTime);
    final isValid = isToday && isBeforeExpiration;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!isToday) {
      if (now.isBefore(DateTime(exitDate.year, exitDate.month, exitDate.day))) {
        statusText =
            'Valid on ${exitDate.day}/${exitDate.month}/${exitDate.year} until 5:00 PM';
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
      } else {
        statusText = 'Expired - Exit date has passed';
        statusColor = Colors.red;
        statusIcon = Icons.error;
      }
    } else if (!isBeforeExpiration) {
      statusText = 'Expired at 5:00 PM today';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else {
      final hours = timeUntilExpiration.inHours;
      final minutes = timeUntilExpiration.inMinutes % 60;
      statusText = 'Valid for ${hours}h ${minutes}m more (until 5:00 PM)';
      statusColor =
          timeUntilExpiration.inHours < 2 ? Colors.orange : Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Card(
      elevation: 2,
      color:
          isValid
              ? (timeUntilExpiration.inHours < 2
                  ? Colors.orange[50]
                  : Colors.green[50])
              : Colors.red[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Validity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    statusText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.blue[700]),
      ),
    );
  }
}
