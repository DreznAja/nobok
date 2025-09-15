import 'package:flutter/material.dart';

/// Enhanced model for chat conversations with better structure
class ChatConversation {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final ChatType type;
  final ChatStatus status;
  final DateTime createdAt;
  final DateTime? lastActivity;
  final int unreadCount;
  final bool isArchived;
  final bool isPinned;
  final bool isMuted;
  final List<String> participantIds;
  final Map<String, dynamic>? metadata;

  ChatConversation({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    required this.type,
    required this.status,
    required this.createdAt,
    this.lastActivity,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isPinned = false,
    this.isMuted = false,
    this.participantIds = const [],
    this.metadata,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
      description: json['Description']?.toString(),
      avatar: json['Avatar']?.toString(),
      type: ChatType.fromValue(json['IsGrp'] == 1 ? 'group' : 'private'),
      status: ChatStatus.fromValue(json['St'] ?? 1),
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      lastActivity: DateTime.tryParse(json['LastActivity']?.toString() ?? ''),
      unreadCount: int.tryParse(json['UnreadCount']?.toString() ?? '0') ?? 0,
      isArchived: json['IsArchived'] == true,
      isPinned: json['IsPinned'] == true || json['IsPin'] == 2,
      isMuted: json['IsMuted'] == true,
      participantIds: (json['ParticipantIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      metadata: json['Metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Description': description,
      'Avatar': avatar,
      'Type': type.value,
      'Status': status.value,
      'CreatedAt': createdAt.toIso8601String(),
      'LastActivity': lastActivity?.toIso8601String(),
      'UnreadCount': unreadCount,
      'IsArchived': isArchived,
      'IsPinned': isPinned,
      'IsMuted': isMuted,
      'ParticipantIds': participantIds,
      'Metadata': metadata,
    };
  }

  ChatConversation copyWith({
    String? id,
    String? name,
    String? description,
    String? avatar,
    ChatType? type,
    ChatStatus? status,
    DateTime? createdAt,
    DateTime? lastActivity,
    int? unreadCount,
    bool? isArchived,
    bool? isPinned,
    bool? isMuted,
    List<String>? participantIds,
    Map<String, dynamic>? metadata,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      participantIds: participantIds ?? this.participantIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'ChatConversation{id: $id, name: $name, type: $type, status: $status, unreadCount: $unreadCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatConversation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Enum for chat types
enum ChatType {
  private('private'),
  group('group');

  const ChatType(this.value);
  final String value;

  static ChatType fromValue(String value) {
    return ChatType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => ChatType.private,
    );
  }

  String get displayName {
    switch (this) {
      case ChatType.private:
        return 'Private';
      case ChatType.group:
        return 'Group';
    }
  }

  IconData get icon {
    switch (this) {
      case ChatType.private:
        return Icons.person;
      case ChatType.group:
        return Icons.group;
    }
  }
}

/// Enum for chat status
enum ChatStatus {
  unassigned(1),
  assigned(2),
  resolved(3),
  archived(4);

  const ChatStatus(this.value);
  final int value;

  static ChatStatus fromValue(int value) {
    return ChatStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ChatStatus.unassigned,
    );
  }

  String get displayName {
    switch (this) {
      case ChatStatus.unassigned:
        return 'Unassigned';
      case ChatStatus.assigned:
        return 'Assigned';
      case ChatStatus.resolved:
        return 'Resolved';
      case ChatStatus.archived:
        return 'Archived';
    }
  }

  Color get color {
    switch (this) {
      case ChatStatus.unassigned:
        return Colors.red;
      case ChatStatus.assigned:
        return Colors.blue;
      case ChatStatus.resolved:
        return Colors.green;
      case ChatStatus.archived:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case ChatStatus.unassigned:
        return Icons.help_outline;
      case ChatStatus.assigned:
        return Icons.person;
      case ChatStatus.resolved:
        return Icons.check_circle;
      case ChatStatus.archived:
        return Icons.archive;
    }
  }
}

/// Model for chat participants
class ChatParticipant {
  final String id;
  final String name;
  final String? avatar;
  final String? email;
  final String? phone;
  final ParticipantRole role;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatParticipant({
    required this.id,
    required this.name,
    this.avatar,
    this.email,
    this.phone,
    required this.role,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      avatar: json['Avatar']?.toString(),
      email: json['Email']?.toString(),
      phone: json['Phone']?.toString(),
      role: ParticipantRole.fromValue(json['Role']?.toString() ?? 'member'),
      isOnline: json['IsOnline'] == true,
      lastSeen: DateTime.tryParse(json['LastSeen']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Avatar': avatar,
      'Email': email,
      'Phone': phone,
      'Role': role.value,
      'IsOnline': isOnline,
      'LastSeen': lastSeen?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ChatParticipant{id: $id, name: $name, role: $role, isOnline: $isOnline}';
  }
}

/// Enum for participant roles
enum ParticipantRole {
  owner('owner'),
  admin('admin'),
  moderator('moderator'),
  member('member'),
  guest('guest');

  const ParticipantRole(this.value);
  final String value;

  static ParticipantRole fromValue(String value) {
    return ParticipantRole.values.firstWhere(
      (role) => role.value == value.toLowerCase(),
      orElse: () => ParticipantRole.member,
    );
  }

  String get displayName {
    switch (this) {
      case ParticipantRole.owner:
        return 'Owner';
      case ParticipantRole.admin:
        return 'Admin';
      case ParticipantRole.moderator:
        return 'Moderator';
      case ParticipantRole.member:
        return 'Member';
      case ParticipantRole.guest:
        return 'Guest';
    }
  }

  bool get canManageChat {
    return this == ParticipantRole.owner || this == ParticipantRole.admin;
  }

  bool get canModerate {
    return canManageChat || this == ParticipantRole.moderator;
  }
}

/// Model for chat settings
class ChatSettings {
  final bool allowFileSharing;
  final bool allowVoiceMessages;
  final bool allowVideoMessages;
  final bool allowLocationSharing;
  final bool allowContactSharing;
  final bool enableReadReceipts;
  final bool enableTypingIndicators;
  final int maxFileSize; // in bytes
  final List<String> allowedFileTypes;
  final Map<String, dynamic>? customSettings;

  ChatSettings({
    this.allowFileSharing = true,
    this.allowVoiceMessages = true,
    this.allowVideoMessages = true,
    this.allowLocationSharing = true,
    this.allowContactSharing = true,
    this.enableReadReceipts = true,
    this.enableTypingIndicators = true,
    this.maxFileSize = 50 * 1024 * 1024, // 50MB default
    this.allowedFileTypes = const [],
    this.customSettings,
  });

  factory ChatSettings.fromJson(Map<String, dynamic> json) {
    return ChatSettings(
      allowFileSharing: json['AllowFileSharing'] ?? true,
      allowVoiceMessages: json['AllowVoiceMessages'] ?? true,
      allowVideoMessages: json['AllowVideoMessages'] ?? true,
      allowLocationSharing: json['AllowLocationSharing'] ?? true,
      allowContactSharing: json['AllowContactSharing'] ?? true,
      enableReadReceipts: json['EnableReadReceipts'] ?? true,
      enableTypingIndicators: json['EnableTypingIndicators'] ?? true,
      maxFileSize: json['MaxFileSize'] ?? 50 * 1024 * 1024,
      allowedFileTypes: (json['AllowedFileTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      customSettings: json['CustomSettings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AllowFileSharing': allowFileSharing,
      'AllowVoiceMessages': allowVoiceMessages,
      'AllowVideoMessages': allowVideoMessages,
      'AllowLocationSharing': allowLocationSharing,
      'AllowContactSharing': allowContactSharing,
      'EnableReadReceipts': enableReadReceipts,
      'EnableTypingIndicators': enableTypingIndicators,
      'MaxFileSize': maxFileSize,
      'AllowedFileTypes': allowedFileTypes,
      'CustomSettings': customSettings,
    };
  }

  ChatSettings copyWith({
    bool? allowFileSharing,
    bool? allowVoiceMessages,
    bool? allowVideoMessages,
    bool? allowLocationSharing,
    bool? allowContactSharing,
    bool? enableReadReceipts,
    bool? enableTypingIndicators,
    int? maxFileSize,
    List<String>? allowedFileTypes,
    Map<String, dynamic>? customSettings,
  }) {
    return ChatSettings(
      allowFileSharing: allowFileSharing ?? this.allowFileSharing,
      allowVoiceMessages: allowVoiceMessages ?? this.allowVoiceMessages,
      allowVideoMessages: allowVideoMessages ?? this.allowVideoMessages,
      allowLocationSharing: allowLocationSharing ?? this.allowLocationSharing,
      allowContactSharing: allowContactSharing ?? this.allowContactSharing,
      enableReadReceipts: enableReadReceipts ?? this.enableReadReceipts,
      enableTypingIndicators: enableTypingIndicators ?? this.enableTypingIndicators,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      allowedFileTypes: allowedFileTypes ?? this.allowedFileTypes,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Model for typing indicators
class TypingIndicator {
  final String chatId;
  final String userId;
  final String userName;
  final DateTime timestamp;

  TypingIndicator({
    required this.chatId,
    required this.userId,
    required this.userName,
    required this.timestamp,
  });

  factory TypingIndicator.fromJson(Map<String, dynamic> json) {
    return TypingIndicator(
      chatId: json['ChatId']?.toString() ?? '',
      userId: json['UserId']?.toString() ?? '',
      userName: json['UserName']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['Timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ChatId': chatId,
      'UserId': userId,
      'UserName': userName,
      'Timestamp': timestamp.toIso8601String(),
    };
  }

  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(seconds: 5);
  }

  @override
  String toString() {
    return 'TypingIndicator{chatId: $chatId, userId: $userId, userName: $userName}';
  }
}

/// Model for read receipts
class ReadReceipt {
  final String messageId;
  final String userId;
  final String userName;
  final DateTime readAt;

  ReadReceipt({
    required this.messageId,
    required this.userId,
    required this.userName,
    required this.readAt,
  });

  factory ReadReceipt.fromJson(Map<String, dynamic> json) {
    return ReadReceipt(
      messageId: json['MessageId']?.toString() ?? '',
      userId: json['UserId']?.toString() ?? '',
      userName: json['UserName']?.toString() ?? '',
      readAt: DateTime.tryParse(json['ReadAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'MessageId': messageId,
      'UserId': userId,
      'UserName': userName,
      'ReadAt': readAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'ReadReceipt{messageId: $messageId, userId: $userId, readAt: $readAt}';
  }
}

/// Model for chat notifications
class ChatNotification {
  final String id;
  final String chatId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  ChatNotification({
    required this.id,
    required this.chatId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  factory ChatNotification.fromJson(Map<String, dynamic> json) {
    return ChatNotification(
      id: json['Id']?.toString() ?? '',
      chatId: json['ChatId']?.toString() ?? '',
      title: json['Title']?.toString() ?? '',
      body: json['Body']?.toString() ?? '',
      type: NotificationType.fromValue(json['Type']?.toString() ?? 'message'),
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['IsRead'] == true,
      data: json['Data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'ChatId': chatId,
      'Title': title,
      'Body': body,
      'Type': type.value,
      'CreatedAt': createdAt.toIso8601String(),
      'IsRead': isRead,
      'Data': data,
    };
  }

  @override
  String toString() {
    return 'ChatNotification{id: $id, chatId: $chatId, type: $type, isRead: $isRead}';
  }
}

/// Enum for notification types
enum NotificationType {
  message('message'),
  mention('mention'),
  assignment('assignment'),
  statusChange('status_change'),
  system('system');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromValue(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => NotificationType.message,
    );
  }

  String get displayName {
    switch (this) {
      case NotificationType.message:
        return 'New Message';
      case NotificationType.mention:
        return 'Mention';
      case NotificationType.assignment:
        return 'Assignment';
      case NotificationType.statusChange:
        return 'Status Change';
      case NotificationType.system:
        return 'System';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.mention:
        return Icons.alternate_email;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.statusChange:
        return Icons.update;
      case NotificationType.system:
        return Icons.info;
    }
  }
}

/// Extensions for better usability
extension ChatConversationExtensions on ChatConversation {
  /// Check if conversation needs attention
  bool get needsAttention => unreadCount > 0 && !isMuted;
  
  /// Check if conversation is active
  bool get isActive => !isArchived && status != ChatStatus.resolved;
  
  /// Get display subtitle
  String get subtitle {
    if (isArchived) return 'Archived';
    if (status == ChatStatus.resolved) return 'Resolved';
    if (unreadCount > 0) return '$unreadCount unread';
    return 'No new messages';
  }
  
  /// Get priority score for sorting
  int get priorityScore {
    int score = 0;
    if (isPinned) score += 1000;
    if (needsAttention) score += 100;
    score += unreadCount;
    return score;
  }
}

extension ChatStatusExtensions on ChatStatus {
  /// Check if status allows messaging
  bool get allowsMessaging {
    return this != ChatStatus.archived && this != ChatStatus.resolved;
  }
  
  /// Check if status requires assignment
  bool get requiresAssignment {
    return this == ChatStatus.unassigned;
  }
}