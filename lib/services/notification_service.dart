import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/chat_models.dart';
import '../utils/debug_utils.dart';

/// Service for handling push notifications and in-app notifications
class NotificationService {
  static final List<ChatNotification> _notifications = [];
  static final StreamController<ChatNotification> _notificationController = 
      StreamController<ChatNotification>.broadcast();
  
  static Function(ChatNotification)? onNotificationReceived;
  static Function(String)? onNotificationTapped;
  
  /// Initialize notification service
  static Future<void> initialize() async {
    try {
      DebugUtils.log('Initializing NotificationService...');
      
      // Setup notification listeners
      _setupNotificationListeners();
      
      DebugUtils.log('NotificationService initialized successfully');
    } catch (e) {
      DebugUtils.log('Error initializing NotificationService: $e', category: 'ERROR');
      rethrow;
    }
  }

  /// Setup notification listeners
  static void _setupNotificationListeners() {
    _notificationController.stream.listen((notification) {
      _notifications.add(notification);
      onNotificationReceived?.call(notification);
      
      // Keep only recent notifications (last 100)
      if (_notifications.length > 100) {
        _notifications.removeAt(0);
      }
    });
  }

  /// Show local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? chatId,
    NotificationType type = NotificationType.message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = ChatNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: chatId ?? '',
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        data: data,
      );

      _notificationController.add(notification);
      
      // Trigger haptic feedback for important notifications
      if (type == NotificationType.mention || type == NotificationType.assignment) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      
      DebugUtils.log('Notification shown: $title', category: 'NOTIFICATION');
    } catch (e) {
      DebugUtils.log('Error showing notification: $e', category: 'ERROR');
    }
  }

  /// Show message notification
  static Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String messageContent,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: senderName,
      body: messageContent,
      chatId: chatId,
      type: NotificationType.message,
      data: data,
    );
  }

  /// Show mention notification
  static Future<void> showMentionNotification({
    required String chatId,
    required String senderName,
    required String messageContent,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: 'You were mentioned',
      body: '$senderName: $messageContent',
      chatId: chatId,
      type: NotificationType.mention,
      data: data,
    );
  }

  /// Show assignment notification
  static Future<void> showAssignmentNotification({
    required String chatId,
    required String assignerName,
    required String assigneeName,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: 'Chat Assigned',
      body: '$assignerName assigned chat to $assigneeName',
      chatId: chatId,
      type: NotificationType.assignment,
      data: data,
    );
  }

  /// Show system notification
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String? chatId,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: title,
      body: body,
      chatId: chatId,
      type: NotificationType.system,
      data: data,
    );
  }

  /// Mark notification as read
  static void markAsRead(String notificationId) {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        // In a real implementation, you would update the notification in the backend
        DebugUtils.log('Notification marked as read: $notificationId');
      }
    } catch (e) {
      DebugUtils.log('Error marking notification as read: $e', category: 'ERROR');
    }
  }

  /// Mark all notifications as read for a chat
  static void markChatNotificationsAsRead(String chatId) {
    try {
      final chatNotifications = _notifications.where((n) => n.chatId == chatId);
      for (final notification in chatNotifications) {
        markAsRead(notification.id);
      }
      DebugUtils.log('All notifications marked as read for chat: $chatId');
    } catch (e) {
      DebugUtils.log('Error marking chat notifications as read: $e', category: 'ERROR');
    }
  }

  /// Get unread notifications
  static List<ChatNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Get notifications for a specific chat
  static List<ChatNotification> getChatNotifications(String chatId) {
    return _notifications.where((n) => n.chatId == chatId).toList();
  }

  /// Get notification count for a chat
  static int getChatNotificationCount(String chatId) {
    return _notifications.where((n) => n.chatId == chatId && !n.isRead).length;
  }

  /// Clear all notifications
  static void clearAllNotifications() {
    _notifications.clear();
    DebugUtils.log('All notifications cleared');
  }

  /// Clear notifications for a specific chat
  static void clearChatNotifications(String chatId) {
    _notifications.removeWhere((n) => n.chatId == chatId);
    DebugUtils.log('Notifications cleared for chat: $chatId');
  }

  /// Get notification stream
  static Stream<ChatNotification> get notificationStream => _notificationController.stream;

  /// Request notification permissions
  static Future<bool> requestPermissions() async {
    try {
      // In a real implementation, you would request actual notification permissions
      DebugUtils.log('Notification permissions requested');
      return true;
    } catch (e) {
      DebugUtils.log('Error requesting notification permissions: $e', category: 'ERROR');
      return false;
    }
  }

  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    try {
      // In a real implementation, you would check actual notification settings
      return true;
    } catch (e) {
      DebugUtils.log('Error checking notification status: $e', category: 'ERROR');
      return false;
    }
  }

  /// Dispose notification service
  static void dispose() {
    try {
      _notificationController.close();
      _notifications.clear();
      DebugUtils.log('NotificationService disposed');
    } catch (e) {
      DebugUtils.log('Error disposing NotificationService: $e', category: 'ERROR');
    }
  }

  /// Get notification statistics
  static Map<String, dynamic> getStatistics() {
    final unreadCount = getUnreadNotifications().length;
    final totalCount = _notifications.length;
    final typeBreakdown = <String, int>{};
    
    for (final notification in _notifications) {
      final typeName = notification.type.displayName;
      typeBreakdown[typeName] = (typeBreakdown[typeName] ?? 0) + 1;
    }
    
    return {
      'totalNotifications': totalCount,
      'unreadNotifications': unreadCount,
      'typeBreakdown': typeBreakdown,
      'lastNotification': _notifications.isNotEmpty 
        ? _notifications.last.createdAt.toIso8601String()
        : null,
    };
  }
}