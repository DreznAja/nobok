import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/message_model.dart';
import '../services/message_formatter.dart';

/// Enhanced notification service for NoBox Chat
class NotificationService {
  static bool _isInitialized = false;
  static final List<ChatNotification> _notifications = [];
  static final StreamController<ChatNotification> _notificationController = 
      StreamController<ChatNotification>.broadcast();
  
  /// Initialize notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔥 🔔 Initializing NotificationService...');
      
      // Initialize platform-specific notifications
      if (!kIsWeb) {
        // Mobile notifications would be initialized here
        // For now, we'll use in-app notifications
      }
      
      _isInitialized = true;
      print('🔥 🔔 ✅ NotificationService initialized');
    } catch (e) {
      print('🔥 Error initializing NotificationService: $e');
    }
  }
  
  /// Show notification for new message
  static Future<void> showMessageNotification({
    required NoboxMessage message,
    required String chatName,
    required String channelName,
  }) async {
    try {
      if (!_isInitialized) await initialize();
      
      final notification = ChatNotification(
        id: message.id,
        title: chatName,
        body: MessageFormatter.formatNotificationText(message),
        channelName: channelName,
        timestamp: message.createdAt,
        isFromCurrentUser: message.isFromMe,
        messageType: message.bodyType,
      );
      
      _notifications.add(notification);
      _notificationController.add(notification);
      
      // Show system notification if app is in background
      if (!kIsWeb) {
        await _showSystemNotification(notification);
      }
      
      // Show in-app notification
      _showInAppNotification(notification);
      
      print('🔥 🔔 Notification shown: ${notification.title}');
    } catch (e) {
      print('🔥 Error showing notification: $e');
    }
  }
  
  /// Show system notification (platform-specific)
  static Future<void> _showSystemNotification(ChatNotification notification) async {
    try {
      // This would integrate with flutter_local_notifications
      // For now, we'll use haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      print('🔥 Error showing system notification: $e');
    }
  }
  
  /// Show in-app notification
  static void _showInAppNotification(ChatNotification notification) {
    // This would show a banner or toast notification
    // Implementation depends on your UI framework
    print('🔔 In-app notification: ${notification.title} - ${notification.body}');
  }
  
  /// Clear notification for specific chat
  static void clearChatNotifications(String chatId) {
    _notifications.removeWhere((notif) => notif.id.contains(chatId));
  }
  
  /// Clear all notifications
  static void clearAllNotifications() {
    _notifications.clear();
  }
  
  /// Get notification stream
  static Stream<ChatNotification> get notificationStream => _notificationController.stream;
  
  /// Get all notifications
  static List<ChatNotification> get notifications => List.unmodifiable(_notifications);
  
  /// Get unread notifications count
  static int get unreadCount => _notifications.where((n) => !n.isRead).length;
  
  /// Mark notification as read
  static void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
    }
  }
  
  /// Dispose service
  static Future<void> dispose() async {
    await _notificationController.close();
    _notifications.clear();
    _isInitialized = false;
    print('🔥 🔔 NotificationService disposed');
  }
}

/// Notification model
class ChatNotification {
  final String id;
  final String title;
  final String body;
  final String channelName;
  final DateTime timestamp;
  final bool isFromCurrentUser;
  final int messageType;
  final bool isRead;
  
  ChatNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.channelName,
    required this.timestamp,
    required this.isFromCurrentUser,
    required this.messageType,
    this.isRead = false,
  });
  
  ChatNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? channelName,
    DateTime? timestamp,
    bool? isFromCurrentUser,
    int? messageType,
    bool? isRead,
  }) {
    return ChatNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      channelName: channelName ?? this.channelName,
      timestamp: timestamp ?? this.timestamp,
      isFromCurrentUser: isFromCurrentUser ?? this.isFromCurrentUser,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
    );
  }
  
  @override
  String toString() {
    return 'ChatNotification{id: $id, title: $title, body: $body, isRead: $isRead}';
  }
}