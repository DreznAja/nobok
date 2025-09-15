import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_utils.dart';

/// Enhanced connection service for monitoring network connectivity
class ConnectionService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  static bool _isConnected = true;
  static bool _isInitialized = false;
  
  // Callbacks for connection state changes
  static Function(bool isConnected)? onConnectionChanged;
  
  /// Initialize connection service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      DebugUtils.log('Initializing ConnectionService...');
      
      // Check initial connectivity
      final initialResult = await _connectivity.checkConnectivity();
      _isConnected = _isConnectedFromResult(initialResult);
      
      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = _isConnectedFromResult(results);
          
          if (wasConnected != _isConnected) {
            DebugUtils.log(
              'Connection state changed: ${_isConnected ? "Connected" : "Disconnected"}',
              category: 'CONNECTION'
            );
            onConnectionChanged?.call(_isConnected);
          }
        },
        onError: (error) {
          DebugUtils.log('Connectivity stream error: $error', category: 'ERROR');
        },
      );
      
      _isInitialized = true;
      DebugUtils.log('ConnectionService initialized. Initial state: ${_isConnected ? "Connected" : "Disconnected"}');
      
    } catch (e) {
      DebugUtils.log('Error initializing ConnectionService: $e', category: 'ERROR');
      rethrow;
    }
  }

  /// Check if device is connected based on connectivity results
  static bool _isConnectedFromResult(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    
    // Consider connected if any of the results indicate connectivity
    return results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn
    );
  }

  /// Get current connection status
  static bool get isConnected => _isConnected;

  /// Check connection status now (force check)
  static Future<bool> checkConnectionNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final newConnectionState = _isConnectedFromResult(results);
      
      if (_isConnected != newConnectionState) {
        _isConnected = newConnectionState;
        DebugUtils.log(
          'Connection state updated: ${_isConnected ? "Connected" : "Disconnected"}',
          category: 'CONNECTION'
        );
        onConnectionChanged?.call(_isConnected);
      }
      
      return _isConnected;
    } catch (e) {
      DebugUtils.log('Error checking connection: $e', category: 'ERROR');
      return false;
    }
  }

  /// Get detailed connectivity information
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      
      return {
        'isConnected': _isConnectedFromResult(results),
        'connectionTypes': results.map((r) => r.name).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      DebugUtils.log('Error getting connection info: $e', category: 'ERROR');
      return {
        'isConnected': false,
        'connectionTypes': [],
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Wait for connection to be available
  static Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
    Duration checkInterval = const Duration(seconds: 1),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      if (await checkConnectionNow()) {
        DebugUtils.log('Connection available after ${stopwatch.elapsed.inSeconds}s');
        return true;
      }
      
      await Future.delayed(checkInterval);
    }
    
    DebugUtils.log('Connection timeout after ${timeout.inSeconds}s', category: 'WARNING');
    return false;
  }

  /// Dispose connection service
  static Future<void> dispose() async {
    try {
      await _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
      _isInitialized = false;
      
      DebugUtils.log('ConnectionService disposed');
    } catch (e) {
      DebugUtils.log('Error disposing ConnectionService: $e', category: 'ERROR');
    }
  }

  /// Set connection state manually (for testing)
  static void setConnectionState(bool isConnected) {
    if (kDebugMode) {
      final wasConnected = _isConnected;
      _isConnected = isConnected;
      
      if (wasConnected != _isConnected) {
        DebugUtils.log(
          'Connection state manually set: ${_isConnected ? "Connected" : "Disconnected"}',
          category: 'CONNECTION'
        );
        onConnectionChanged?.call(_isConnected);
      }
    }
  }

  /// Get connection status as string
  static String get connectionStatusText {
    return _isConnected ? 'Connected' : 'Disconnected';
  }

  /// Check if connection service is initialized
  static bool get isInitialized => _isInitialized;
}