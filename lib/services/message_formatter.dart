import 'dart:convert';
import '../models/message_model.dart';

/// Enhanced message formatter based on the JavaScript implementation
class MessageFormatter {
  
  /// Format message content with rich text support
  static String formatMessage(String text) {
    if (text.isEmpty) return text;
    
    // Convert bold (e.g., *Bold*)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w|https?:\/\/)(?<!\S)\*(.*?)\*(?!\S)(?!\w)'),
      (match) => '<strong style="font-weight: bold;">${match.group(1)}</strong>',
    );

    // Convert italic (e.g., _Italic_)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w|https?:\/\/)(?<!\S)_(.*?)_(?!\S)(?!\w)'),
      (match) => '<em style="font-style: italic;">${match.group(1)}</em>',
    );

    // Convert strikethrough (e.g., ~Strikethrough~)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w|https?:\/\/)(?<!\S)~(.*?)~(?!\S)(?!\w)'),
      (match) => '<s style="text-decoration: line-through;">${match.group(1)}</s>',
    );

    // Convert monospace block code (e.g., ```Block Code```)
    text = text.replaceAllMapped(
      RegExp(r'```([\s\S]*?)```'),
      (match) => '<pre style="font-family: monospace;background-color: #f3f3f3;padding: 4px;border-radius: 4px;">${match.group(1)}</pre>',
    );

    // Convert inline monospace (e.g., `Inline Code`)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\w|https?:\/\/)(?<!\S)`(.*?)`(?!\S)(?!\w)'),
      (match) => '<code style="font-family: monospace;background-color:rgb(243 243 243 / 16%);border-radius:4px;padding:2px;">${match.group(1)}</code>',
    );

    // Process lists and quotes
    text = _processListsAndQuotes(text);
    
    return text;
  }
  
  /// Process bulleted lists, numbered lists, and blockquotes
  static String _processListsAndQuotes(String text) {
    final lines = text.split('\n');
    final result = StringBuffer();
    bool inBulletedList = false;
    bool inNumberedList = false;

    for (final line in lines) {
      if (RegExp(r'^- ').hasMatch(line)) {
        // Handle bulleted list
        if (!inBulletedList) {
          result.write('<ul style="padding-left: 20px;">');
          inBulletedList = true;
        }
        if (inNumberedList) {
          result.write('</ol>');
          inNumberedList = false;
        }
        result.write('<li style="list-style-type: disc;">${line.substring(2).trim()}</li>');
      } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        // Handle numbered list
        if (!inNumberedList) {
          result.write('<ol style="padding-left: 20px;">');
          inNumberedList = true;
        }
        if (inBulletedList) {
          result.write('</ul>');
          inBulletedList = false;
        }
        result.write('<li style="list-style-type: decimal;">${line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim()}</li>');
      } else if (RegExp(r'^> ').hasMatch(line)) {
        // Handle blockquote
        if (inBulletedList) {
          result.write('</ul>');
          inBulletedList = false;
        }
        if (inNumberedList) {
          result.write('</ol>');
          inNumberedList = false;
        }
        result.write('<blockquote style="border-left: 4px solid #ccc; margin: 0; font-style: italic; background-color: rgb(243 243 243 / 16%); padding: 2px; border-radius: 4px;">${line.substring(2).trim()}</blockquote>');
      } else {
        // Close any open lists if we encounter a non-list item
        if (inBulletedList) {
          result.write('</ul>');
          inBulletedList = false;
        }
        if (inNumberedList) {
          result.write('</ol>');
          inNumberedList = false;
        }
        // Add non-list content with line breaks for empty lines
        result.write(line.trim().isNotEmpty ? '$line<br>' : '<br>');
      }
    }

    // Close any open lists at the end
    if (inBulletedList) {
      result.write('</ul>');
    }
    if (inNumberedList) {
      result.write('</ol>');
    }

    return result.toString();
  }
  
  /// Convert text URLs to clickable links
  static String text2Url(String text, {bool isMyMessage = false}) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    
    return text.replaceAllMapped(urlRegex, (match) {
      final url = match.group(0)!;
      final color = isMyMessage ? 'white' : '#007AFF';
      return '<a target="_blank" style="text-decoration: underline;color:$color;line-break:auto;" href="$url">$url</a>';
    });
  }
  
  /// Parse vCard data
  static Map<String, dynamic> parseVCard(String vCardData) {
    final Map<String, dynamic> contact = {};
    
    try {
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
        } else if (line.startsWith('EMAIL:')) {
          contact['email'] = line.substring(6);
        } else if (line.startsWith('ORG:')) {
          contact['org'] = line.substring(4);
        }
      }
    } catch (e) {
      print('🔥 Error parsing vCard: $e');
    }
    
    return contact;
  }
  
  /// Format currency with thousand separators
  static String formatCurrency(String price, {String currency = 'Rp'}) {
    try {
      final number = double.tryParse(price.replaceAll(',', '')) ?? 0;
      final formatted = number.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match.group(1)},',
      );
      return '$currency $formatted';
    } catch (e) {
      return price;
    }
  }
  
  /// Translate system messages
  static String translateSystemMessage(String message) {
    final translations = {
      'Site.Inbox.PaymentPaid': 'Payment Paid',
      'Site.Inbox.PaymentPending': 'Payment Pending',
      'Site.Inbox.StatusPreparing': 'Preparing',
      'Site.Inbox.StatusPayRequest': 'Payment Request',
      'Site.Inbox.StatusShipped': 'Shipped',
      'Site.Inbox.StatusDelivered': 'Delivered',
      'Site.Inbox.StatusCanceled': 'Canceled',
      'Site.Inbox.OrderConfirm': 'Order Confirmed',
      'Site.Inbox.OrderReject': 'Order Rejected',
      'Site.Inbox.DeletedMessage': 'This message was deleted',
      'Site.Inbox.HasAsign': 'Conversation assigned',
      'Site.Inbox.UnmuteBot': 'Bot unmuted',
      'Site.Inbox.MuteBot': 'Bot muted',
      'Site.Inbox.AgentOut': 'Agent left conversation',
      'Site.Inbox.TransferTo': 'Conversation transferred to',
    };
    
    String result = message;
    translations.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    return result;
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
  
  /// Parse JSON safely
  static Map<String, dynamic>? parseJsonSafely(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Generate unique message ID
  static String generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final timestampPart = timestamp.substring(0, 9);
    final randomPart = (100000 + (DateTime.now().microsecond % 900000)).toString();
    return timestampPart + randomPart;
  }
  
  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Check if URL is valid
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }
  
  /// Check if file is video
  static bool isVideo(String filePath) {
    final videoExtensions = RegExp(r'\.(mp4|webm|ogg|avi|mov|wmv|flv)$', caseSensitive: false);
    final urlWithoutQuery = filePath.split('?')[0];
    return videoExtensions.hasMatch(urlWithoutQuery);
  }
  
  /// Get message type display text
  static String getMessageTypeDisplay(int bodyType) {
    switch (bodyType) {
      case 1: return 'Text';
      case 2: return 'Audio';
      case 3: return 'Photo';
      case 4: return 'Video';
      case 5: return 'Document';
      case 7: return 'Sticker';
      case 9: return 'Location';
      case 10: return 'Order';
      case 11: return 'Catalog';
      case 12: return 'Contact';
      case 13: return 'Contacts';
      case 14: return 'Interactive Order';
      case 15: return 'Polling';
      case 16: return 'Unsupported Message';
      case 17: return 'Storage Limit';
      case 18: return 'Channel Limit';
      case 19: return 'Interactive List';
      case 21: return 'Interactive Button';
      case 24: return 'Post';
      case 25: return 'Profile';
      case 26: return 'Sticker not Supported';
      case 27: return 'Template Message';
      default: return 'Unknown';
    }
  }
  
  /// Get emoji for message type
  static String getMessageTypeEmoji(int bodyType) {
    switch (bodyType) {
      case 1: return '💬';
      case 2: return '🔉';
      case 3: return '📷';
      case 4: return '📽';
      case 5: return '📂';
      case 7: return '🌟';
      case 9: return '📍';
      case 10: return '🛒';
      case 11: return '📦';
      case 12: return '👤';
      case 13: return '👥';
      case 14: return '📋';
      case 15: return '📊';
      case 16: return '❌';
      case 17: return '❌';
      case 18: return '❌';
      case 19: return '📝';
      case 21: return '📟';
      case 24: return '🖼';
      case 25: return '👤';
      case 26: return '🌟';
      case 27: return '📃';
      default: return '💬';
    }
  }
  
  /// Clean HTML tags from text
  static String cleanHtmlTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '');
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
  
  /// Extract text from JSON message
  static String extractTextFromJson(String jsonContent) {
    try {
      final jsonData = jsonDecode(jsonContent);
      
      if (jsonData is Map<String, dynamic>) {
        // Try to extract text from various possible fields
        if (jsonData['msg'] != null) {
          final msg = jsonData['msg'].toString();
          return translateSystemMessage(msg);
        }
        if (jsonData['text'] != null) return jsonData['text'].toString();
        if (jsonData['message'] != null) return jsonData['message'].toString();
        if (jsonData['content'] != null) return jsonData['content'].toString();
        if (jsonData['body'] != null) return jsonData['body'].toString();
        if (jsonData['Message'] != null) return jsonData['Message'].toString();
        if (jsonData['Content'] != null) return jsonData['Content'].toString();
      }
      
      return 'Message';
    } catch (e) {
      return jsonContent.length > 30 ? '${jsonContent.substring(0, 30)}...' : jsonContent;
    }
  }
  
  /// Format time for display
  static String formatTimeDisplay(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Format duration for voice messages
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  
  /// Truncate text with ellipsis
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Check if message should show read more
  static bool shouldShowReadMore(String text, {int threshold = 500}) {
    return text.length > threshold;
  }
  
  /// Get short version of long message
  static String getShortMessage(String text, {int maxLength = 500}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Parse interactive message content
  static Map<String, dynamic>? parseInteractiveMessage(String content) {
    try {
      final jsonData = jsonDecode(content);
      if (jsonData is Map<String, dynamic>) {
        return jsonData;
      }
    } catch (e) {
      print('🔥 Error parsing interactive message: $e');
    }
    return null;
  }
  
  /// Format order message content
  static Map<String, dynamic> parseOrderMessage(String content) {
    final parts = content.split('[-{=||=}-]');
    
    return {
      'items': parts.isNotEmpty ? parts[0] : '',
      'currency': parts.length > 1 ? parts[1] : '',
      'amount': parts.length > 2 ? parts[2] : '',
      'description': parts.length > 3 ? parts[3] : '',
      'title': parts.length > 4 ? parts[4] : '',
    };
  }
  
  /// Format location message content
  static Map<String, dynamic> parseLocationMessage(String content) {
    final parts = content.split('[-{=||=}-]');
    
    return {
      'latitude': parts.isNotEmpty ? parts[0] : '',
      'longitude': parts.length > 1 ? parts[1] : '',
      'name': parts.length > 2 ? parts[2] : '',
    };
  }
  
  /// Get Google Maps URL for location
  static String getGoogleMapsUrl(String latitude, String longitude, {String? placeName}) {
    if (placeName != null && placeName.isNotEmpty) {
      return 'https://www.google.com/maps/search/$placeName/@$latitude,$longitude,21z';
    } else {
      return 'https://www.google.com/maps?q=$latitude,$longitude&z=21';
    }
  }
  
  /// Format contact message for display
  static String formatContactMessage(Map<String, dynamic> contactData) {
    final name = contactData['fn'] ?? 'Unknown Contact';
    final phone = contactData['tel']?[0]?['value']?[0] ?? '';
    
    if (phone.isNotEmpty) {
      return '$name\n$phone';
    }
    return name;
  }
  
  /// Check if message is system message
  static bool isSystemMessage(NoboxMessage message) {
    return message.bodyType == 6 || 
           message.content.contains('Site.Inbox.') ||
           message.senderId == 'System' ||
           message.senderId == 'Bot';
  }
  
  /// Get system message display text
  static String getSystemMessageDisplay(NoboxMessage message) {
    if (message.bodyType == 6) {
      try {
        final jsonData = jsonDecode(message.content);
        if (jsonData is Map<String, dynamic>) {
          final msg = jsonData['msg']?.toString() ?? '';
          final userHandle = jsonData['userHandle']?.toString() ?? '';
          final user = jsonData['user']?.toString() ?? '';
          
          String displayText = translateSystemMessage(msg);
          
          // Add user information if available
          if (userHandle.isNotEmpty && userHandle != 'customer') {
            displayText = '$displayText by $userHandle';
          }
          
          if (user.isNotEmpty) {
            displayText = '$displayText to $user';
          }
          
          return displayText;
        }
      } catch (e) {
        print('🔥 Error parsing system message: $e');
      }
    }
    
    return translateSystemMessage(message.content);
  }
  
  /// Format message for notification
  static String formatNotificationText(NoboxMessage message) {
    if (isSystemMessage(message)) {
      return getSystemMessageDisplay(message);
    }
    
    switch (message.bodyType) {
      case 2: return '🔉 Audio message';
      case 3: return '📷 Photo';
      case 4: return '📽 Video';
      case 5: return '📂 Document';
      case 7: return '🌟 Sticker';
      case 9: return '📍 Location';
      case 10: return '🛒 Order';
      case 11: return '📦 Catalog';
      case 12: return '👤 Contact';
      case 13: return '👥 Contacts';
      default:
        return message.content.length > 100 
            ? '${message.content.substring(0, 100)}...'
            : message.content;
    }
  }
}