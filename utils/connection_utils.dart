import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

class ConnectionUtils {
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);
  static const Duration _maxDelay = Duration(seconds: 30);
  
  /// 🔥 Retry logic with exponential backoff
  static Future<T> retryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration baseDelay = _baseDelay,
    Duration maxDelay = _maxDelay,
    bool Function(dynamic error)? shouldRetry,
    String? operationName,
  }) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < maxRetries) {
      try {
        final result = await operation();
        if (attempts > 0 && operationName != null) {
          debugPrint('🔥 $operationName succeeded after ${attempts + 1} attempts');
        }
        return result;
      } catch (error) {
        lastError = error;
        attempts++;

        if (operationName != null) {
          debugPrint('🔥 $operationName attempt $attempts failed: $error');
        }

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          debugPrint('🔥 Not retrying due to error type: $error');
          rethrow;
        }

        // Don't delay on the last attempt
        if (attempts < maxRetries) {
          final delay = _calculateDelay(attempts, baseDelay, maxDelay);
          if (operationName != null) {
            debugPrint('🔥 Retrying $operationName in ${delay.inSeconds}s...');
          }
          await Future.delayed(delay);
        }
      }
    }

    if (operationName != null) {
      debugPrint('🔥 $operationName failed after $maxRetries attempts');
    }
    throw lastError;
  }

  /// 🔥 Calculate exponential backoff delay
  static Duration _calculateDelay(int attempt, Duration baseDelay, Duration maxDelay) {
    final exponentialDelay = baseDelay * pow(2, attempt - 1);
    final delayWithJitter = Duration(
      milliseconds: (exponentialDelay.inMilliseconds * (0.8 + Random().nextDouble() * 0.4)).round(),
    );
    
    return delayWithJitter > maxDelay ? maxDelay : delayWithJitter;
  }

  /// 🔥 Default retry condition for network errors
  static bool shouldRetryNetworkError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    
    // Retry on network-related errors
    final retryableErrors = [
      'socket',
      'timeout',
      'connection',
      'network',
      'host',
      'unreachable',
    ];

    return retryableErrors.any((keyword) => errorMessage.contains(keyword));
  }

  /// 🔥 Default retry condition for API errors
  static bool shouldRetryApiError(dynamic error) {
    final errorMessage = error.toString().toLowerCase();
    
    // Don't retry on client errors (4xx), but retry on server errors (5xx)
    if (errorMessage.contains('400') || 
        errorMessage.contains('401') || 
        errorMessage.contains('403') || 
        errorMessage.contains('404')) {
      return false;
    }
    
    // Retry on server errors and network issues
    return errorMessage.contains('500') || 
           errorMessage.contains('502') || 
           errorMessage.contains('503') || 
           errorMessage.contains('504') || 
           shouldRetryNetworkError(error);
  }

  /// 🔥 Circuit breaker for preventing cascading failures
  static CircuitBreaker createCircuitBreaker({
    required String name,
    int failureThreshold = 5,
    Duration timeout = const Duration(seconds: 60),
    Duration resetTimeout = const Duration(minutes: 1),
  }) {
    return CircuitBreaker(
      name: name,
      failureThreshold: failureThreshold,
      timeout: timeout,
      resetTimeout: resetTimeout,
    );
  }

  /// 🔥 Rate limiter to prevent overwhelming the server
  static RateLimiter createRateLimiter({
    required int maxRequests,
    required Duration window,
  }) {
    return RateLimiter(
      maxRequests: maxRequests,
      window: window,
    );
  }
}

/// 🔥 Circuit Breaker Implementation
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration resetTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  Timer? _resetTimer;

  CircuitBreaker({
    required this.name,
    required this.failureThreshold,
    required this.timeout,
    required this.resetTimeout,
  });

  /// Execute operation through circuit breaker
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitBreakerState.open) {
      if (_shouldAttemptReset()) {
        _state = CircuitBreakerState.halfOpen;
        debugPrint('🔥 Circuit breaker $name: Half-open state');
      } else {
        throw CircuitBreakerOpenException('Circuit breaker $name is open');
      }
    }

    try {
      final result = await operation().timeout(timeout);
      _onSuccess();
      return result;
    } catch (error) {
      _onFailure();
      rethrow;
    }
  }

  bool _shouldAttemptReset() {
    if (_lastFailureTime == null) return true;
    return DateTime.now().difference(_lastFailureTime!) >= resetTimeout;
  }

  void _onSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
    _resetTimer?.cancel();
    
    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.closed;
      debugPrint('🔥 Circuit breaker $name: Closed state');
    }
  }

  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      debugPrint('🔥 Circuit breaker $name: Open state (failures: $_failureCount)');
      
      _resetTimer = Timer(resetTimeout, () {
        debugPrint('🔥 Circuit breaker $name: Ready for half-open attempt');
      });
    }
  }

  CircuitBreakerState get state => _state;
  int get failures => _failureCount;
}

enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreakerOpenException implements Exception {
  final String message;
  CircuitBreakerOpenException(this.message);
  
  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// 🔥 Rate Limiter Implementation
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final List<DateTime> _requests = [];

  RateLimiter({
    required this.maxRequests,
    required this.window,
  });

  /// Check if request is allowed
  Future<bool> allowRequest() async {
    final now = DateTime.now();
    final cutoff = now.subtract(window);

    // Remove old requests
    _requests.removeWhere((request) => request.isBefore(cutoff));

    if (_requests.length >= maxRequests) {
      final oldestRequest = _requests.first;
      final waitTime = window - now.difference(oldestRequest);
      
      if (waitTime > Duration.zero) {
        debugPrint('🔥 Rate limit hit, waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
      
      // Clean up again after waiting
      _requests.removeWhere((request) => request.isBefore(DateTime.now().subtract(window)));
    }

    _requests.add(now);
    return true;
  }

  int get currentRequests => _requests.length;
}

/// 🔥 Connection Pool for managing multiple connections
class ConnectionPool {
  final int maxConnections;
  final Duration connectionTimeout;
  final List<Connection> _pool = [];
  final Queue<Completer<Connection>> _waitingQueue = Queue();

  ConnectionPool({
    this.maxConnections = 5,
    this.connectionTimeout = const Duration(seconds: 30),
  });

  Future<Connection> acquire() async {
    // Return available connection
    for (final connection in _pool) {
      if (connection.isAvailable) {
        connection._inUse = true;
        return connection;
      }
    }

    // Create new connection if under limit
    if (_pool.length < maxConnections) {
      final connection = Connection();
      _pool.add(connection);
      connection._inUse = true;
      return connection;
    }

    // Wait for available connection
    final completer = Completer<Connection>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  void release(Connection connection) {
    connection._inUse = false;
    
    // Fulfill waiting requests
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      connection._inUse = true;
      completer.complete(connection);
    }
  }

  void dispose() {
    _pool.clear();
    while (_waitingQueue.isNotEmpty) {
      _waitingQueue.removeFirst().completeError('Connection pool disposed');
    }
  }
}

class Connection {
  bool _inUse = false;
  final DateTime createdAt = DateTime.now();

  bool get isAvailable => !_inUse;
  bool get inUse => _inUse;
}

/// 🔥 Queue implementation for deferred operations
class Queue<T> {
  final List<T> _items = [];

  void add(T item) => _items.add(item);
  T removeFirst() => _items.removeAt(0);
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;
}