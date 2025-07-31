import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:uniapp/screens/app_constants.dart';
import 'package:uniapp/utils/location_utils.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

class LecturerQrGenerationScreen extends StatefulWidget {
  final String sessionId;
  final String program;

  const LecturerQrGenerationScreen({
    super.key,
    required this.sessionId,
    required this.program,
  });

  @override
  State<LecturerQrGenerationScreen> createState() =>
      _LecturerQrGenerationScreenState();
}

class _LecturerQrGenerationScreenState
    extends State<LecturerQrGenerationScreen> {
  String _qrData = '';
  int _secondsLeft = AppConstants.qrTtlSeconds;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  double? _lat;
  double? _lng;
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    debugPrint('QR Screen: initState called');
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    debugPrint('QR Screen: Checking location permission...');
    final status = await Permission.location.request();
    debugPrint('QR Screen: Permission status: [33m$status[0m');
    if (!status.isGranted) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Location permission denied. Please enable location.';
      });
      debugPrint('QR Screen: Location permission denied.');
      return;
    }
    try {
      await _generateQrCodeWithLocation();
      _startRefreshTimer();
      _startCountdownTimer();
      setState(() {
        _isLoading = false;
      });
      debugPrint('QR Screen: Initial QR and location ready.');
    } catch (e, st) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Failed to initialize QR code: $e';
      });
      debugPrint('QR Screen: Error during init: $e\n$st');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: AppConstants.qrTtlSeconds),
      (_) async {
        debugPrint('QR Screen: Auto-refresh triggered');
        await _handleRefresh();
      },
    );
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsLeft = (_secondsLeft - 1);
        if (_secondsLeft <= 0) {
          _secondsLeft = AppConstants.qrTtlSeconds;
        }
      });
    });
  }

  Future<void> _handleRefresh() async {
    if (_isLoading) {
      debugPrint('QR Screen: Refresh blocked, already loading');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _generateQrCodeWithLocation();
      debugPrint('QR Screen: Manual/auto refresh complete');
    } catch (e, st) {
      debugPrint('QR Screen: Error during refresh: $e\n$st');
      setState(() => _errorMsg = 'Failed to refresh QR: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateQrCodeWithLocation() async {
    debugPrint('QR Screen: Generating QR with location...');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    double? lat;
    double? lng;
    final payloadMap = await _createPayloadMapWithLocation();
    if (payloadMap['location'] != null) {
      lat = payloadMap['location']['lat'];
      lng = payloadMap['location']['lng'];
      debugPrint('QR Screen: Got location for QR: lat=$lat, lng=$lng');
    } else {
      debugPrint('QR Screen: No location in payload');
    }
    final signature = _generateSignature(
      jsonEncode(payloadMap),
      timestamp.toString(),
    );
    final qrData = {
      'payload': payloadMap,
      'timestamp': timestamp,
      'signature': signature,
    };
    setState(() {
      _qrData = jsonEncode(qrData);
      _secondsLeft = AppConstants.qrTtlSeconds;
      _lat = lat;
      _lng = lng;
    });
  }

  Future<Map<String, dynamic>> _createPayloadMapWithLocation() async {
    double? lat;
    double? lng;
    try {
      final position = await LocationUtils.getCurrentLocation();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        debugPrint(
          'QR Screen: Location fetched: lat=\x1b[32m$lat\x1b[0m, lng=\x1b[32m$lng\x1b[0m',
        );
      } else {
        debugPrint('QR Screen: LocationUtils returned null');
      }
    } catch (e) {
      debugPrint('QR Screen: Error fetching location: $e');
    }
    final Map<String, dynamic> payloadMap = {
      'session_id': widget.sessionId,
      'program': widget.program,
      'timestamp': DateTime.now().toIso8601String(),
    };
    if (lat != null && lng != null) {
      payloadMap['location'] = {'lat': lat, 'lng': lng};
    }
    return payloadMap;
  }

  String _generateSignature(String payload, String timestamp) {
    final dataToSign = payload + timestamp;
    final hmac = Hmac(sha256, utf8.encode(AppConstants.hmacSecretKey));
    final digest = hmac.convert(utf8.encode(dataToSign));
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance QR Code'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed:
                (_isLoading || _secondsLeft != AppConstants.qrTtlSeconds)
                    ? null
                    : () async {
                      debugPrint('QR Screen: Manual refresh button pressed');
                      await _handleRefresh();
                    },
            tooltip: 'Generate New QR Code',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child:
                  _errorMsg != null
                      ? Center(
                        child: Text(
                          _errorMsg!,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.redAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 250.0,
                            backgroundColor: Colors.white,
                          ),
                          SizedBox(height: 24),
                          if (_lat != null && _lng != null)
                            SizedBox(
                              height: 180,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Builder(
                                  builder: (context) {
                                    debugPrint(
                                      'QR Screen: Building OSM map widget with lat=$_lat, lng=$_lng',
                                    );
                                    return FlutterMap(
                                      options: MapOptions(
                                        center: LatLng(_lat!, _lng!),
                                        zoom: 17,
                                        interactionOptions:
                                            const InteractionOptions(
                                              flags:
                                                  InteractiveFlag
                                                      .none, // disables gestures
                                            ),
                                      ),
                                      // Required for flutter_map 6.x+
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          subdomains: ['a', 'b', 'c'],
                                          userAgentPackageName:
                                              'com.example.uniapp',
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: LatLng(_lat!, _lng!),
                                              width: 40,
                                              height: 40,
                                              child: Icon(
                                                Icons.location_on,
                                                color: Colors.red,
                                                size: 40,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          if (_lat == null || _lng == null)
                            Text(
                              'Location unavailable. QR will not be location-locked.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                          SizedBox(height: 16),
                          Text(
                            'QR code refreshes in [32m$_secondsLeft[0m seconds',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Session: ${widget.sessionId}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Program: ${widget.program}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
            ),
        ],
      ),
    );
  }
}
