import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import '../app_provider.dart';
import '../../models/models.dart';
import 'security_logs_screen.dart';

class QRManagementScreen extends StatefulWidget {
  const QRManagementScreen({super.key});

  @override
  State<QRManagementScreen> createState() => _QRManagementScreenState();
}

class _QRManagementScreenState extends State<QRManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // QR Generation Tab State
  String? _securityQrData;
  Timer? _qrRefreshTimer;
  int _timeRemaining = 30; // 30 seconds TTL
  bool _isGeneratingQr = false;

  // Scanner Tab State
  MobileScannerController? _scannerController;
  ExitResult? _lastScanResult;
  bool _isProcessingScan = false;
  bool _isScanningEnabled = false;
  DateTime? _lastScanTime;
  static const Duration _scanCooldown = Duration(seconds: 3);
  Offset? _focusPoint;
  bool _showFocusIndicator = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 3.0;
  String? _scannedStudentId;
  String? _scannedPurpose;
  String? _scannedExitDate;
  String? _scannedReturnDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _generateSecurityQr();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qrRefreshTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) {
      // Scanner tab - initialize camera and enable scanning
      _initializeScanner();
      setState(() {
        _isScanningEnabled = true;
        _lastScanResult = null;
      });
    } else {
      // QR tab - dispose camera to save resources
      _disposeScanner();
      setState(() {
        _isScanningEnabled = false;
      });
    }
  }

  void _initializeScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      autoStart: true,
      useNewCameraSelector: true,
      formats: const [
        BarcodeFormat.qrCode,
      ], // Focus only on QR codes for better performance
    );

    // Enable autofocus after initialization
    _enableAutofocus();
  }

  Future<void> _enableAutofocus() async {
    if (_scannerController != null) {
      try {
        // Start autofocus
        await _scannerController!.start();

        // Set autofocus mode for better QR detection
        await Future.delayed(const Duration(milliseconds: 500));

        debugPrint('Autofocus enabled for QR scanner');
      } catch (e) {
        debugPrint('Error enabling autofocus: $e');
      }
    }
  }

  void _disposeScanner() {
    _scannerController?.dispose();
    _scannerController = null;
  }

  Future<void> _handleTapToFocus(TapUpDetails details) async {
    if (_scannerController == null || !_isScanningEnabled) return;

    try {
      // Get the tap position relative to the screen
      final RenderBox box = context.findRenderObject() as RenderBox;
      final localPosition = box.globalToLocal(details.globalPosition);

      // Normalize coordinates to 0-1 range
      final x = localPosition.dx / box.size.width;
      final y = localPosition.dy / box.size.height;

      debugPrint('Tap-to-focus at: ($x, $y)');

      // Show focus animation at tap location
      _showFocusAnimation(details.globalPosition);

      // Note: mobile_scanner doesn't have direct focus point control
      // but we can restart autofocus which helps with detection
      await _scannerController!.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await _scannerController!.start();
    } catch (e) {
      debugPrint('Error handling tap-to-focus: $e');
    }
  }

  void _showFocusAnimation(Offset position) {
    // Add visual feedback for tap-to-focus
    setState(() {
      _focusPoint = position;
      _showFocusIndicator = true;
    });

    // Reset after animation
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showFocusIndicator = false;
          _focusPoint = null;
        });
      }
    });
  }

  Future<void> _toggleTorch() async {
    if (_scannerController == null) return;

    try {
      await _scannerController!.toggleTorch();
      setState(() {
        // Update UI to reflect torch state
      });
      debugPrint('Torch toggled for better QR detection');
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  Future<void> _handleZoom(double scale) async {
    if (_scannerController == null) return;

    try {
      // Clamp zoom level between min and max
      final newZoom = (_currentZoom * scale).clamp(_minZoom, _maxZoom);

      if (newZoom != _currentZoom) {
        await _scannerController!.setZoomScale(newZoom);
        setState(() {
          _currentZoom = newZoom;
        });
        debugPrint('Zoom adjusted to: $newZoom');
      }
    } catch (e) {
      debugPrint('Error adjusting zoom: $e');
    }
  }

  void _resetZoom() async {
    if (_scannerController == null) return;

    try {
      await _scannerController!.setZoomScale(1.0);
      setState(() {
        _currentZoom = 1.0;
      });
      debugPrint('Zoom reset to 1.0');
    } catch (e) {
      debugPrint('Error resetting zoom: $e');
    }
  }

  void _toggleScanning() {
    setState(() {
      _isScanningEnabled = !_isScanningEnabled;
      if (_isScanningEnabled) {
        _lastScanResult = null;
      }
    });
  }

  void _restartScanning() {
    setState(() {
      _isScanningEnabled = true;
      _lastScanResult = null;
      _isProcessingScan = false;
      _scannedStudentId = null;
      _scannedPurpose = null;
      _scannedExitDate = null;
      _scannedReturnDate = null;
    });
  }

  bool _canScan() {
    if (!_isScanningEnabled || _isProcessingScan) return false;

    if (_lastScanTime != null) {
      final timeSinceLastScan = DateTime.now().difference(_lastScanTime!);
      if (timeSinceLastScan < _scanCooldown) return false;
    }

    return true;
  }

  void _navigateToSecurityLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecurityLogsScreen()),
    );
  }

  Future<void> _generateSecurityQr() async {
    if (_isGeneratingQr) return;

    setState(() {
      _isGeneratingQr = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final currentUser = provider.getCurrentUser();

      // Generate security QR payload with user info (fallback for demo)
      final qrPayload = {
        'type': 'security_signin',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now()
                .add(const Duration(seconds: 30))
                .millisecondsSinceEpoch,
        'security_id': currentUser?.id ?? 'security_demo',
        'security_name': currentUser?.name ?? 'Security Officer',
        'security_role': currentUser?.role ?? 'security',
      };

      setState(() {
        _securityQrData = jsonEncode(qrPayload);
        _timeRemaining = 30;
        _isGeneratingQr = false;
      });

      _startRefreshTimer();
    } catch (e) {
      debugPrint('Error generating security QR: $e');
      setState(() {
        _isGeneratingQr = false;
      });
    }
  }

  void _startRefreshTimer() {
    _qrRefreshTimer?.cancel();
    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--;
      });

      if (_timeRemaining <= 0) {
        timer.cancel();
        _generateSecurityQr();
      }
    });
  }

  Future<void> _processStudentQr(String qrData) async {
    if (!_canScan()) return;

    // Set last scan time and disable scanning temporarily
    _lastScanTime = DateTime.now();

    setState(() {
      _isProcessingScan = true;
      _isScanningEnabled = false; // Disable scanning during processing
      _lastScanResult = null;
      _scannedStudentId = null;
      _scannedPurpose = null;
      _scannedExitDate = null;
      _scannedReturnDate = null;
    });

    try {
      // Parse the student QR code
      final qrJson = jsonDecode(qrData);

      // Validate QR code structure
      if (qrJson['type'] != 'EXIT_REQUEST') {
        setState(() {
          _lastScanResult = ExitResult(
            allowed: false,
            message: 'Invalid QR code type. Expected student exit QR.',
          );
          _isProcessingScan = false;
        });
        return;
      }

      // Check if QR code is still valid
      final validUntil = qrJson['validUntil'] as int?;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      debugPrint('QR validation: current=$currentTime, validUntil=$validUntil');

      if (validUntil != null && currentTime > validUntil) {
        final expired = DateTime.fromMillisecondsSinceEpoch(validUntil);
        final now = DateTime.fromMillisecondsSinceEpoch(currentTime);
        debugPrint('QR expired at $expired, current time $now');

        setState(() {
          _lastScanResult = ExitResult(
            allowed: false,
            message: 'QR code has expired. Valid until 5 PM on the exit date.',
          );
          _isProcessingScan = false;
        });
        return;
      }

      final studentId = qrJson['userId'] as String?;
      final leaveId = qrJson['leaveId'] as String?;
      final purpose = qrJson['purpose'] as String? ?? 'Exit';
      final exitDate = qrJson['exitDate'] as String?;
      final returnDate = qrJson['returnDate'] as String?;
      final reason = qrJson['reason'] as String?;

      if (studentId == null || studentId.isEmpty) {
        setState(() {
          _lastScanResult = ExitResult(
            allowed: false,
            message: 'Invalid QR code: Missing student information.',
          );
          _isProcessingScan = false;
          // Re-enable scanning after cooldown
          Timer(_scanCooldown, () {
            if (mounted) {
              setState(() {
                _isScanningEnabled = true;
              });
            }
          });
        });
        return;
      }

      // Additional validation: Check if QR is being used on the correct date
      if (exitDate != null) {
        final exitDateTime = DateTime.parse(exitDate);
        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);
        final exitDateOnly = DateTime(
          exitDateTime.year,
          exitDateTime.month,
          exitDateTime.day,
        );

        if (!todayDate.isAtSameMomentAs(exitDateOnly)) {
          setState(() {
            _lastScanResult = ExitResult(
              allowed: false,
              message:
                  'QR code can only be used on the scheduled exit date: ${exitDateTime.day}/${exitDateTime.month}/${exitDateTime.year}',
            );
            _isProcessingScan = false;
            // Re-enable scanning after cooldown
            Timer(_scanCooldown, () {
              if (mounted) {
                setState(() {
                  _isScanningEnabled = true;
                });
              }
            });
          });
          return;
        }
      }

      // Store scanned details for display (including additional info)
      _scannedStudentId = studentId;
      _scannedPurpose = reason ?? purpose;
      _scannedExitDate = exitDate;
      _scannedReturnDate = returnDate;

      final provider = Provider.of<AppProvider>(context, listen: false);

      // Call the security student processing endpoint with additional data
      final result = await provider.coreServices.processStudentExit(
        studentId: studentId,
        action: 'exit',
        leaveId: leaveId,
        purpose: reason ?? purpose,
        exitDate: exitDate,
        returnDate: returnDate,
        qrCodeData: qrData, // Pass the raw QR data for duplicate detection
      );

      setState(() {
        _lastScanResult = result;
        _isProcessingScan = false;
      });

      // If successful, navigate to logs after a short delay
      if (result.allowed) {
        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _navigateToSecurityLogs();
            // Clear result after navigation
            setState(() {
              _lastScanResult = null;
              _isScanningEnabled = true;
            });
          }
        });
      } else {
        // For failed scans, don't auto-clear and don't re-enable scanning
        // User needs to use retry button
      }
    } catch (e) {
      debugPrint('Error processing student QR: $e');
      setState(() {
        _lastScanResult = ExitResult(
          allowed: false,
          message: 'Error processing QR code: ${e.toString()}',
        );
        _isProcessingScan = false;
        // Re-enable scanning after cooldown
        Timer(_scanCooldown, () {
          if (mounted) {
            setState(() {
              _isScanningEnabled = true;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'QR Display'),
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scanner'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildQrDisplayTab(), _buildScannerTab()],
      ),
    );
  }

  Widget _buildQrDisplayTab() {
    return Container(
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey[50]!],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Campus Sign-In QR',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Students scan this to sign back into campus',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // QR Code Display
                    if (_securityQrData != null && !_isGeneratingQr)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _securityQrData!,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      )
                    else
                      Container(
                        width: 232,
                        height: 232,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),

                    const SizedBox(height: 24),

                    // Timer Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: _timeRemaining / 30,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                                strokeWidth: 4,
                              ),
                            ),
                            Text(
                              '$_timeRemaining',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-refresh in',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '$_timeRemaining seconds',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Manual refresh button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingQr ? null : _generateSecurityQr,
                        icon:
                            _isGeneratingQr
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.refresh),
                        label: Text(
                          _isGeneratingQr ? 'Generating...' : 'Refresh Now',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Technical Info (Expandable)
            Card(
              child: ExpansionTile(
                title: const Text('Technical Info'),
                leading: const Icon(Icons.info_outline),
                children: [
                  if (_securityQrData != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTechnicalInfoRow('QR Type', 'Security Sign-In'),
                          _buildTechnicalInfoRow(
                            'Security ID',
                            _getSecurityId(),
                          ),
                          _buildTechnicalInfoRow(
                            'Security Name',
                            _getSecurityName(),
                          ),
                          _buildTechnicalInfoRow(
                            'Security Role',
                            _getSecurityRole(),
                          ),
                          _buildTechnicalInfoRow(
                            'Generated At',
                            _getGeneratedTime(),
                          ),
                          _buildTechnicalInfoRow(
                            'Expires At',
                            _getExpirationTime(),
                          ),
                          _buildTechnicalInfoRow(
                            'TTL',
                            '$_timeRemaining seconds remaining',
                          ),
                          const Divider(height: 24),
                          const Text(
                            'Raw Payload:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _securityQrData!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerTab() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Camera Preview with Tap-to-Focus and Pinch-to-Zoom
          if (_scannerController != null)
            GestureDetector(
              onTapUp: (details) => _handleTapToFocus(details),
              onScaleUpdate: (details) => _handleZoom(details.scale),
              onScaleEnd: (details) {
                // Reset zoom on double tap
                if (details.pointerCount == 1) {
                  // Check if this is a potential double tap
                  final now = DateTime.now();
                  if (_lastScanTime != null &&
                      now.difference(_lastScanTime!).inMilliseconds < 300) {
                    _resetZoom();
                  }
                  _lastScanTime = now;
                }
              },
              child: MobileScanner(
                controller: _scannerController!,
                onDetect: (capture) {
                  if (!_canScan()) return;

                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _processStudentQr(barcode.rawValue!);
                      break;
                    }
                  }
                },
                fit: BoxFit.cover,
                placeholderBuilder: (context, child) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Enhanced Scan Overlay with Focus Indicator
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Instructions
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Position student QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to focus • Pinch to zoom • Use flash for better scanning',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Scan Status and Controls
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Scanning Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isScanningEnabled ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isScanningEnabled
                            ? Icons.qr_code_scanner
                            : Icons.pause_circle,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isScanningEnabled
                            ? 'Scanning Active'
                            : 'Scanning Paused',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Scanner Controls
                if (!_isProcessingScan) ...[
                  // Zoom Reset Control
                  if (_currentZoom != 1.0)
                    FloatingActionButton.small(
                      onPressed: _resetZoom,
                      backgroundColor: Colors.blue.withOpacity(0.7),
                      child: Text(
                        '${_currentZoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (_currentZoom != 1.0) const SizedBox(width: 8),
                  // Torch/Flash Control
                  FloatingActionButton.small(
                    onPressed: _toggleTorch,
                    backgroundColor: Colors.black54,
                    child: const Icon(
                      Icons.flash_on,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Main Control Button
                  FloatingActionButton.small(
                    onPressed: _toggleScanning,
                    backgroundColor:
                        _isScanningEnabled ? Colors.orange : Colors.green,
                    child: Icon(
                      _isScanningEnabled ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Processing Indicator
          if (_isProcessingScan)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Processing QR Code...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Scan Result Display
          if (_lastScanResult != null)
            Positioned(
              bottom: 60,
              left: 16,
              right: 16,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          _lastScanResult!.allowed
                              ? [Colors.green[400]!, Colors.green[600]!]
                              : [Colors.red[400]!, Colors.red[600]!],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _lastScanResult!.allowed
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 32,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastScanResult!.allowed
                                      ? 'EXIT APPROVED'
                                      : 'EXIT DENIED',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_lastScanResult!.allowed)
                                  Text(
                                    'Redirecting to logs...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy - HH:mm:ss',
                                    ).format(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _lastScanResult = null;
                                _scannedStudentId = null;
                                _scannedPurpose = null;
                                _scannedExitDate = null;
                                _scannedReturnDate = null;
                              });
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_lastScanResult!.studentName != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                backgroundImage:
                                    _lastScanResult!.studentPhotoUrl != null
                                        ? NetworkImage(
                                          _lastScanResult!.studentPhotoUrl!,
                                        )
                                        : null,
                                child:
                                    _lastScanResult!.studentPhotoUrl == null
                                        ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 28,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lastScanResult!.studentName!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_scannedStudentId != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID: $_scannedStudentId',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_scannedPurpose != null) ...[
                              Text(
                                'Purpose: $_scannedPurpose',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (_scannedExitDate != null) ...[
                              Text(
                                'Exit Date: ${DateTime.parse(_scannedExitDate!).day}/${DateTime.parse(_scannedExitDate!).month}/${DateTime.parse(_scannedExitDate!).year}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (_scannedReturnDate != null) ...[
                              Text(
                                'Return Date: ${DateTime.parse(_scannedReturnDate!).day}/${DateTime.parse(_scannedReturnDate!).month}/${DateTime.parse(_scannedReturnDate!).year}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              _lastScanResult!.message,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action buttons based on scan result
                      if (_lastScanResult!.allowed) ...[
                        // Success: Show "View Logs" and "Scan Another" buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _navigateToSecurityLogs,
                                icon: const Icon(
                                  Icons.history,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'View Logs',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _restartScanning,
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Scan Next',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // Failed: Show "Retry Scan" button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _restartScanning,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Retry Scan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Focus Indicator Overlay
          if (_showFocusIndicator && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 30,
              top: _focusPoint!.dy - 30,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.center_focus_strong,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper methods for technical info display
  Widget _buildTechnicalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  String _getSecurityId() {
    if (_securityQrData == null) return 'N/A';
    try {
      final payload = jsonDecode(_securityQrData!) as Map<String, dynamic>;
      return payload['security_id']?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Error parsing';
    }
  }

  String _getSecurityName() {
    if (_securityQrData == null) return 'N/A';
    try {
      final payload = jsonDecode(_securityQrData!) as Map<String, dynamic>;
      return payload['security_name']?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Error parsing';
    }
  }

  String _getSecurityRole() {
    if (_securityQrData == null) return 'N/A';
    try {
      final payload = jsonDecode(_securityQrData!) as Map<String, dynamic>;
      return payload['security_role']?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Error parsing';
    }
  }

  String _getGeneratedTime() {
    if (_securityQrData == null) return 'N/A';
    try {
      final payload = jsonDecode(_securityQrData!) as Map<String, dynamic>;
      final timestamp = payload['timestamp'] as int?;
      if (timestamp == null) return 'Unknown';
      final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateFormat('HH:mm:ss dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return 'Error parsing';
    }
  }

  String _getExpirationTime() {
    if (_securityQrData == null) return 'N/A';
    try {
      final payload = jsonDecode(_securityQrData!) as Map<String, dynamic>;
      final expiresAt = payload['expires_at'] as int?;
      if (expiresAt == null) return 'Unknown';
      final dateTime = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      return DateFormat('HH:mm:ss dd/MM/yyyy').format(dateTime);
    } catch (e) {
      return 'Error parsing';
    }
  }
}
