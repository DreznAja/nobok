import 'dart:convert';
import '../models/api_response.dart';
import '../services/api_service.dart';

/// Service for managing message templates and quick replies
class TemplateService {
  static List<MessageTemplate> _templates = [];
  static List<QuickReply> _quickReplies = [];
  
  /// Load templates from server
  static Future<ApiResponse<List<MessageTemplate>>> loadTemplates() async {
    try {
      final response = await ApiService._dio.get('/Services/Chat/Templates/List');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          _templates = entities.map((json) => MessageTemplate.fromJson(json)).toList();
          return ApiResponse.success(_templates);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to load templates');
        }
      } else {
        return ApiResponse.error('Failed to load templates: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error loading templates: $e');
      return ApiResponse.networkError('Failed to load templates: $e');
    }
  }
  
  /// Load quick replies from server
  static Future<ApiResponse<List<QuickReply>>> loadQuickReplies() async {
    try {
      final response = await ApiService._dio.get('/Services/Chat/QuickReplies/List');
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          _quickReplies = entities.map((json) => QuickReply.fromJson(json)).toList();
          return ApiResponse.success(_quickReplies);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to load quick replies');
        }
      } else {
        return ApiResponse.error('Failed to load quick replies: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error loading quick replies: $e');
      return ApiResponse.networkError('Failed to load quick replies: $e');
    }
  }
  
  /// Get templates by channel
  static List<MessageTemplate> getTemplatesByChannel(int channelId) {
    return _templates.where((template) => 
      template.channelId == null || template.channelId == channelId
    ).toList();
  }
  
  /// Get quick replies by type
  static List<QuickReply> getQuickRepliesByType(QuickReplyType type) {
    return _quickReplies.where((reply) => reply.type == type).toList();
  }
  
  /// Send template message
  static Future<ApiResponse<bool>> sendTemplateMessage({
    required String templateId,
    required Map<String, dynamic> templateData,
    required int channelId,
    int? linkId,
    String? linkIdExt,
  }) async {
    try {
      final requestData = {
        'ChannelId': channelId,
        'TemplateId': templateId,
        'TemplateData': templateData,
      };
      
      if (linkId != null) {
        requestData['LinkId'] = linkId;
      }
      
      if (linkIdExt != null && linkIdExt.isNotEmpty) {
        requestData['CtIdExt'] = linkIdExt;
      }

      final response = await ApiService._dio.post(
        '/Services/Chat/Templates/Send',
        data: requestData,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to send template');
        }
      } else {
        return ApiResponse.error('Failed to send template: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error sending template: $e');
      return ApiResponse.networkError('Failed to send template: $e');
    }
  }
  
  /// Get all templates
  static List<MessageTemplate> get templates => List.unmodifiable(_templates);
  
  /// Get all quick replies
  static List<QuickReply> get quickReplies => List.unmodifiable(_quickReplies);
}

/// Message template model
class MessageTemplate {
  final String id;
  final String name;
  final String content;
  final int? channelId;
  final TemplateType type;
  final List<TemplateComponent> components;
  final Map<String, dynamic>? metadata;

  MessageTemplate({
    required this.id,
    required this.name,
    required this.content,
    this.channelId,
    required this.type,
    this.components = const [],
    this.metadata,
  });

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      content: json['Content']?.toString() ?? '',
      channelId: json['ChannelId'],
      type: TemplateType.fromString(json['Type']?.toString() ?? 'text'),
      components: (json['Components'] as List<dynamic>?)
          ?.map((comp) => TemplateComponent.fromJson(comp))
          .toList() ?? [],
      metadata: json['Metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Content': content,
      'ChannelId': channelId,
      'Type': type.toString(),
      'Components': components.map((comp) => comp.toJson()).toList(),
      'Metadata': metadata,
    };
  }
}

/// Template component model
class TemplateComponent {
  final String type;
  final String? text;
  final Map<String, dynamic>? parameters;

  TemplateComponent({
    required this.type,
    this.text,
    this.parameters,
  });

  factory TemplateComponent.fromJson(Map<String, dynamic> json) {
    return TemplateComponent(
      type: json['type']?.toString() ?? '',
      text: json['text']?.toString(),
      parameters: json['parameters'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'parameters': parameters,
    };
  }
}

/// Template type enum
enum TemplateType {
  text,
  interactive,
  media,
  button,
  list;

  static TemplateType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'interactive': return TemplateType.interactive;
      case 'media': return TemplateType.media;
      case 'button': return TemplateType.button;
      case 'list': return TemplateType.list;
      default: return TemplateType.text;
    }
  }

  @override
  String toString() {
    switch (this) {
      case TemplateType.interactive: return 'interactive';
      case TemplateType.media: return 'media';
      case TemplateType.button: return 'button';
      case TemplateType.list: return 'list';
      default: return 'text';
    }
  }
}

/// Quick reply model
class QuickReply {
  final String id;
  final String command;
  final String content;
  final QuickReplyType type;
  final List<String>? files;

  QuickReply({
    required this.id,
    required this.command,
    required this.content,
    required this.type,
    this.files,
  });

  factory QuickReply.fromJson(Map<String, dynamic> json) {
    return QuickReply(
      id: json['Id']?.toString() ?? '',
      command: json['Cmd']?.toString() ?? '',
      content: json['Cnt']?.toString() ?? '',
      type: QuickReplyType.fromString(json['Type']?.toString() ?? '1'),
      files: (json['Files'] as String?)?.isNotEmpty == true 
          ? (jsonDecode(json['Files']) as List<dynamic>).map((f) => f.toString()).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Cmd': command,
      'Cnt': content,
      'Type': type.value,
      'Files': files != null ? jsonEncode(files) : null,
    };
  }
}

/// Quick reply type enum
enum QuickReplyType {
  text(1),
  button(2),
  list(3);

  const QuickReplyType(this.value);
  final int value;

  static QuickReplyType fromString(String value) {
    switch (value) {
      case '2': return QuickReplyType.button;
      case '3': return QuickReplyType.list;
      default: return QuickReplyType.text;
    }
  }

  @override
  String toString() => value.toString();
}

/// Chat notification model
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