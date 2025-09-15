// ✅ FIXED: Enhanced message parsing for better image detection
import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:nobox_mobile/services/user_service.dart';

class NoboxMessage {
  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final int linkId;
  final int channelId;
  final int bodyType;
  final String? accountIds;
  final String? attachment;
  final String? fileName;
  final int ack;
  final String? note;
  final String? replyMsg;
  final String? replyId;
  final String? senderName;
  final bool isIncoming;
  final String? quotedMsg;
  final String? quotedId;

  var body;

  NoboxMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.linkId,
    required this.channelId,
    this.bodyType = 1,
    this.accountIds,
    this.attachment,
    this.fileName,
    this.ack = 0,
    this.note,
    this.replyMsg,
    this.replyId,
    this.senderName,
    this.isIncoming = true,
    this.quotedMsg,
    this.quotedId,
    required int roomId,
  });

  // ✅ FIXED: Enhanced media type detection
  bool get hasFile => bodyType == 5 || _hasAttachmentOfType(['.pdf', '.doc', '.txt', '.zip']);
  
  bool get hasImage => bodyType == 3 || _hasAttachmentOfType(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp']);
  
  bool get hasVideo => bodyType == 4 || _hasAttachmentOfType(['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm']);
  
  bool get hasAudio => bodyType == 2 || _hasAttachmentOfType(['.mp3', '.wav', '.ogg', '.aac', '.m4a']);
  
  bool get hasSticker => bodyType == 7;
  
  bool get hasLocation => bodyType == 9;
  
  bool get hasReply => replyMsg != null && replyMsg!.isNotEmpty;
  
  bool get hasQuoted => quotedMsg != null && quotedMsg!.isNotEmpty;

  // ✅ NEW: Helper method to check attachment type
  bool _hasAttachmentOfType(List<String> extensions) {
    if (attachment == null || attachment!.isEmpty) return false;
    
    String attachmentStr = attachment!.toLowerCase();
    
    // Handle JSON format
    if (attachmentStr.startsWith('{')) {
      try {
        final Map<String, dynamic> fileData = jsonDecode(attachment!);
        final filename = fileData['Filename'] ?? fileData['filename'] ?? '';
        attachmentStr = filename.toString().toLowerCase();
      } catch (e) {
        return false;
      }
    }
    
    return extensions.any((ext) => attachmentStr.endsWith(ext));
  }

  /// ✅ FIXED: Enhanced user detection using UserService
  bool get isFromMe {
    // First check: if isIncoming is explicitly false, it's from me
    if (!isIncoming) return true;
    
    // Second check: compare with current user ID
    final currentUserId = UserService.currentUserId;
    final currentAgentId = UserService.currentAgentId;
    
    if (currentUserId != null && senderId == currentUserId) return true;
    if (currentAgentId != null && senderId == currentAgentId) return true;
    
    // Third check: check against known user identifiers
    if (UserService.isMyMessage(senderId)) return true;
    
    // Fourth check: temporary/failed messages from this session
    if (id.startsWith('temp_') || id.startsWith('failed_')) return true;
    
    // Default: if isIncoming is true and no matches, it's not from me
    return false;
  }

  String get displayName => senderName ?? senderId;

  String get messageTypeDisplay {
    switch (bodyType) {
      case 1: return 'Text';
      case 2: return 'Audio';
      case 3: return 'Image';
      case 4: return 'Video';
      case 5: return 'File';
      case 7: return 'Sticker';
      case 9: return 'Location';
      case 10: return 'Order';
      case 11: return 'Product';
      case 12: return 'VCard';
      case 13: return 'VCard Multi';
      default: return 'Unknown';
    }
  }

  /// ✅ FIXED: Enhanced factory constructor with better attachment parsing
  factory NoboxMessage.fromDetailRoomJson(Map<String, dynamic> json) {
    print('🔥 Parsing DetailRoom JSON: ${json.keys}');
    
    try {
      // Enhanced timestamp parsing
      DateTime createdAt = DateTime.now().toLocal();
      final timeString = json['In']?.toString() ?? 
                        json['TimeMsg']?.toString() ?? 
                        json['CreatedAt']?.toString() ??
                        json['Timestamp']?.toString() ??
                        json['Time']?.toString();
                        
      if (timeString != null && timeString.isNotEmpty && timeString != 'null') {
        try {
          if (timeString.endsWith('Z') || timeString.contains('T')) {
            createdAt = DateTime.parse(timeString).toLocal();
          } else if (timeString.contains('/')) {
            final parts = timeString.split(' ');
            if (parts.length >= 2) {
              final dateParts = parts[0].split('/');
              final timeParts = parts[1].split(':');
              if (dateParts.length == 3 && timeParts.length >= 2) {
                createdAt = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                  timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
                ).toLocal();
              }
            }
          } else {
            final timestamp = int.tryParse(timeString);
            if (timestamp != null) {
              if (timestamp.toString().length == 13) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
              } else if (timestamp.toString().length == 10) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toLocal();
              }
            }
          }
        } catch (e) {
          print('🔥 Error parsing timestamp: $timeString, using current time');
          createdAt = DateTime.now().toLocal();
        }
      }

      // Enhanced user detection logic
      String senderId = 'Unknown';
      bool isIncoming = true;
      String? senderName;
      
      final currentUserId = UserService.currentUserId;
      final currentAgentId = UserService.currentAgentId;
      final currentUserName = UserService.currentUserName;
      
      final agentId = json['AgentId'];
      final fromId = json['From']?.toString() ?? json['SenderId']?.toString();
      final isNobox = json['IsNobox'];
      final senderMsg = json['SdrMsg']?.toString();
      final direction = json['Direction']?.toString();
      final isIncomingField = json['IsIncoming'];
      final senderNameField = json['SenderName']?.toString() ?? json['FromName']?.toString();

      if (direction == 'Outgoing' || 
          isIncomingField == false || 
          senderMsg == 'me') {
        senderId = currentUserId ?? currentAgentId ?? 'me';
        senderName = currentUserName ?? 'Me';
        isIncoming = false;
      } else if (agentId != null && agentId != 0) {
        senderId = agentId.toString();
        senderName = senderNameField ?? 'Agent';
        isIncoming = !(currentAgentId == agentId.toString() || currentUserId == agentId.toString());
      } else if (isNobox == 1 || isNobox == true) {
        senderId = 'System';
        senderName = 'System';
        isIncoming = false;
      } else if (fromId != null && fromId.isNotEmpty) {
        senderId = fromId;
        senderName = senderNameField ?? fromId;
        isIncoming = !(UserService.isMyMessage(senderId));
      } else {
        senderId = 'Contact';
        senderName = senderNameField ?? 'Contact';
        isIncoming = true;
      }

      // Parse content and other fields
      String content = json['Msg']?.toString() ?? 
                      json['Body']?.toString() ?? 
                      json['Content']?.toString() ?? 
                      json['Message']?.toString() ?? 
                      json['Text']?.toString() ?? '';
      
      int bodyType = 1;
      final typeString = json['Type']?.toString() ?? 
                        json['BodyType']?.toString() ?? 
                        json['MsgType']?.toString();
      if (typeString != null && typeString.isNotEmpty && typeString != 'null') {
        bodyType = int.tryParse(typeString) ?? 1;
      }

      // ✅ FIXED: Enhanced attachment parsing
      String? attachment;
      String? fileName;
      final files = json['Files'];
      final file = json['File'];
      final attachmentField = json['Attachment'];
      final media = json['Media'];
      final fileNameField = json['FileName']?.toString() ?? json['Filename']?.toString();
      
      // Priority: File > Files > Attachment > Media
      if (file != null && file.toString().isNotEmpty && file != 'null') {
        attachment = file.toString();
        fileName = fileNameField ?? 'Attachment';
        
        // Auto-detect bodyType from attachment if not set correctly
        if (bodyType == 1) {
          bodyType = _detectBodyTypeFromAttachment(attachment);
        }
      } else if (files != null && files.toString().isNotEmpty && files != 'null') {
        attachment = files.toString();
        fileName = fileNameField ?? 'Attachment';
        
        if (bodyType == 1) {
          bodyType = _detectBodyTypeFromAttachment(attachment);
        }
      } else if (attachmentField != null && attachmentField.toString().isNotEmpty && attachmentField != 'null') {
        attachment = attachmentField.toString();
        fileName = fileNameField ?? 'Attachment';
        
        if (bodyType == 1) {
          bodyType = _detectBodyTypeFromAttachment(attachment);
        }
      } else if (media != null && media.toString().isNotEmpty && media != 'null') {
        attachment = media.toString();
        fileName = fileNameField ?? 'Media';
        
        if (bodyType == 1) {
          bodyType = 3; // Assume image for media
        }
      }

      // Parse reply/quoted messages
      String? replyMsg = json['ReplyMsg']?.toString() ?? json['QuotedMsg']?.toString();
      String? replyId = json['ReplyId']?.toString() ?? json['QuotedId']?.toString();
      String? quotedMsg = json['QuotedMsg']?.toString();
      String? quotedId = json['QuotedId']?.toString();

      final message = NoboxMessage(
        id: json['Id']?.toString() ?? 
            json['MsgId']?.toString() ?? 
            DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        linkId: int.tryParse(json['To']?.toString() ?? 
                           json['CtId']?.toString() ?? 
                           json['LinkId']?.toString() ?? '0') ?? 0,
        channelId: int.tryParse(json['ChId']?.toString() ?? 
                              json['ChannelId']?.toString() ?? '0') ?? 0,
        bodyType: bodyType,
        accountIds: json['AccountIds']?.toString(),
        attachment: attachment,
        fileName: fileName,
        ack: int.tryParse(json['Ack']?.toString() ?? 
                         json['Status']?.toString() ?? '0') ?? 0,
        note: json['Note']?.toString() ?? json['Notes']?.toString(),
        replyMsg: replyMsg,
        replyId: replyId,
        senderName: senderName,
        isIncoming: isIncoming,
        quotedMsg: quotedMsg,
        quotedId: quotedId,
        roomId: 0,
      );

      print('🔥 ✅ Parsed DetailRoom message: ID=${message.id}, BodyType=${message.bodyType}, Attachment=${message.attachment}');
      return message;
    } catch (e) {
      print('🔥 Error parsing DetailRoom message: $e');
      return NoboxMessage(
        id: json['Id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'Unknown',
        content: json['Msg']?.toString() ?? 
                json['Body']?.toString() ?? 
                json['Content']?.toString() ?? 
                'Failed to parse message',
        createdAt: DateTime.now().toLocal(),
        linkId: 0,
        channelId: 0,
        bodyType: 1,
        isIncoming: true,
        roomId: 0,
      );
    }
  }

  /// ✅ FIXED: Enhanced factory constructor for Messages endpoint
  factory NoboxMessage.fromMessagesJson(Map<String, dynamic> json) {
    print('🔥 Parsing Messages JSON: ${json.keys}');
    
    try {
      // Enhanced timestamp parsing
      DateTime createdAt = DateTime.now().toLocal();
      final timeString = json['CreatedAt']?.toString() ?? 
                        json['In']?.toString() ?? 
                        json['TimeMsg']?.toString() ??
                        json['Timestamp']?.toString() ??
                        json['Time']?.toString();
                        
      if (timeString != null && timeString.isNotEmpty && timeString != 'null') {
        try {
          if (timeString.endsWith('Z') || timeString.contains('T')) {
            createdAt = DateTime.parse(timeString).toLocal();
          } else {
            final timestamp = int.tryParse(timeString);
            if (timestamp != null) {
              if (timestamp.toString().length == 13) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal();
              } else if (timestamp.toString().length == 10) {
                createdAt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toLocal();
              }
            }
          }
        } catch (e) {
          print('🔥 Error parsing timestamp: $timeString, using current time');
          createdAt = DateTime.now().toLocal();
        }
      }

      // Enhanced user detection using UserService
      String senderId = 'Unknown';
      bool isIncoming = true;
      String? senderName;
      
      final currentUserId = UserService.currentUserId;
      final currentAgentId = UserService.currentAgentId;
      final currentUserName = UserService.currentUserName;
      
      final fromId = json['From']?.toString();
      final senderId_field = json['SenderId']?.toString();
      final agentId = json['AgentId']?.toString();
      final accountId = json['AccountId']?.toString();
      final direction = json['Direction']?.toString();
      final isIncomingField = json['IsIncoming'];
      final senderNameField = json['SenderName']?.toString() ?? json['FromName']?.toString();
      
      if (direction == 'Outgoing' || isIncomingField == false) {
        senderId = currentUserId ?? currentAgentId ?? 'me';
        senderName = currentUserName ?? 'Me';
        isIncoming = false;
      } else if (agentId != null && agentId.isNotEmpty && agentId != '0') {
        senderId = agentId;
        senderName = senderNameField ?? 'Agent';
        isIncoming = !(currentAgentId == agentId || currentUserId == agentId);
      } else if (fromId != null && fromId.isNotEmpty) {
        senderId = fromId;
        senderName = senderNameField ?? fromId;
        isIncoming = !UserService.isMyMessage(fromId);
      } else if (senderId_field != null && senderId_field.isNotEmpty) {
        senderId = senderId_field;
        senderName = senderNameField ?? senderId_field;
        isIncoming = !UserService.isMyMessage(senderId_field);
      } else {
        senderId = senderNameField ?? 'Contact';
        senderName = senderNameField ?? 'Contact';
        isIncoming = true;
      }

      // Parse message content and other fields
      String content = json['Content']?.toString() ?? 
                      json['Body']?.toString() ?? 
                      json['Msg']?.toString() ?? 
                      json['Message']?.toString() ??
                      json['Text']?.toString() ?? '';
      
      int bodyType = 1;
      final typeString = json['Type']?.toString() ?? 
                        json['BodyType']?.toString() ?? 
                        json['MsgType']?.toString();
      if (typeString != null && typeString.isNotEmpty && typeString != 'null') {
        bodyType = int.tryParse(typeString) ?? 1;
      }

      // ✅ FIXED: Enhanced attachment parsing
      String? attachment;
      String? fileName;
      final attachmentData = json['Attachment'];
      final fileData = json['File'];
      final mediaData = json['Media'];
      final fileNameField = json['FileName']?.toString() ?? json['Filename']?.toString();
      
      if (attachmentData != null && attachmentData.toString().isNotEmpty && attachmentData != 'null') {
        attachment = attachmentData.toString();
        fileName = fileNameField ?? 'Attachment';
        
        if (bodyType == 1) {
          bodyType = _detectBodyTypeFromAttachment(attachment);
        }
      } else if (fileData != null && fileData.toString().isNotEmpty && fileData != 'null') {
        attachment = fileData.toString();
        fileName = fileNameField ?? 'Attachment';
        
        if (bodyType == 1) {
          bodyType = _detectBodyTypeFromAttachment(attachment);
        }
      } else if (mediaData != null && mediaData.toString().isNotEmpty && mediaData != 'null') {
        attachment = mediaData.toString();
        fileName = fileNameField ?? 'Media';
        
        if (bodyType == 1) {
          bodyType = 3; // Assume image
        }
      }

      // Parse reply/quoted messages
      String? replyMsg = json['ReplyMsg']?.toString() ?? json['QuotedMsg']?.toString();
      String? replyId = json['ReplyId']?.toString() ?? json['QuotedId']?.toString();
      String? quotedMsg = json['QuotedMsg']?.toString();
      String? quotedId = json['QuotedId']?.toString();

      final message = NoboxMessage(
        id: json['Id']?.toString() ?? 
            json['MsgId']?.toString() ?? 
            DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        linkId: int.tryParse(json['LinkId']?.toString() ?? 
                           json['RoomId']?.toString() ?? 
                           json['CtId']?.toString() ?? '0') ?? 0,
        channelId: int.tryParse(json['ChannelId']?.toString() ?? 
                              json['ChId']?.toString() ?? '0') ?? 0,
        bodyType: bodyType,
        accountIds: json['AccountIds']?.toString(),
        attachment: attachment,
        fileName: fileName,
        ack: int.tryParse(json['Ack']?.toString() ?? 
                         json['Status']?.toString() ?? '0') ?? 0,
        note: json['Note']?.toString() ?? json['Notes']?.toString(),
        replyMsg: replyMsg,
        replyId: replyId,
        senderName: senderName,
        isIncoming: isIncoming,
        quotedMsg: quotedMsg,
        quotedId: quotedId,
        roomId: 0,
      );

      print('🔥 ✅ Parsed Messages message: ID=${message.id}, BodyType=${message.bodyType}, Attachment=${message.attachment}');
      return message;

    } catch (e) {
      print('🔥 Error parsing Messages message: $e');
      return NoboxMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'Unknown',
        content: 'Error parsing message',
        createdAt: DateTime.now().toLocal(),
        linkId: 0,
        channelId: 0,
        isIncoming: true,
        roomId: 0,
      );
    }
  }

  // ✅ NEW: Helper method to detect body type from attachment
  static int _detectBodyTypeFromAttachment(String attachment) {
    if (attachment.isEmpty) return 1;
    
    String attachmentStr = attachment.toLowerCase();
    
    // Handle JSON format
    if (attachmentStr.startsWith('{')) {
      try {
        final Map<String, dynamic> fileData = jsonDecode(attachment);
        final filename = fileData['Filename'] ?? fileData['filename'] ?? '';
        attachmentStr = filename.toString().toLowerCase();
      } catch (e) {
        return 5; // Default to file
      }
    }
    
    // Image extensions
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].any((ext) => attachmentStr.endsWith(ext))) {
      return 3;
    }
    
    // Video extensions
    if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv'].any((ext) => attachmentStr.endsWith(ext))) {
      return 4;
    }
    
    // Audio extensions
    if (['.mp3', '.wav', '.ogg', '.aac', '.m4a', '.flac'].any((ext) => attachmentStr.endsWith(ext))) {
      return 2;
    }
    
    // Default to file
    return 5;
  }

  /// Legacy factory constructor (keep for compatibility)
  factory NoboxMessage.fromBackendJson(Map<String, dynamic> json) {
    return NoboxMessage.fromDetailRoomJson(json);
  }

  /// Convert to JSON untuk kirim ke API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'Body': content,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'linkId': linkId,
      'channelId': channelId,
      'bodyType': bodyType,
      'AccountIds': accountIds,
      'attachment': attachment,
      'fileName': fileName,
      'ack': ack,
      'note': note,
      'replyMsg': replyMsg,
      'replyId': replyId,
      'senderName': senderName,
      'isIncoming': isIncoming,
      'quotedMsg': quotedMsg,
      'quotedId': quotedId,
    };
  }

  /// Convert ke format yang dibutuhkan backend untuk sending
  Map<String, dynamic> toNoboxBackend() {
    final Map<String, dynamic> data = {
      'ChannelId': channelId,
      'BodyType': bodyType,
      'Body': content,
    };

    if (linkId > 0) {
      data['LinkId'] = linkId;
    }

    if (attachment != null && attachment!.isNotEmpty) {
      data['Attachment'] = attachment;
    }

    if (replyId != null && replyId!.isNotEmpty) {
      data['ReplyId'] = replyId;
    }

    return data;
  }

  /// Copy with method untuk update message
  NoboxMessage copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? createdAt,
    int? linkId,
    int? channelId,
    int? bodyType,
    String? attachment,
    String? fileName,
    int? ack,
    String? note,
    String? replyMsg,
    String? replyId,
    String? senderName,
    bool? isIncoming,
    String? quotedMsg,
    String? quotedId,
  }) {
    return NoboxMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      linkId: linkId ?? this.linkId,
      channelId: channelId ?? this.channelId,
      bodyType: bodyType ?? this.bodyType,
      attachment: attachment ?? this.attachment,
      fileName: fileName ?? this.fileName,
      ack: ack ?? this.ack,
      note: note ?? this.note,
      replyMsg: replyMsg ?? this.replyMsg,
      replyId: replyId ?? this.replyId,
      senderName: senderName ?? this.senderName,
      isIncoming: isIncoming ?? this.isIncoming,
      quotedMsg: quotedMsg ?? this.quotedMsg,
      quotedId: quotedId ?? this.quotedId,
      roomId: 0,
    );
  }

  @override
  String toString() {
    return 'NoboxMessage{id: $id, senderId: $senderId, content: $content, createdAt: $createdAt, bodyType: $bodyType, isIncoming: $isIncoming, isFromMe: $isFromMe, attachment: $attachment}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoboxMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  get file => null;

  static empty() {}
}

// Helper class untuk message types
class MessageType {
  static const int text = 1;
  static const int audio = 2;
  static const int image = 3;
  static const int video = 4;
  static const int file = 5;
  static const int sticker = 7;
  static const int location = 9;
  static const int order = 10;
  static const int product = 11;
  static const int vcard = 12;
  static const int vcardMulti = 13;

  static String getTypeName(int type) {
    switch (type) {
      case text: return 'Text';
      case audio: return 'Audio';
      case image: return 'Image';
      case video: return 'Video';
      case file: return 'File';
      case sticker: return 'Sticker';
      case location: return 'Location';
      case order: return 'Order';
      case product: return 'Product';
      case vcard: return 'VCard';
      case vcardMulti: return 'VCard Multi';
      default: return 'Unknown';
    }
  }

  static IconData getTypeIcon(int type) {
    switch (type) {
      case text: return Icons.message;
      case audio: return Icons.audiotrack;
      case image: return Icons.image;
      case video: return Icons.videocam;
      case file: return Icons.attach_file;
      case sticker: return Icons.emoji_emotions;
      case location: return Icons.location_on;
      case order: return Icons.shopping_cart;
      case product: return Icons.inventory;
      case vcard: return Icons.contact_page;
      case vcardMulti: return Icons.contacts;
      default: return Icons.help_outline;
    }
  }

  static bool isMediaType(int type) {
    return type == image || type == video || type == audio;
  }

  static bool isFileType(int type) {
    return type == file;
  }

  static bool isTextType(int type) {
    return type == text;
  }
}

extension NoboxMessageExtensions on NoboxMessage {
  /// Generate unique key untuk deduplikasi
  String get deduplicationKey {
    final timeKey = (createdAt.millisecondsSinceEpoch / 1000).floor();
    return '${senderId}_${content.hashCode}_$timeKey';
  }
  
  /// Check apakah ini pesan temporary
  bool get isTemporary => id.startsWith('temp_');
  
  /// Check apakah ini pesan failed
  bool get isFailed => id.startsWith('failed_');
  
  /// Check apakah pesan ini sama dengan pesan lain (untuk dedup)
  bool isSameMessageAs(NoboxMessage other) {
    if (content != other.content || senderId != other.senderId) {
      return false;
    }
    
    final timeDiff = createdAt.difference(other.createdAt).inSeconds.abs();
    if (timeDiff > 10) {
      return false;
    }
    
    return true;
  }
}