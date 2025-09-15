import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service untuk manage network connection status dan server availability
class ConnectionService {
  static const String _serverUrl = 'https://id.nobox.ai';
  static final Connectivity _connectivity = Connectivity();
  
  static StreamController<bool>? _connectionController;
  static Timer? _connectionTimer;
  static bool _isOnline = true;
  static bool _isServerAvailable = true;
  
  /// Initialize connection monitoring
  static Future<void> initialize() async {
    _connectionController = StreamController<bool>.broadcast();
    
    // Check initial connection
    await _checkConnection();
    
    // Start periodic checks
    _startPeriodicChecks();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _checkConnection();
    });
    
    print('🔥 📡 ConnectionService initialized');
  }
  
  /// Start periodic connection checks
  static void _startPeriodicChecks() {
    _connectionTimer?.cancel();
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnection();
    });
  }
  
  /// Check current connection status
  static Future<void> _checkConnection() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasNetworkConnection = connectivityResult != ConnectivityResult.none;
      
      bool serverAvailable = false;
      
      if (hasNetworkConnection) {
        serverAvailable = await _checkServerAvailability();
      }
      
      final wasOnline = _isOnline;
      final wasServerAvailable = _isServerAvailable;
      
      _isOnline = hasNetworkConnection;
      _isServerAvailable = serverAvailable;
      
      // Notify if status changed
      if (wasOnline != _isOnline || wasServerAvailable != _isServerAvailable) {
        final isConnected = _isOnline && _isServerAvailable;
        _connectionController?.add(isConnected);
        
        print('🔥 📡 Connection status changed:');
        print('🔥    Network: $hasNetworkConnection');
        print('🔥    Server: $serverAvailable');
        print('🔥    Overall: $isConnected');
      }
      
    } catch (e) {
      print('🔥 Error checking connection: $e');
      _isOnline = false;
      _isServerAvailable = false;
      _connectionController?.add(false);
    }
  }
  
  /// Check if server is available
  static Future<bool> _checkServerAvailability() async {
    try {
      final response = await http.get(
        Uri.parse(_serverUrl),
        headers: {'Accept': 'text/html,application/json'},
      ).timeout(const Duration(seconds: 10));
      
      final isAvailable = response.statusCode >= 200 && response.statusCode < 500;
      print('🔥 📡 Server check: ${response.statusCode} - ${isAvailable ? 'Available' : 'Unavailable'}');
      
      return isAvailable;
    } catch (e) {
      print('🔥 📡 Server unavailable: $e');
      return false;
    }
  }
  
  /// Get connection stream
  static Stream<bool> get connectionStream {
    return _connectionController?.stream ?? Stream.empty();
  }
  
  /// Check if device has internet connection
  static bool get isOnline => _isOnline;
  
  /// Check if server is available
  static bool get isServerAvailable => _isServerAvailable;
  
  /// Check if fully connected (network + server)
  static bool get isConnected => _isOnline && _isServerAvailable;
  
  /// Check if should use offline mode
  static bool get shouldUseOfflineMode => !isConnected;
  
  /// Force check connection immediately
  static Future<bool> checkConnectionNow() async {
    await _checkConnection();
    return isConnected;
  }
  
  /// Get connection status details
  static Future<Map<String, dynamic>> getConnectionStatus() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    
    return {
      'hasNetwork': _isOnline,
      'serverAvailable': _isServerAvailable,
      'isConnected': isConnected,
      'shouldUseOffline': shouldUseOfflineMode,
      'connectivityType': connectivityResult.toString(),
      'lastChecked': DateTime.now().toIso8601String(),
    };
  }
  
  /// Dispose connection service
  static void dispose() {
    _connectionTimer?.cancel();
    _connectionController?.close();
    print('🔥 📡 ConnectionService disposed');
  }
}