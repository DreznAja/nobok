import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../utils/last_message_renderer.dart';
import 'user_service.dart';
import 'api_service.dart';

/// Service khusus untuk mengelola message operations dan last message logic
class MessageService {
  
  /// ✅ ENHANCED: Get last message dengan ikon yang tepat
  static Future<LastMessageData?> getLastMessageForChat(
    String chatId,
    int channelId,
    String? linkIdExt,
  ) async {
    try {
      print('🔥 Getting last message for chat: $chatId');
      
      // Ambil messages terbaru
      final response = await ApiService.getMessages(
        linkId: int.tryParse(chatId),
        channelId: channelId,
        linkIdExt: linkIdExt,
        take: 10000, // Ambil cukup untuk memastikan dapat message yang valid
        skip: 0,
        limit: 10000,
        orderBy: 'CreatedAt',
        orderDirection: 'desc', // Newest first
      );
      
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        final allMessages = response.data!;
        
        // Filter messages yang valid
        final validMessages = allMessages.where((message) {
          return LastMessageRenderer.isValidLastMessage(message);
        }).toList();
        
        if (validMessages.isEmpty) {
          return LastMessageData(
            message: null,
            preview: "No messages yet",
            isFromCurrentUser: false,
            unreadCount: 0,
          );
        }
        
        // Sort by creation time descending
        validMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Ambil message terakhir yang valid
        final lastMessage = validMessages.first;
        final isFromCurrentUser = lastMessage.isFromMe || UserService.isMyMessage(lastMessage.senderId);
        
        // Hitung unread count yang akurat
        int unreadCount = 0;
        if (isFromCurrentUser) {
          // Jika last message dari user sendiri, hitung unread dari contact setelah message ini
          unreadCount = validMessages.where((msg) {
            return !msg.isFromMe && 
                   !UserService.isMyMessage(msg.senderId) && 
                   msg.createdAt.isAfter(lastMessage.createdAt) &&
                   msg.ack < 2;
          }).length;
        } else {
          // Jika last message dari contact, hitung semua unread dari contact
          unreadCount = validMessages.where((msg) {
            return !msg.isFromMe && 
                   !UserService.isMyMessage(msg.senderId) && 
                   msg.ack < 2;
          }).length;
        }
        
        // ✅ CRITICAL FIX: Generate preview text dengan ikon yang tepat
        String preview = LastMessageRenderer.renderLastMessage(lastMessage);
        
        // ✅ ENHANCED: Tambahkan prefix "You: " hanya untuk text messages
        if (isFromCurrentUser) {
          // Jika message mengandung ikon (media), jangan tambahkan "You: "
          if (preview.startsWith('📷') || preview.startsWith('📽') || 
              preview.startsWith('🔉') || preview.startsWith('📂')) {
            // Untuk media messages, tampilkan apa adanya
            preview = preview;
          } else {
            // Untuk text messages, tambahkan "You: "
            preview = "You: $preview";
          }
        }
        
        print('🔥 ✅ Found last message: "$preview", unread: $unreadCount, from current user: $isFromCurrentUser');
        
        return LastMessageData(
          message: lastMessage,
          preview: preview,
          isFromCurrentUser: isFromCurrentUser,
          unreadCount: unreadCount,
          timestamp: lastMessage.createdAt,
        );
      }
      
      // No messages found
      return LastMessageData(
        message: null,
        preview: "No messages yet",
        isFromCurrentUser: false,
        unreadCount: 0,
      );
      
    } catch (e) {
      print('🔥 Error getting last message for chat $chatId: $e');
      return LastMessageData(
        message: null,
        preview: "Error loading message",
        isFromCurrentUser: false,
        unreadCount: 0,
      );
    }
  }
  
  /// Get multiple last messages dalam batch untuk efisiensi
  static Future<Map<String, LastMessageData>> getBatchLastMessages(
    List<ChatLinkModel> chatLinks,
    Map<String, ChannelModel> chatChannelMap,
  ) async {
    final Map<String, LastMessageData> results = {};
    
    try {
      print('🔥 Getting batch last messages for ${chatLinks.length} chats');
      
      // Process in parallel batches untuk performance
      const batchSize = 5;
      for (int i = 0; i < chatLinks.length; i += batchSize) {
        final batch = chatLinks.skip(i).take(batchSize).toList();
        
        final futures = batch.map((chatLink) async {
          final channel = chatChannelMap[chatLink.id];
          if (channel != null) {
            final lastMessageData = await getLastMessageForChat(
              chatLink.id,
              channel.id,
              chatLink.idExt.isNotEmpty ? chatLink.idExt : null,
            );
            if (lastMessageData != null) {
              return MapEntry(chatLink.id, lastMessageData);
            }
          }
          return null;
        });
        
        final batchResults = await Future.wait(futures);
        
        for (final result in batchResults) {
          if (result != null) {
            results[result.key] = result.value;
          }
        }
        
        // Small delay between batches
        if (i + batchSize < chatLinks.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      print('🔥 ✅ Batch last messages completed: ${results.length} results');
      
    } catch (e) {
      print('🔥 Error in batch last messages: $e');
    }
    
    return results;
  }
  
  /// Filter messages untuk mendapatkan yang valid saja
  static List<NoboxMessage> filterValidMessages(List<NoboxMessage> messages) {
    return messages.where((message) {
      return LastMessageRenderer.isValidLastMessage(message);
    }).toList();
  }
  
  /// Sort messages by timestamp (newest first)
  static List<NoboxMessage> sortMessagesByTime(List<NoboxMessage> messages, {bool ascending = false}) {
    final sorted = List<NoboxMessage>.from(messages);
    if (ascending) {
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }
}

/// ✅ ENHANCED: Data class untuk menyimpan informasi last message dengan metadata tambahan
class LastMessageData {
  final NoboxMessage? message;
  final String preview;
  final bool isFromCurrentUser;
  final int unreadCount;
  final DateTime? timestamp;
  final MessageTypeInfo? typeInfo;

  LastMessageData({
    required this.message,
    required this.preview,
    required this.isFromCurrentUser,
    required this.unreadCount,
    this.timestamp,
    this.typeInfo,
  });

  /// ✅ NEW: Factory constructor dengan type info
  factory LastMessageData.withTypeInfo({
    required NoboxMessage? message,
    required String preview,
    required bool isFromCurrentUser,
    required int unreadCount,
    DateTime? timestamp,
  }) {
    MessageTypeInfo? typeInfo;
    if (message != null) {
      typeInfo = MessageTypeInfo(
        icon: LastMessageRenderer.getMessageTypeIcon(message),
        color: LastMessageRenderer.getMessageTypeColor(message),
        type: _getMessageTypeName(message),
      );
    }
    
    return LastMessageData(
      message: message,
      preview: preview,
      isFromCurrentUser: isFromCurrentUser,
      unreadCount: unreadCount,
      timestamp: timestamp,
      typeInfo: typeInfo,
    );
  }
  
  static String _getMessageTypeName(NoboxMessage message) {
    switch (message.bodyType) {
      case 2: return 'Audio';
      case 3: return 'Photo';
      case 4: return 'Video';
      case 5: return 'Document';
      case 7: return 'Sticker';
      case 9: return 'Location';
      default: return 'Text';
    }
  }

  @override
  String toString() {
    return 'LastMessageData{preview: "$preview", unread: $unreadCount, isFromCurrentUser: $isFromCurrentUser, timestamp: $timestamp}';
  }
}

/// ✅ NEW: Message type info untuk UI customization
class MessageTypeInfo {
  final IconData icon;
  final Color color;
  final String type;

  MessageTypeInfo({
    required this.icon,
    required this.color,
    required this.type,
  });
}