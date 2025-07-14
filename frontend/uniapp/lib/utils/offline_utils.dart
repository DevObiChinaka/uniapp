import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../screens/app_constants.dart';
import '../models/models.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  final List<Function(bool)> _listeners = [];
  bool _isConnected = true;
  Timer? _periodicCheck;

  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Get initial connectivity status
    _isConnected = await _checkConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _handleConnectivityChange(result);
    });
    
    // Periodic check for actual internet connectivity (not just network connection)
    _periodicCheck = Timer.periodic(Duration(minutes: 1), (timer) async {
      final hasInternet = await _checkConnectivity();
      if (hasInternet != _isConnected) {
        _isConnected = hasInternet;
        _notifyListeners();
      }
    });
  }

  // Check if device has actual internet connectivity, not just network connection
  Future<bool> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result == ConnectivityResult.none) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    _isConnected = result != ConnectivityResult.none;
    _notifyListeners();
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener(_isConnected);
    }
  }

  void addListener(Function(bool) listener) {
    _listeners.add(listener);
    // Immediately notify with current status
    listener(_isConnected);
  }

  void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }

  bool get isConnected => _isConnected;

  Future<bool> get checkConnectivity => _checkConnectivity();

  void dispose() {
    _connectivitySubscription?.cancel();
    _periodicCheck?.cancel();
    _listeners.clear();
  }
}

class OfflineDataManager {
  static const String _offlineAttendanceKey = AppConstants.offlineAttendanceKey;

  // Save offline attendance record
  static Future<bool> saveOfflineAttendance(OfflineAttendanceRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getStringList(_offlineAttendanceKey) ?? [];
      
      // Check if we've reached the maximum number of stored records
      if (existingData.length >= AppConstants.maxOfflineRecords) {
        debugPrint('Maximum offline records reached (${AppConstants.maxOfflineRecords})');
        return false;
      }
      
      // Add the new record
      existingData.add(jsonEncode(record.toJson()));
      await prefs.setStringList(_offlineAttendanceKey, existingData);
      debugPrint('Saved offline attendance record: ${record.id}');
      return true;
    } catch (e) {
      debugPrint('Error saving offline attendance: $e');
      return false;
    }
  }
  
  // Get all stored offline attendance records
  static Future<List<OfflineAttendanceRecord>> getOfflineAttendanceRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_offlineAttendanceKey) ?? [];
      
      return data.map((jsonStr) {
        final json = jsonDecode(jsonStr);
        return OfflineAttendanceRecord.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('Error getting offline attendance records: $e');
      return [];
    }
  }
  
  // Remove synced offline attendance records
  static Future<void> removeSyncedRecords(List<String> recordIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getStringList(_offlineAttendanceKey) ?? [];
      
      final updatedData = existingData.where((jsonStr) {
        final record = OfflineAttendanceRecord.fromJson(jsonDecode(jsonStr));
        return !recordIds.contains(record.id);
      }).toList();
      
      await prefs.setStringList(_offlineAttendanceKey, updatedData);
      debugPrint('Removed ${recordIds.length} synced offline records');
    } catch (e) {
      debugPrint('Error removing synced records: $e');
    }
  }
  
  // Remove an individual offline record
  static Future<bool> removeOfflineRecord(String recordId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getStringList(_offlineAttendanceKey) ?? [];
      
      final updatedData = existingData.where((jsonStr) {
        final record = OfflineAttendanceRecord.fromJson(jsonDecode(jsonStr));
        return record.id != recordId;
      }).toList();
      
      if (existingData.length == updatedData.length) {
        return false; // Record not found
      }
      
      await prefs.setStringList(_offlineAttendanceKey, updatedData);
      return true;
    } catch (e) {
      debugPrint('Error removing offline record: $e');
      return false;
    }
  }
  
  // Count pending offline records
  static Future<int> countPendingRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_offlineAttendanceKey) ?? [];
      return data.length;
    } catch (e) {
      debugPrint('Error counting pending records: $e');
      return 0;
    }
  }
  
  // Clear all offline attendance records
  static Future<void> clearAllOfflineRecords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineAttendanceKey);
      debugPrint('Cleared all offline attendance records');
    } catch (e) {
      debugPrint('Error clearing offline records: $e');
    }
  }
}
