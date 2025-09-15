import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Utility class for message processing and formatting
class MessageUtils {
  /// ✅ FIXED: Safe JSON parsing with proper null checks
  static Map<String, dynamic>? parseJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty || jsonString == 'null') {
      return null;
    }
    
    try {
      final decoded = jsonDecode(jsonString);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      print('🔥 Error parsing JSON: $e');
      return null;
    }
  }

  /// Check if string is valid JSON
  static bool isValidJson(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Convert text to clickable text (replace URLs, mentions, etc)
  static String convertToClickableText(String text) {
    // Simple implementation - can be enhanced with actual URL detection
    return text;
  }

  /// Format currency with thousand separators
  static String formatCurrency(String price) {
    try {
      final number = double.tryParse(price.replaceAll(',', '')) ?? 0;
      final formatter = NumberFormat('#,##0', 'en_US');
      return formatter.format(number);
    } catch (e) {
      return price;
    }
  }

  /// Parse vCard data to contact information
  static Map<String, dynamic> parseVCard(String vCardData) {
    final Map<String, dynamic> contact = {};
    
    try {
      // Basic vCard parsing - can be enhanced
      final lines = vCardData.split('\n');
      
      for (String line in lines) {
        if (line.startsWith('FN:')) {
          contact['fn'] = line.substring(3);
        } else if (line.startsWith('TEL:')) {
          final telValue = line.substring(4);
          contact['tel'] = [
            {
              'value': [telValue]
            }
          ];
        }
      }
    } catch (e) {
      print('🔥 Error parsing vCard: $e');
    }
    
    return contact;
  }

  /// Copy text to clipboard
  static Future<void> copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      print('🔥 Error copying to clipboard: $e');
    }
  }

  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Check if string is empty or null
  static bool isEmptyOrNull(String? value) {
    return value == null || value.isEmpty || value.trim().isEmpty || value == 'null';
  }

  /// Clean HTML tags from text
  static String cleanHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Extract URLs from text
  static List<String> extractUrls(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    
    final matches = urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  /// Format time for display
  static String formatDisplayTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today - show time only
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays < 7) {
      // This week - show day name
      return DateFormat('EEEE HH:mm').format(dateTime);
    } else {
      // Older - show date
      return DateFormat('dd/MM HH:mm').format(dateTime);
    }
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phone);
  }

  /// Generate random string
  static String generateRandomId([int length = 10]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => 
      chars[(random + index) % chars.length]).join();
  }

  /// Debounce function calls
  static Timer? _debounceTimer;
  
  static void debounce(Duration duration, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }

  /// Throttle function calls
  static DateTime? _lastThrottleTime;
  
  static void throttle(Duration duration, VoidCallback callback) {
    final now = DateTime.now();
    if (_lastThrottleTime == null || 
        now.difference(_lastThrottleTime!) >= duration) {
      _lastThrottleTime = now;
      callback();
    }
  }

  /// Get file extension from filename
  static String getFileExtension(String filename) {
    return filename.split('.').last.toLowerCase();
  }

  /// Check if file is image
  static bool isImageFile(String filename) {
    final ext = getFileExtension(filename);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  /// Check if file is video
  static bool isVideoFile(String filename) {
    final ext = getFileExtension(filename);
    return ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'].contains(ext);
  }

  /// Check if file is audio
  static bool isAudioFile(String filename) {
    final ext = getFileExtension(filename);
    return ['mp3', 'wav', 'ogg', 'aac', 'm4a'].contains(ext);
  }

  /// Escape HTML characters
  static String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  /// Unescape HTML characters
  static String unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'");
  }
}