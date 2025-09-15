import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/message_model.dart';

/// Enhanced Last Message Renderer untuk menampilkan preview pesan terakhir
/// dengan ikon yang sesuai dengan tipe pesan
class LastMessageRenderer {
  /// Main method untuk generate last message display text yang akurat dengan ikon
  static String renderLastMessage(NoboxMessage message) {
    try {
      final content = message.content.trim();
      
          // ✅ FIXED: Enhanced system message detection
    if (content.contains('Site.Inbox.UnmuteBot')) {
      return "🔊 Bot unmuted";
    }
    if (content.contains('Site.Inbox.HasAsign')) {
      return "👤 Conversation assigned";
    }
    if (content.contains('Site.Inbox.MuteBot')) {
      return "🔇 Bot muted";
    }
    if (content.contains('Site.Inbox')) {
      return "⚙️ New message";
    }
    
    // Skip other system messages
    if (content.contains('"msg":"Site.Inbox.HasAsign"') || 
        content.contains('Site.Inbox.HasAsign')) {
      return '[System Message]';
    }
    
    // ✅ FIXED: Enhanced JSON parsing for system messages
    if (_isJsonContent(content)) {
      final extracted = _extractTextFromJson(content);
      if (extracted != content) { // If we successfully extracted something
        return extracted;
      }
    }
      
      // ✅ FIXED: Enhanced media type detection dengan ikon yang tepat
      if (_isImageMessage(message)) {
        return _renderImageMessage(message);
      } else if (_isVideoMessage(message)) {
        return _renderVideoMessage(message);
      } else if (_isAudioMessage(message)) {
        return _renderAudioMessage(message);
      } else if (_isFileMessage(message)) {
        return _renderFileMessage(message);
      }
      
      // Handle berdasarkan body type untuk fallback
      switch (message.bodyType) {
        case 2: // Audio
          return "🔉 Audio";
        case 3: // Image
          return "📷 Photo";
        case 4: // Video
          return "📽 Video";
        case 5: // File/Document
          return "📂 Document";
        case 7: // Sticker
          return "🌟 Sticker";
        case 9: // Location
          return "📍 Location";
        case 10: // Order
          return "🛒 Order";
        case 11: // Catalog
          return "📦 Catalog";
        case 12: // Contact
          return "👤 Contact";
        case 13: // Contact Multi
          return "👥 Contacts";
        case 14: // Interactive Order
          return "📋 Interactive Order";
        case 15: // Polling
          return "📊 Polling";
        case 16: // Unsupported
          return "❌ Unsupported Message";
        case 17: // Storage Limit
          return "❌ Storage Limit";
        case 18: // Channel Limit
          return "❌ Channel Limit";
        case 19: // Interactive List
          return "📝 Interactive List";
        case 21: // Interactive Button
          return "📟 Interactive Button";
        case 24: // Post
          return "🖼 Post";
        case 25: // Profile
          return "👤 Profile";
        case 26: // Sticker Not Supported
          return "🌟 Sticker not Supported";
        case 27: // Template Message
          return "📃 Template Message";
        case 1: // Text
        default:
          return _renderTextMessage(content);
      }
    } catch (e) {
      debugPrint("🔥 Error rendering last message: $e");
      return "[Message error]";
    }
  }
  
// ✅ NEW: Add these helper methods to LastMessageRenderer
static bool _isJsonContent(String content) {
  final trimmed = content.trim();
  return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
         (trimmed.startsWith('[') && trimmed.endsWith(']'));
}

static String _extractTextFromJson(String jsonContent) {
  try {
    final jsonData = json.decode(jsonContent);
    
    if (jsonData is Map<String, dynamic>) {
      // Try to extract text from various possible fields
      if (jsonData['msg'] != null) {
        final msg = jsonData['msg'].toString();
        if (msg.contains('Site.Inbox.UnmuteBot')) return "🔊 Bot unmuted";
        if (msg.contains('Site.Inbox.HasAsign')) return "👤 Assigned";
        if (msg.contains('Site.Inbox.MuteBot')) return "🔇 Bot muted";
        if (msg.contains('Site.Inbox')) return "⚙️ System";
        return msg;
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

  /// ✅ ENHANCED: Image message detection dan rendering
  static bool _isImageMessage(NoboxMessage message) {
    // Check body type first
    if (message.bodyType == 3) return true;
    
    // Check attachment for image extensions
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
      
      // Handle JSON format attachment
      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = (fileData['Filename'] ?? fileData['filename'] ?? '').toString().toLowerCase();
          if (imageExtensions.any((ext) => filename.endsWith(ext))) {
            return true;
          }
        } catch (e) {
          // Continue to other checks
        }
      }
      
      // Direct attachment string check
      if (imageExtensions.any((ext) => attachment.contains(ext))) {
        return true;
      }
    }
    
    // Check content for image indicators
    final contentLower = message.content.toLowerCase();
    return contentLower.contains('📷') || 
           contentLower.contains('image') || 
           contentLower.contains('foto') ||
           contentLower.contains('photo');
  }
  
  /// ✅ ENHANCED: Video message detection dan rendering
  static bool _isVideoMessage(NoboxMessage message) {
    // Check body type first
    if (message.bodyType == 4) return true;
    
    // Check attachment for video extensions
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final videoExtensions = ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.3gp'];
      
      // Handle JSON format attachment
      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = (fileData['Filename'] ?? fileData['filename'] ?? '').toString().toLowerCase();
          if (videoExtensions.any((ext) => filename.endsWith(ext))) {
            return true;
          }
        } catch (e) {
          // Continue to other checks
        }
      }
      
      // Direct attachment string check
      if (videoExtensions.any((ext) => attachment.contains(ext))) {
        return true;
      }
    }
    
    // Check content for video indicators
    final contentLower = message.content.toLowerCase();
    return contentLower.contains('🎥') || 
           contentLower.contains('📽') || 
           contentLower.contains('video');
  }
  
  /// ✅ ENHANCED: Audio message detection dan rendering
  static bool _isAudioMessage(NoboxMessage message) {
    // Check body type first
    if (message.bodyType == 2) return true;
    
    // Check attachment for audio extensions
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final audioExtensions = ['.mp3', '.wav', '.ogg', '.aac', '.m4a', '.flac', '.wma'];
      
      // Handle JSON format attachment
      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = (fileData['Filename'] ?? fileData['filename'] ?? '').toString().toLowerCase();
          if (audioExtensions.any((ext) => filename.endsWith(ext))) {
            return true;
          }
        } catch (e) {
          // Continue to other checks
        }
      }
      
      // Direct attachment string check
      if (audioExtensions.any((ext) => attachment.contains(ext))) {
        return true;
      }
    }
    
    // Check content for audio indicators
    final contentLower = message.content.toLowerCase();
    return contentLower.contains('🎵') || 
           contentLower.contains('🔉') || 
           contentLower.contains('🎤') ||
           contentLower.contains('audio') || 
           contentLower.contains('voice') ||
           contentLower.contains('suara');
  }
  
  /// ✅ ENHANCED: File/Document message detection dan rendering
  static bool _isFileMessage(NoboxMessage message) {
    // Check body type first
    if (message.bodyType == 5) return true;
    
    // Check attachment for file extensions (excluding media files)
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      // If it's already detected as image, video, or audio, it's not a document
      if (_isImageMessage(message) || _isVideoMessage(message) || _isAudioMessage(message)) {
        return false;
      }
      
      final attachment = message.attachment!.toLowerCase();
      final documentExtensions = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.zip', '.rar'];
      
      // Handle JSON format attachment
      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = (fileData['Filename'] ?? fileData['filename'] ?? '').toString().toLowerCase();
          if (documentExtensions.any((ext) => filename.endsWith(ext))) {
            return true;
          }
        } catch (e) {
          // Continue to other checks
        }
      }
      
      // Direct attachment string check
      if (documentExtensions.any((ext) => attachment.contains(ext))) {
        return true;
      }
      
      // If has attachment but not media, assume it's a document
      return true;
    }
    
    // Check content for file indicators
    final contentLower = message.content.toLowerCase();
    return contentLower.contains('📎') || 
           contentLower.contains('📂') || 
           contentLower.contains('📄') ||
           contentLower.contains('file') || 
           contentLower.contains('document') ||
           contentLower.contains('dokumen');
  }
  
  /// ✅ ENHANCED: Render image message dengan ikon dan caption
  static String _renderImageMessage(NoboxMessage message) {
    final content = message.content.trim();
    
    // Jika ada caption yang meaningful (bukan default)
    if (content.isNotEmpty && 
        !content.startsWith('📷') && 
        content.toLowerCase() != 'image' &&
        content.toLowerCase() != 'photo' &&
        content.toLowerCase() != 'foto') {
      return "📷 Photo";
    }
    
    return "📷 Photo";
  }
  
  /// ✅ ENHANCED: Render video message dengan ikon dan caption
  static String _renderVideoMessage(NoboxMessage message) {
    final content = message.content.trim();
    
    // Jika ada caption yang meaningful (bukan default)
    if (content.isNotEmpty && 
        !content.startsWith('🎥') && 
        !content.startsWith('📽') && 
        content.toLowerCase() != 'video') {
      return "📽 Video";
    }
    
    return "📽 Video";
  }
  
  /// ✅ ENHANCED: Render audio message dengan ikon dan info
  static String _renderAudioMessage(NoboxMessage message) {
    final content = message.content.trim();
    
    // Check for voice note indicators
    if (content.toLowerCase().contains('voice') || 
        content.toLowerCase().contains('🎤') ||
        content.toLowerCase().contains('suara')) {
      return "🔉 Audio";
    }
    
    // Check for specific audio content
    if (content.isNotEmpty && 
        !content.startsWith('🎵') && 
        !content.startsWith('🔉') && 
        content.toLowerCase() != 'audio') {
      return "🔉 Audio";
    }
    
    return "🔉 Audio";
  }
  
  /// ✅ ENHANCED: Render file/document message dengan ikon dan info
  static String _renderFileMessage(NoboxMessage message) {
    final content = message.content.trim();
    
    // Try to get filename from attachment
    String filename = "Document";
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      if (message.attachment!.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(message.attachment!);
          final originalName = fileData['OriginalName'] ?? fileData['originalName'];
          final filenameFromJson = fileData['Filename'] ?? fileData['filename'];
          filename = originalName ?? filenameFromJson ?? "Document";
        } catch (e) {
          // Use default
        }
      } else {
        // Use attachment string directly
        filename = message.attachment!.split('/').last;
      }
    }
    
    // Get file extension for better display
    final extension = filename.split('.').last.toUpperCase();
    
    // Return with document icon and file type
    if (extension.isNotEmpty && extension != filename.toUpperCase()) {
      return "📂 Document";
    }
    
    return "📂 Document";
  }
  
  /// Render text message dengan handling JSON content
  static String _renderTextMessage(String content) {
    if (content.isEmpty) return "[Empty message]";
    
    // Coba parse sebagai JSON untuk structured message
    try {
      final jsonData = jsonDecode(content);
      if (jsonData is Map && jsonData.containsKey("Type")) {
        final type = jsonData["Type"].toString();
        switch (type) {
          case "2": return "🔉 Audio";
          case "3": return "📷 Photo";
          case "4": return "📽 Video";
          case "5": return "📂 Document";
          case "7": return "🌟 Sticker";
          case "9": return "📍 Location";
          case "10": return "🛒 Order";
          case "11": return "📦 Catalog";
          case "12": return "👤 Contact";
          case "13": return "👥 Contacts";
          default:
            if (jsonData.containsKey("Msg")) {
              return jsonData["Msg"].toString();
            }
            return "[Structured message]";
        }
      }
    } catch (e) {
      // Bukan JSON, lanjutkan sebagai text biasa
    }
    
    // ✅ ENHANCED: Check for emoji indicators in text content
    if (content.contains('📷') || content.toLowerCase().contains('photo')) {
      return "📷 Photo";
    } else if (content.contains('📽') || content.contains('🎥') || content.toLowerCase().contains('video')) {
      return "📽 Video";
    } else if (content.contains('🔉') || content.contains('🎵') || content.contains('🎤') || content.toLowerCase().contains('audio')) {
      return "🔉 Audio";
    } else if (content.contains('📂') || content.contains('📎') || content.contains('📄')) {
      return "📂 Document";
    }
    
    // Limit text length untuk preview
    if (content.length > 50) {
      return content.substring(0, 50) + "...";
    }
    
    return content;
  }
  
  /// Get last message dari list messages dengan filtering yang benar
  static NoboxMessage? getValidLastMessage(List<NoboxMessage> messages) {
    if (messages.isEmpty) return null;
    
    // Filter out system messages dan empty messages
    final validMessages = messages.where((message) {
      return isValidLastMessage(message);
    }).toList();
    
    if (validMessages.isEmpty) return null;
    
    // Sort by creation time descending (newest first)
    validMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Return the newest valid message
    return validMessages.first;
  }
  
  /// Get formatted last message untuk display di home screen
  static String getFormattedLastMessage(
    List<NoboxMessage> messages, 
    bool isFromCurrentUser
  ) {
    final lastMessage = getValidLastMessage(messages);
    
    if (lastMessage == null) {
      return "No messages yet";
    }
    
    final messagePreview = renderLastMessage(lastMessage);
    
    // Jika pesan dari current user, tambahkan prefix "You: "
    if (isFromCurrentUser) {
      return "You: $messagePreview";
    }
    
    return messagePreview;
  }
  
  /// Check apakah message ini valid untuk dijadikan last message
  static bool isValidLastMessage(NoboxMessage message) {
    // Skip system messages
    if (message.content.contains('"msg":"Site.Inbox.HasAsign"') ||
        message.content.contains('Site.Inbox.HasAsign')) {
      return false;
    }
    
    // Skip empty messages (kecuali yang punya attachment)
    if (message.content.trim().isEmpty && 
        (message.attachment == null || message.attachment!.isEmpty)) {
      return false;
    }
    
    // Skip messages with empty IDs
    if (message.id.isEmpty) {
      return false;
    }
    
    return true;
  }
  
  /// ✅ NEW: Get message type icon untuk UI display
  static IconData getMessageTypeIcon(NoboxMessage message) {
    if (_isImageMessage(message)) {
      return Icons.image;
    } else if (_isVideoMessage(message)) {
      return Icons.videocam;
    } else if (_isAudioMessage(message)) {
      return Icons.audiotrack;
    } else if (_isFileMessage(message)) {
      return Icons.attach_file;
    }
    
    switch (message.bodyType) {
      case 2: return Icons.audiotrack;
      case 3: return Icons.image;
      case 4: return Icons.videocam;
      case 5: return Icons.attach_file;
      case 7: return Icons.emoji_emotions;
      case 9: return Icons.location_on;
      case 10: return Icons.shopping_cart;
      case 11: return Icons.inventory;
      case 12: return Icons.contact_page;
      case 13: return Icons.contacts;
      default: return Icons.message;
    }
  }
  
  /// ✅ NEW: Get message type color untuk UI display
  static Color getMessageTypeColor(NoboxMessage message) {
    if (_isImageMessage(message)) {
      return Colors.green;
    } else if (_isVideoMessage(message)) {
      return Colors.purple;
    } else if (_isAudioMessage(message)) {
      return Colors.orange;
    } else if (_isFileMessage(message)) {
      return Colors.blue;
    }
    
    switch (message.bodyType) {
      case 2: return Colors.orange;
      case 3: return Colors.green;
      case 4: return Colors.purple;
      case 5: return Colors.blue;
      case 7: return Colors.amber;
      case 9: return Colors.red;
      case 10: return Colors.teal;
      case 11: return Colors.indigo;
      case 12: return Colors.cyan;
      case 13: return Colors.pink;
      default: return Colors.grey;
    }
  }
}