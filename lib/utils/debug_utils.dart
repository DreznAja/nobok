@@ .. @@
 import 'dart:convert';
 import 'package:flutter/foundation.dart';

 class DebugUtils {
   static bool _isDebugMode = kDebugMode;
   static List<String> _logs = [];
   static int _maxLogs = 100;

-  /// 🔥 Enable/disable debug mode
+  /// Enable/disable debug mode
   static void setDebugMode(bool enabled) {
     _isDebugMode = enabled;
   }

-  /// 🔥 Log with timestamp and category
+  /// Log with timestamp and category
   static void log(String message, {String category = 'INFO'}) {
     if (!_isDebugMode) return;

     final timestamp = DateTime.now().toIso8601String();
     final logEntry = '[$timestamp] [$category] $message';
     
     // Print to console
-    print('🔥 $logEntry');
+    debugPrint('DEBUG: $logEntry');
     
     // Store in memory (for debugging UI)
     _logs.add(logEntry);
     if (_logs.length > _maxLogs) {
       _logs.removeAt(0);
     }
   }

-  /// 🔥 Log API requests/responses
+  /// Log API requests/responses
   static void logApiCall(String method, String endpoint, {
     Map<String, dynamic>? requestBody,
     int? statusCode,
     String? responseBody,
     String? error,
   }) {
     if (!_isDebugMode) return;

     final buffer = StringBuffer();
     buffer.writeln('API Call: $method $endpoint');
     
     if (requestBody != null) {
       buffer.writeln('Request Body: ${_formatJson(requestBody)}');
     }
     
     if (statusCode != null) {
       buffer.writeln('Status Code: $statusCode');
     }
     
     if (responseBody != null) {
       buffer.writeln('Response Body: ${_truncateString(responseBody, 500)}');
     }
     
     if (error != null) {
       buffer.writeln('Error: $error');
     }

     log(buffer.toString(), category: 'API');
   }

-  /// 🔥 Log message parsing attempts
+  /// Log message parsing attempts
   static void logMessageParsing(Map<String, dynamic> json, {
     bool success = true,
     String? error,
     String? result,
   }) {
     if (!_isDebugMode) return;

     final buffer = StringBuffer();
     buffer.writeln('Message Parsing ${success ? 'SUCCESS' : 'FAILED'}');
     buffer.writeln('JSON Keys: ${json.keys.toList()}');
     
     if (error != null) {
       buffer.writeln('Error: $error');
     }
     
     if (result != null) {
       buffer.writeln('Result: $result');
     }
     
     // Log sample of important fields
     final importantFields = ['Id', 'Body', 'Content', 'SenderId', 'CreatedAt', 'LinkId', 'ChannelId'];
     for (final field in importantFields) {
       if (json.containsKey(field)) {
         buffer.writeln('$field: ${_truncateString(json[field].toString(), 100)}');
       }
     }

     log(buffer.toString(), category: success ? 'PARSE_SUCCESS' : 'PARSE_ERROR');
   }

-  /// 🔥 Get all logs (for debug UI)
+  /// Get all logs (for debug UI)
   static List<String> getAllLogs() {
     return List.from(_logs);
   }

-  /// 🔥 Clear all logs
+  /// Clear all logs
   static void clearLogs() {
     _logs.clear();
   }

-  /// 🔥 Export logs as string
+  /// Export logs as string
   static String exportLogs() {
     return _logs.join('\n');
   }

-  /// 🔥 Helper to format JSON nicely
+  /// Helper to format JSON nicely
   static String _formatJson(Map<String, dynamic> json) {
     try {
       const encoder = JsonEncoder.withIndent('  ');
       return encoder.convert(json);
     } catch (e) {
       return json.toString();
     }
   }

-  /// 🔥 Helper to truncate long strings
+  /// Helper to truncate long strings
   static String _truncateString(String str, int maxLength) {
     if (str.length <= maxLength) return str;
     return '${str.substring(0, maxLength)}...';
   }

-  /// 🔥 Validate message data structure
+  /// Validate message data structure
   static Map<String, dynamic> validateMessageStructure(Map<String, dynamic> json) {
     final issues = <String>[];
     final recommendations = <String>[];

     // Check for required fields
     if (!json.containsKey('Id') && !json.containsKey('id')) {
       issues.add('Missing ID field');
       recommendations.add('Add unique identifier for the message');
     }

     // Check for message content
     final contentFields = ['Body', 'Content', 'Message', 'Text', 'LastMsg'];
     final hasContent = contentFields.any((field) => 
         json.containsKey(field) && 
         json[field] != null && 
         json[field].toString().trim().isNotEmpty
     );
     
     if (!hasContent) {
       issues.add('No message content found');
       recommendations.add('Check if this is actually a message or metadata');
     }

     // Check for sender information
     final senderFields = ['SenderId', 'FromId', 'ContactId', 'SdrMsg'];
     final hasSender = senderFields.any((field) => 
         json.containsKey(field) && 
         json[field] != null
     );
     
     if (!hasSender) {
       issues.add('No sender information found');
       recommendations.add('Add sender identification');
     }

     // Check for timestamp
     final timeFields = ['CreatedAt', 'Timestamp', 'Time', 'TimeMsg'];
     final hasTime = timeFields.any((field) => 
         json.containsKey(field) && 
         json[field] != null
     );
     
     if (!hasTime) {
       issues.add('No timestamp found');
       recommendations.add('Add message timestamp');
     }

     // Log validation results
     if (issues.isNotEmpty) {
       log('Message validation issues: ${issues.join(', ')}', category: 'VALIDATION');
       log('Recommendations: ${recommendations.join(', ')}', category: 'VALIDATION');
     }

     return {
       'valid': issues.isEmpty,
       'issues': issues,
       'recommendations': recommendations,
       'availableFields': json.keys.toList(),
     };
   }

-  /// 🔥 Performance monitoring
+  /// Performance monitoring
   static void measurePerformance(String operation, Future<void> Function() task) async {
     if (!_isDebugMode) return;

     final stopwatch = Stopwatch()..start();
     try {
       await task();
       stopwatch.stop();
       log('$operation completed in ${stopwatch.elapsedMilliseconds}ms', category: 'PERFORMANCE');
     } catch (e) {
       stopwatch.stop();
       log('$operation failed after ${stopwatch.elapsedMilliseconds}ms: $e', category: 'PERFORMANCE');
       rethrow;
     }
   }

-  /// 🔥 Create debug report
+  /// Create debug report
   static Map<String, dynamic> createDebugReport({
     required int messageCount,
     required bool realTimeEnabled,
     required String currentChat,
     List<String>? recentErrors,
   }) {
     return {
       'timestamp': DateTime.now().toIso8601String(),
       'messageCount': messageCount,
       'realTimeEnabled': realTimeEnabled,
       'currentChat': currentChat,
       'recentErrors': recentErrors ?? [],
       'totalLogs': _logs.length,
       'debugMode': _isDebugMode,
       'lastLogs': _logs.take(10).toList(),
     };
   }
 }