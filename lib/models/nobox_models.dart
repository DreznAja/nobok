import 'package:flutter/material.dart';
import 'message_model.dart';

/// Model untuk Contact List
class ContactList {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? avatar;
  final DateTime? lastSeen;
  final bool isOnline;
  final int unreadCount;

  ContactList({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.avatar,
    this.lastSeen,
    this.isOnline = false,
    this.unreadCount = 0,
  });

  factory ContactList.fromJson(Map<String, dynamic> json) {
    return ContactList(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      phone: json['Phone']?.toString() ?? json['phone']?.toString(),
      email: json['Email']?.toString() ?? json['email']?.toString(),
      avatar: json['Avatar']?.toString() ?? json['avatar']?.toString(),
      lastSeen: json['LastSeen'] != null 
        ? DateTime.tryParse(json['LastSeen'].toString()) 
        : null,
      isOnline: json['IsOnline'] == true || json['isOnline'] == true,
      unreadCount: int.tryParse(json['UnreadCount']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Phone': phone,
      'Email': email,
      'Avatar': avatar,
      'LastSeen': lastSeen?.toIso8601String(),
      'IsOnline': isOnline,
      'UnreadCount': unreadCount,
    };
  }

  ContactList copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? avatar,
    DateTime? lastSeen,
    bool? isOnline,
    int? unreadCount,
  }) {
    return ContactList(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  String toString() {
    return 'ContactList{id: $id, name: $name, phone: $phone, isOnline: $isOnline, unreadCount: $unreadCount}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactList &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk Chat Link
class Link {
  final String id;
  final String idExt;
  final String name;
  final String? description;
  final String? avatar;
  final DateTime? lastActivity;
  final int unreadCount;
  final bool isGroup;
  final bool isArchived;
  final bool isMuted;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  Link({
    required this.id,
    required this.idExt,
    required this.name,
    this.description,
    this.avatar,
    this.lastActivity,
    this.unreadCount = 0,
    this.isGroup = false,
    this.isArchived = false,
    this.isMuted = false,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? json['idExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      description: json['Description']?.toString() ?? json['description']?.toString(),
      avatar: json['Avatar']?.toString() ?? json['avatar']?.toString(),
      lastActivity: json['LastActivity'] != null 
        ? DateTime.tryParse(json['LastActivity'].toString()) 
        : null,
      unreadCount: int.tryParse(json['UnreadCount']?.toString() ?? '0') ?? 0,
      isGroup: json['IsGroup'] == true || json['isGroup'] == true,
      isArchived: json['IsArchived'] == true || json['isArchived'] == true,
      isMuted: json['IsMuted'] == true || json['isMuted'] == true,
      lastMessage: json['LastMessage']?.toString() ?? json['lastMessage']?.toString(),
      lastMessageTime: json['LastMessageTime'] != null 
        ? DateTime.tryParse(json['LastMessageTime'].toString()) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'IdExt': idExt,
      'Name': name,
      'Description': description,
      'Avatar': avatar,
      'LastActivity': lastActivity?.toIso8601String(),
      'UnreadCount': unreadCount,
      'IsGroup': isGroup,
      'IsArchived': isArchived,
      'IsMuted': isMuted,
      'LastMessage': lastMessage,
      'LastMessageTime': lastMessageTime?.toIso8601String(),
    };
  }

  Link copyWith({
    String? id,
    String? idExt,
    String? name,
    String? description,
    String? avatar,
    DateTime? lastActivity,
    int? unreadCount,
    bool? isGroup,
    bool? isArchived,
    bool? isMuted,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return Link(
      id: id ?? this.id,
      idExt: idExt ?? this.idExt,
      name: name ?? this.name,
      description: description ?? this.description,
      avatar: avatar ?? this.avatar,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  @override
  String toString() {
    return 'Link{id: $id, idExt: $idExt, name: $name, unreadCount: $unreadCount, isGroup: $isGroup}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Link &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk Channel
class ListChannel {
  final int id;
  final String name;
  final String? description;
  final String? type;
  final bool isActive;
  final DateTime? createdAt;
  final Map<String, dynamic>? settings;

  ListChannel({
    required this.id,
    required this.name,
    this.description,
    this.type,
    this.isActive = true,
    this.createdAt,
    this.settings,
  });

  factory ListChannel.fromJson(Map<String, dynamic> json) {
    return ListChannel(
      id: json['Id'] ?? json['id'] ?? 0,
      name: json['Nm']?.toString() ?? json['name']?.toString() ?? json['Name']?.toString() ?? '',
      description: json['Description']?.toString() ?? json['description']?.toString(),
      type: json['Type']?.toString() ?? json['type']?.toString(),
      isActive: json['IsActive'] == true || json['isActive'] == true,
      createdAt: json['CreatedAt'] != null 
        ? DateTime.tryParse(json['CreatedAt'].toString()) 
        : null,
      settings: json['Settings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Nm': name,
      'Description': description,
      'Type': type,
      'IsActive': isActive,
      'CreatedAt': createdAt?.toIso8601String(),
      'Settings': settings,
    };
  }

  ListChannel copyWith({
    int? id,
    String? name,
    String? description,
    String? type,
    bool? isActive,
    DateTime? createdAt,
    Map<String, dynamic>? settings,
  }) {
    return ListChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      settings: settings ?? this.settings,
    );
  }

  @override
  String toString() {
    return 'ListChannel{id: $id, name: $name, type: $type, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListChannel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk Account
class ListAccount {
  final String id;
  final String name;
  final int channel;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? role;
  final bool isActive;
  final DateTime? lastLogin;
  final Map<String, dynamic>? permissions;

  ListAccount({
    required this.id,
    required this.name,
    required this.channel,
    this.email,
    this.phone,
    this.avatar,
    this.role,
    this.isActive = true,
    this.lastLogin,
    this.permissions,
  });

  factory ListAccount.fromJson(Map<String, dynamic> json) {
    return ListAccount(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      channel: json['Channel'] ?? json['channel'] ?? 0,
      email: json['Email']?.toString() ?? json['email']?.toString(),
      phone: json['Phone']?.toString() ?? json['phone']?.toString(),
      avatar: json['Avatar']?.toString() ?? json['avatar']?.toString(),
      role: json['Role']?.toString() ?? json['role']?.toString(),
      isActive: json['IsActive'] == true || json['isActive'] == true,
      lastLogin: json['LastLogin'] != null 
        ? DateTime.tryParse(json['LastLogin'].toString()) 
        : null,
      permissions: json['Permissions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Channel': channel,
      'Email': email,
      'Phone': phone,
      'Avatar': avatar,
      'Role': role,
      'IsActive': isActive,
      'LastLogin': lastLogin?.toIso8601String(),
      'Permissions': permissions,
    };
  }

  ListAccount copyWith({
    String? id,
    String? name,
    int? channel,
    String? email,
    String? phone,
    String? avatar,
    String? role,
    bool? isActive,
    DateTime? lastLogin,
    Map<String, dynamic>? permissions,
  }) {
    return ListAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      channel: channel ?? this.channel,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  String toString() {
    return 'ListAccount{id: $id, name: $name, channel: $channel, role: $role, isActive: $isActive}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListAccount &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model untuk Uploaded File
class UploadedFile {
  final String filename;
  final String originalName;
  final String? mimeType;
  final int? size;
  final String? url;
  final DateTime? uploadedAt;

  UploadedFile({
    required this.filename,
    required this.originalName,
    this.mimeType,
    this.size,
    this.url,
    this.uploadedAt,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      filename: json['Filename']?.toString() ?? json['filename']?.toString() ?? '',
      originalName: json['OriginalName']?.toString() ?? json['originalName']?.toString() ?? '',
      mimeType: json['MimeType']?.toString() ?? json['mimeType']?.toString(),
      size: int.tryParse(json['Size']?.toString() ?? json['size']?.toString() ?? '0'),
      url: json['Url']?.toString() ?? json['url']?.toString(),
      uploadedAt: json['UploadedAt'] != null 
        ? DateTime.tryParse(json['UploadedAt'].toString()) 
        : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Filename': filename,
      'OriginalName': originalName,
      'MimeType': mimeType,
      'Size': size,
      'Url': url,
      'UploadedAt': uploadedAt?.toIso8601String(),
    };
  }

  bool get isImage => mimeType?.startsWith('image/') == true;
  bool get isVideo => mimeType?.startsWith('video/') == true;
  bool get isAudio => mimeType?.startsWith('audio/') == true;
  bool get isDocument => !isImage && !isVideo && !isAudio;

  String get displaySize {
    if (size == null) return 'Unknown size';
    if (size! < 1024) return '${size} B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  String toString() {
    return 'UploadedFile{filename: $filename, originalName: $originalName, mimeType: $mimeType, size: $size}';
  }
}

/// Enum untuk Body Type sesuai dengan backend C#
enum BodyType {
  text(1),
  audio(2),
  image(3),
  video(4),
  file(5),
  sticker(7),
  location(9),
  order(10),
  product(11),
  vcard(12),
  vcardMulti(13);

  const BodyType(this.value);
  final int value;

  static BodyType fromValue(int value) {
    return BodyType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => BodyType.text,
    );
  }

  String get displayName {
    switch (this) {
      case BodyType.text: return 'Text';
      case BodyType.audio: return 'Audio';
      case BodyType.image: return 'Image';
      case BodyType.video: return 'Video';
      case BodyType.file: return 'File';
      case BodyType.sticker: return 'Sticker';
      case BodyType.location: return 'Location';
      case BodyType.order: return 'Order';
      case BodyType.product: return 'Product';
      case BodyType.vcard: return 'VCard';
      case BodyType.vcardMulti: return 'VCard Multi';
    }
  }

  IconData get icon {
    switch (this) {
      case BodyType.text: return Icons.message;
      case BodyType.audio: return Icons.audiotrack;
      case BodyType.image: return Icons.image;
      case BodyType.video: return Icons.videocam;
      case BodyType.file: return Icons.attach_file;
      case BodyType.sticker: return Icons.emoji_emotions;
      case BodyType.location: return Icons.location_on;
      case BodyType.order: return Icons.shopping_cart;
      case BodyType.product: return Icons.inventory;
      case BodyType.vcard: return Icons.contact_page;
      case BodyType.vcardMulti: return Icons.contacts;
    }
  }

  bool get isMedia => this == BodyType.image || this == BodyType.video || this == BodyType.audio;
  bool get isFile => this == BodyType.file;
  bool get isText => this == BodyType.text;
}

/// Model untuk Inbox Request
class InboxModel {
  final int linkId;
  final int channelId;
  final String? accountIds;
  final BodyType bodyType;
  final String body;
  final String? attachment;
  final String? ctIdExt;
  final String? replyId;

  InboxModel({
    required this.linkId,
    required this.channelId,
    this.accountIds,
    required this.bodyType,
    required this.body,
    this.attachment,
    this.ctIdExt,
    this.replyId,
  });

  factory InboxModel.fromJson(Map<String, dynamic> json) {
    return InboxModel(
      linkId: json['LinkId'] ?? json['linkId'] ?? 0,
      channelId: json['ChannelId'] ?? json['channelId'] ?? 0,
      accountIds: json['AccountIds']?.toString() ?? json['accountIds']?.toString(),
      bodyType: BodyType.fromValue(json['BodyType'] ?? json['bodyType'] ?? 1),
      body: json['Body']?.toString() ?? json['body']?.toString() ?? '',
      attachment: json['Attachment']?.toString() ?? json['attachment']?.toString(),
      ctIdExt: json['CtIdExt']?.toString() ?? json['ctIdExt']?.toString(),
      replyId: json['ReplyId']?.toString() ?? json['replyId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'ChannelId': channelId,
      'BodyType': bodyType.value,
      'Body': body,
    };

    if (linkId > 0) {
      data['LinkId'] = linkId;
    }

    if (ctIdExt != null && ctIdExt!.isNotEmpty) {
      data['CtIdExt'] = ctIdExt;
    }
    // ✅ PERBAIKAN: Jangan sertakan CtIdExt di request body
    // Backend InboxModel tidak mengenal field ini
    
    if (attachment != null && attachment!.isNotEmpty) {
      data['Attachment'] = attachment;
    }

    if (replyId != null && replyId!.isNotEmpty) {
      data['ReplyId'] = replyId;
    }

    return data;
  }

  InboxModel copyWith({
    int? linkId,
    int? channelId,
    String? accountIds,
    BodyType? bodyType,
    String? body,
    String? attachment,
    String? ctIdExt,
    String? replyId,
  }) {
    return InboxModel(
      linkId: linkId ?? this.linkId,
      channelId: channelId ?? this.channelId,
      accountIds: accountIds ?? this.accountIds,
      bodyType: bodyType ?? this.bodyType,
      body: body ?? this.body,
      attachment: attachment ?? this.attachment,
      ctIdExt: ctIdExt ?? this.ctIdExt,
      replyId: replyId ?? this.replyId,
    );
  }

  @override
  String toString() {
    return 'InboxModel{linkId: $linkId, channelId: $channelId, bodyType: $bodyType, body: $body, attachment: $attachment}';
  }
}

/// Response wrapper untuk API Nobox
class ResponseNobox<T> {
  final int code;
  final bool isError;
  final T? data;
  final String? error;

  ResponseNobox({
    required this.code,
    required this.isError,
    this.data,
    this.error,
  });

  factory ResponseNobox.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ResponseNobox(
      code: json['Code'] ?? json['code'] ?? 0,
      isError: json['IsError'] ?? json['isError'] ?? false,
      data: json['Data'] != null ? fromJsonT(json['Data']) : null,
      error: json['Error']?.toString() ?? json['error']?.toString(),
    );
  }

  factory ResponseNobox.success(T data) {
    return ResponseNobox(
      code: 200,
      isError: false,
      data: data,
    );
  }

  factory ResponseNobox.error(String error, {int code = 400}) {
    return ResponseNobox(
      code: code,
      isError: true,
      error: error,
    );
  }

  bool get success => !isError && code >= 200 && code < 300;

  @override
  String toString() {
    return 'ResponseNobox{code: $code, isError: $isError, error: $error}';
  }
}

/// Model untuk Chat Room Info
class ChatRoomInfo {
  final String id;
  final String name;
  final String? description;
  final String? avatar;
  final List<String> participants;
  final bool isGroup;
  final DateTime? createdAt;
  final DateTime? lastActivity;
  final Map<String, dynamic>? settings;

  ChatRoomInfo({
    required this.id,
    required this.name,
    this.description,
    this.avatar,
    this.participants = const [],
    this.isGroup = false,
    this.createdAt,
    this.lastActivity,
    this.settings,
  });

  factory ChatRoomInfo.fromJson(Map<String, dynamic> json) {
    return ChatRoomInfo(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      description: json['Description']?.toString() ?? json['description']?.toString(),
      avatar: json['Avatar']?.toString() ?? json['avatar']?.toString(),
      participants: (json['Participants'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isGroup: json['IsGroup'] == true || json['isGroup'] == true,
      createdAt: json['CreatedAt'] != null 
        ? DateTime.tryParse(json['CreatedAt'].toString()) 
        : null,
      lastActivity: json['LastActivity'] != null 
        ? DateTime.tryParse(json['LastActivity'].toString()) 
        : null,
      settings: json['Settings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Description': description,
      'Avatar': avatar,
      'Participants': participants,
      'IsGroup': isGroup,
      'CreatedAt': createdAt?.toIso8601String(),
      'LastActivity': lastActivity?.toIso8601String(),
      'Settings': settings,
    };
  }

  @override
  String toString() {
    return 'ChatRoomInfo{id: $id, name: $name, isGroup: $isGroup, participants: ${participants.length}}';
  }
}

/// Model untuk Message Status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed;

  String get displayName {
    switch (this) {
      case MessageStatus.sending: return 'Sending';
      case MessageStatus.sent: return 'Sent';
      case MessageStatus.delivered: return 'Delivered';
      case MessageStatus.read: return 'Read';
      case MessageStatus.failed: return 'Failed';
    }
  }

  IconData get icon {
    switch (this) {
      case MessageStatus.sending: return Icons.access_time;
      case MessageStatus.sent: return Icons.done;
      case MessageStatus.delivered: return Icons.done_all;
      case MessageStatus.read: return Icons.done_all;
      case MessageStatus.failed: return Icons.error_outline;
    }
  }

  Color get color {
    switch (this) {
      case MessageStatus.sending: return Colors.grey;
      case MessageStatus.sent: return Colors.grey;
      case MessageStatus.delivered: return Colors.blue;
      case MessageStatus.read: return Colors.blue;
      case MessageStatus.failed: return Colors.red;
    }
  }
}

/// Extension untuk backward compatibility dengan model lama
extension BackwardCompatibility on NoboxMessage {
  // Alias untuk kompatibilitas dengan kode lama
  String get senderName => displayName;
  bool get isMe => isFromMe;
}

/// Utility class untuk parsing berbagai format response
class NoboxResponseParser {
  static List<NoboxMessage> parseMessages(dynamic data, {String endpoint = 'unknown'}) {
    if (data == null) return [];
    
    List<dynamic> messageList = [];
    
    if (data is List) {
      messageList = data;
    } else if (data is Map<String, dynamic>) {
      if (data['Entities'] != null) {
        messageList = data['Entities'] as List<dynamic>;
      } else if (data['Data'] != null) {
        final dataField = data['Data'];
        if (dataField is List) {
          messageList = dataField;
        } else if (dataField is Map && dataField['Entities'] != null) {
          messageList = dataField['Entities'] as List<dynamic>;
        }
      }
    }
    
    return messageList.map((json) {
      try {
        if (endpoint.toLowerCase().contains('detailroom') || endpoint.toLowerCase().contains('room')) {
          return NoboxMessage.fromDetailRoomJson(json as Map<String, dynamic>);
        } else {
          return NoboxMessage.fromMessagesJson(json as Map<String, dynamic>);
        }
      } catch (e) {
        print('🔥 Error parsing message from $endpoint: $e');
        return NoboxMessage.fromDetailRoomJson(json as Map<String, dynamic>);
      }
    }).toList();
  }
}