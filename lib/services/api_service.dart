import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../models/nobox_models.dart';
import '../utils/connection_utils.dart';

// Model classes for API responses
class ChatLinkModel {
  final String id;
  final String idExt;
  final String name;

  ChatLinkModel({
    required this.id,
    required this.idExt,
    required this.name,
  });

  factory ChatLinkModel.fromJson(Map<String, dynamic> json) {
    return ChatLinkModel(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? json['idExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'IdExt': idExt,
      'Name': name,
    };
  }

  @override
  String toString() => 'ChatLinkModel{id: $id, idExt: $idExt, name: $name}';
}

class ChannelModel {
  final int id;
  final String name;

  ChannelModel({
    required this.id,
    required this.name,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['Id'] ?? json['id'] ?? 0,
      name: json['Nm']?.toString() ?? json['name']?.toString() ?? json['Name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Nm': name,
    };
  }

  @override
  String toString() => 'ChannelModel{id: $id, name: $name}';
}

class AccountModel {
  final String id;
  final String name;
  final int channel;

  AccountModel({
    required this.id,
    required this.name,
    required this.channel,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
      channel: json['Channel'] ?? json['channel'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      'Channel': channel,
    };
  }

  @override
  String toString() => 'AccountModel{id: $id, name: $name, channel: $channel}';
}

class ContactModel {
  final String id;
  final String name;

  ContactModel({
    required this.id,
    required this.name,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
    };
  }

  @override
  String toString() => 'ContactModel{id: $id, name: $name}';
}

class LinkModel {
  final String id;
  final String idExt;
  final String name;

  LinkModel({
    required this.id,
    required this.idExt,
    required this.name,
  });

  factory LinkModel.fromJson(Map<String, dynamic> json) {
    return LinkModel(
      id: json['Id']?.toString() ?? json['id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? json['idExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'IdExt': idExt,
      'Name': name,
    };
  }

  @override
  String toString() => 'LinkModel{id: $id, idExt: $idExt, name: $name}';
}

class ApiService {
  static const String _baseUrl = 'https://id.nobox.ai';
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _fileUploadTimeout = Duration(minutes: 5);
  
  static String? _authToken;
  static late Dio _dio;
  static late http.Client _httpClient;
  
  // Circuit breakers for different operations
  static late CircuitBreaker _apiCircuitBreaker;
  static late CircuitBreaker _uploadCircuitBreaker;
  static late RateLimiter _rateLimiter;

  static String? get authToken => _authToken;

  static void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _fileUploadTimeout,
    ));
    
    _httpClient = http.Client();
    
    // Initialize circuit breakers
    _apiCircuitBreaker = ConnectionUtils.createCircuitBreaker(
      name: 'API',
      failureThreshold: 3,
      timeout: _timeout,
      resetTimeout: const Duration(minutes: 1),
    );
    
    _uploadCircuitBreaker = ConnectionUtils.createCircuitBreaker(
      name: 'Upload',
      failureThreshold: 2,
      timeout: _fileUploadTimeout,
      resetTimeout: const Duration(minutes: 2),
    );
    
    _rateLimiter = ConnectionUtils.createRateLimiter(
      maxRequests: 10,
      window: const Duration(seconds: 1),
    );

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_authToken != null) {
          options.headers['Authorization'] = 'Bearer $_authToken';
        }
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';
        handler.next(options);
      },
      onError: (error, handler) {
        print('🔥 API Error: ${error.message}');
        handler.next(error);
      },
    ));
  }

  static void setAuthToken(String token) {
    _authToken = token;
    print('🔥 Auth token set');
  }

  static void clearAuthToken() {
    _authToken = null;
    print('🔥 Auth token cleared');
  }

  // Enhanced login with retry logic
  static Future<ApiResponse<User>> login(String username, String password) async {
    return ConnectionUtils.retryWithBackoff(
      () => _performLogin(username, password),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'Login',
    );
  }

  static Future<ApiResponse<User>> _performLogin(String username, String password) async {
    try {
      await _rateLimiter.allowRequest();
      
      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.post(
          '/Account/LoginMobile',
          data: {
            'Username': username,
            'Password': password,
          },
        );
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['success'] == true || data['IsError'] != true) {
          final userData = data['data'] ?? data['Data'] ?? data;
          final token = data['token'] ?? data['Token'] ?? userData['token'] ?? userData['Token'];
          
          if (token != null) {
            setAuthToken(token);
            final user = User.fromJson(userData);
            return ApiResponse.success(user);
          } else {
            return ApiResponse.error('No authentication token received');
          }
        } else {
          return ApiResponse.error(data['message'] ?? data['Message'] ?? 'Login failed');
        }
      } else {
        return ApiResponse.error('Login failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Login error: $e');
      if (e.toString().contains('401')) {
        return ApiResponse.unauthorized('Invalid credentials');
      } else if (e.toString().contains('timeout')) {
        return ApiResponse.timeout('Login request timed out');
      } else {
        return ApiResponse.networkError('Login failed: $e');
      }
    }
  }

  // Test connection
  static Future<ApiResponse<bool>> testConnection() async {
    try {
      final response = await _dio.get('/api/test');
      return ApiResponse.success(response.statusCode == 200);
    } catch (e) {
      return ApiResponse.networkError('Connection test failed');
    }
  }

  // Get chat links with enhanced error handling
  static Future<ApiResponse<List<ChatLinkModel>>> getChatLinks({
    int? channelId,
    int take = 20,
    int skip = 0,
    String? search,
  }) async {
    return ConnectionUtils.retryWithBackoff(
      () => _getChatLinks(channelId: channelId, take: take, skip: skip, search: search),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'GetChatLinks',
    );
  }

  static Future<ApiResponse<List<ChatLinkModel>>> _getChatLinks({
    int? channelId,
    int take = 20,
    int skip = 0,
    String? search,
  }) async {
    try {
      await _rateLimiter.allowRequest();
      
      final queryParams = <String, dynamic>{
        'Take': take,
        'Skip': skip,
      };
      
      if (channelId != null) {
        queryParams['ChannelId'] = channelId;
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['ContainsText'] = search;
      }

      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.get(
          '/Services/Chat/Chatrooms/List',
          queryParameters: queryParams,
        );
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final chatLinks = entities.map((json) => ChatLinkModel.fromJson(json)).toList();
          return ApiResponse.success(chatLinks);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get chat links');
        }
      } else {
        return ApiResponse.error('Failed to get chat links: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting chat links: $e');
      return ApiResponse.networkError('Failed to get chat links: $e');
    }
  }

  // Get archived chat links
  static Future<ApiResponse<List<ChatLinkModel>>> getArchivedChatLinks({
    int take = 100,
    int skip = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/Services/Chat/Chatrooms/List',
        queryParameters: {
          'Take': take,
          'Skip': skip,
          'IsArchived': true,
          'Sort': ['Up DESC'],
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final chatLinks = entities.map((json) => ChatLinkModel.fromJson(json)).toList();
          return ApiResponse.success(chatLinks);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get archived chats');
        }
      } else {
        return ApiResponse.error('Failed to get archived chats: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting archived chats: $e');
      return ApiResponse.networkError('Failed to get archived chats: $e');
    }
  }

  // Get channels
  static Future<ApiResponse<List<ChannelModel>>> getChannels() async {
    return ConnectionUtils.retryWithBackoff(
      () => _getChannels(),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'GetChannels',
    );
  }

  static Future<ApiResponse<List<ChannelModel>>> _getChannels() async {
    try {
      await _rateLimiter.allowRequest();
      
      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.get('/Services/Chat/Channels/List');
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final channels = entities.map((json) => ChannelModel.fromJson(json)).toList();
          return ApiResponse.success(channels);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get channels');
        }
      } else {
        return ApiResponse.error('Failed to get channels: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting channels: $e');
      return ApiResponse.networkError('Failed to get channels: $e');
    }
  }

  // Get accounts
  static Future<ApiResponse<List<AccountModel>>> getAccounts({int? channelId}) async {
    return ConnectionUtils.retryWithBackoff(
      () => _getAccounts(channelId: channelId),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'GetAccounts',
    );
  }

  static Future<ApiResponse<List<AccountModel>>> _getAccounts({int? channelId}) async {
    try {
      await _rateLimiter.allowRequest();
      
      final queryParams = <String, dynamic>{};
      if (channelId != null) {
        queryParams['ChannelId'] = channelId;
      }

      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.get(
          '/Services/Chat/Accounts/List',
          queryParameters: queryParams,
        );
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final accounts = entities.map((json) => AccountModel.fromJson(json)).toList();
          return ApiResponse.success(accounts);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get accounts');
        }
      } else {
        return ApiResponse.error('Failed to get accounts: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting accounts: $e');
      return ApiResponse.networkError('Failed to get accounts: $e');
    }
  }

  // Get contacts
  static Future<ApiResponse<List<ContactModel>>> getContacts() async {
    return ConnectionUtils.retryWithBackoff(
      () => _getContacts(),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'GetContacts',
    );
  }

  static Future<ApiResponse<List<ContactModel>>> _getContacts() async {
    try {
      await _rateLimiter.allowRequest();
      
      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.get('/Services/Chat/Contacts/List');
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final contacts = entities.map((json) => ContactModel.fromJson(json)).toList();
          return ApiResponse.success(contacts);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get contacts');
        }
      } else {
        return ApiResponse.error('Failed to get contacts: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting contacts: $e');
      return ApiResponse.networkError('Failed to get contacts: $e');
    }
  }

  // Get link list
  static Future<ApiResponse<List<LinkModel>>> getLinkList({
    required int channelId,
    int take = 100,
    int skip = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/Services/Chat/Links/List',
        queryParameters: {
          'ChannelId': channelId,
          'Take': take,
          'Skip': skip,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final links = entities.map((json) => LinkModel.fromJson(json)).toList();
          return ApiResponse.success(links);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get links');
        }
      } else {
        return ApiResponse.error('Failed to get links: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting links: $e');
      return ApiResponse.networkError('Failed to get links: $e');
    }
  }

  // Get messages for a chat
  static Future<ApiResponse<List<NoboxMessage>>> getMessages({
    int? linkId,
    required int channelId,
    String? linkIdExt,
    int take = 50,
    int skip = 0,
    int limit = 50,
    String orderBy = 'CreatedAt',
    String orderDirection = 'desc',
  }) async {
    return ConnectionUtils.retryWithBackoff(
      () => _getMessages(
        linkId: linkId,
        channelId: channelId,
        linkIdExt: linkIdExt,
        take: take,
        skip: skip,
        limit: limit,
        orderBy: orderBy,
        orderDirection: orderDirection,
      ),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'GetMessages',
    );
  }

  static Future<ApiResponse<List<NoboxMessage>>> _getMessages({
    int? linkId,
    required int channelId,
    String? linkIdExt,
    int take = 50,
    int skip = 0,
    int limit = 50,
    String orderBy = 'CreatedAt',
    String orderDirection = 'desc',
  }) async {
    try {
      await _rateLimiter.allowRequest();
      
      final queryParams = <String, dynamic>{
        'ChannelId': channelId,
        'Take': take,
        'Skip': skip,
        'Limit': limit,
        'OrderBy': orderBy,
        'OrderDirection': orderDirection,
      };
      
      if (linkId != null) {
        queryParams['LinkId'] = linkId;
      }
      
      if (linkIdExt != null && linkIdExt.isNotEmpty) {
        queryParams['LinkIdExt'] = linkIdExt;
      }

      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.get(
          '/Services/Chat/Messages/List',
          queryParameters: queryParams,
        );
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final messages = entities.map((json) => NoboxMessage.fromMessagesJson(json)).toList();
          return ApiResponse.success(messages);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get messages');
        }
      } else {
        return ApiResponse.error('Failed to get messages: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting messages: $e');
      return ApiResponse.networkError('Failed to get messages: $e');
    }
  }

  // Send message
  static Future<ApiResponse<bool>> sendMessage({
    required String content,
    required int channelId,
    int? linkId,
    String? linkIdExt,
    int bodyType = 1,
    String? replyId,
  }) async {
    return ConnectionUtils.retryWithBackoff(
      () => _sendMessage(
        content: content,
        channelId: channelId,
        linkId: linkId,
        linkIdExt: linkIdExt,
        bodyType: bodyType,
        replyId: replyId,
      ),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'SendMessage',
    );
  }

  static Future<ApiResponse<bool>> _sendMessage({
    required String content,
    required int channelId,
    int? linkId,
    String? linkIdExt,
    int bodyType = 1,
    String? replyId,
  }) async {
    try {
      await _rateLimiter.allowRequest();
      
      final requestData = <String, dynamic>{
        'ChannelId': channelId,
        'BodyType': bodyType,
        'Body': content,
      };
      
      if (linkId != null) {
        requestData['LinkId'] = linkId;
      }
      
      if (linkIdExt != null && linkIdExt.isNotEmpty) {
        requestData['CtIdExt'] = linkIdExt;
      }
      
      if (replyId != null && replyId.isNotEmpty) {
        requestData['ReplyId'] = replyId;
      }

      final response = await _apiCircuitBreaker.execute(() async {
        return await _dio.post('/Services/Chat/Messages/Send', data: requestData);
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to send message');
        }
      } else {
        return ApiResponse.error('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error sending message: $e');
      return ApiResponse.networkError('Failed to send message: $e');
    }
  }

  // Send message with attachment
  static Future<ApiResponse<bool>> sendMessageWithAttachment({
    required String content,
    required int channelId,
    int? linkId,
    String? linkIdExt,
    required String attachmentFilename,
    int bodyType = 5,
    String? replyId,
  }) async {
    try {
      final requestData = <String, dynamic>{
        'ChannelId': channelId,
        'BodyType': bodyType,
        'Body': content,
        'Attachment': attachmentFilename,
      };
      
      if (linkId != null) {
        requestData['LinkId'] = linkId;
      }
      
      if (linkIdExt != null && linkIdExt.isNotEmpty) {
        requestData['CtIdExt'] = linkIdExt;
      }
      
      if (replyId != null && replyId.isNotEmpty) {
        requestData['ReplyId'] = replyId;
      }

      final response = await _dio.post('/Services/Chat/Messages/Send', data: requestData);

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to send message with attachment');
        }
      } else {
        return ApiResponse.error('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error sending message with attachment: $e');
      return ApiResponse.networkError('Failed to send message: $e');
    }
  }

  // Upload file with enhanced error handling and fallback
  static Future<ApiResponse<UploadedFile>> uploadFileWithFallback({
    required File file,
    String? customFilename,
  }) async {
    return ConnectionUtils.retryWithBackoff(
      () => _uploadFile(file: file, customFilename: customFilename),
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'UploadFile',
      maxRetries: 2,
    );
  }

  static Future<ApiResponse<UploadedFile>> _uploadFile({
    required File file,
    String? customFilename,
  }) async {
    try {
      await _rateLimiter.allowRequest();
      
      final filename = customFilename ?? file.path.split('/').last;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _uploadCircuitBreaker.execute(() async {
        return await _dio.post(
          '/Inbox/UploadFile',
          data: formData,
          options: Options(
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          ),
        );
      });

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final fileData = data['Data'] ?? data;
          final uploadedFile = UploadedFile.fromJson(fileData);
          return ApiResponse.success(uploadedFile);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to upload file');
        }
      } else {
        return ApiResponse.error('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error uploading file: $e');
      return ApiResponse.networkError('Failed to upload file: $e');
    }
  }

  // Get body type for file
  static int getBodyTypeForFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    // Image files
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return 3;
    }
    
    // Video files
    if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm', 'mkv'].contains(extension)) {
      return 4;
    }
    
    // Audio files
    if (['mp3', 'wav', 'ogg', 'aac', 'm4a', 'flac'].contains(extension)) {
      return 2;
    }
    
    // Default to document
    return 5;
  }

  // Archive conversation
  static Future<ApiResponse<bool>> archiveConversation(String chatId) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Chatrooms/MoveArchive',
        data: {'EntityId': chatId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to archive conversation');
        }
      } else {
        return ApiResponse.error('Failed to archive conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error archiving conversation: $e');
      return ApiResponse.networkError('Failed to archive conversation: $e');
    }
  }

  // Unarchive conversation
  static Future<ApiResponse<bool>> unarchiveConversation(String chatId) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Chatrooms/RestoreArchived',
        data: {'EntityId': chatId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to unarchive conversation');
        }
      } else {
        return ApiResponse.error('Failed to unarchive conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error unarchiving conversation: $e');
      return ApiResponse.networkError('Failed to unarchive conversation: $e');
    }
  }

  // Mark conversation as resolved
  static Future<ApiResponse<bool>> markAsResolved(String chatId) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Chatrooms/MarkResolved',
        data: {
          'EntityId': chatId,
          'Entity': {
            'St': 3,
            'Uc': 0,
            'IsPin': 1,
            'Isblock': 1,
          },
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to mark as resolved');
        }
      } else {
        return ApiResponse.error('Failed to mark as resolved: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error marking as resolved: $e');
      return ApiResponse.networkError('Failed to mark as resolved: $e');
    }
  }

  // Delete message
  static Future<ApiResponse<bool>> deleteMessage({
    required String messageId,
    required String roomId,
  }) async {
    try {
      final response = await _dio.delete(
        '/Services/Chat/Messages/Delete',
        data: {
          'MessageId': messageId,
          'RoomId': roomId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to delete message');
        }
      } else {
        return ApiResponse.error('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error deleting message: $e');
      return ApiResponse.networkError('Failed to delete message: $e');
    }
  }

  // Get conversation details
  static Future<ApiResponse<Map<String, dynamic>>> getConversationDetails(String roomId) async {
    try {
      final response = await _dio.get(
        '/Services/Chat/Chatrooms/DetailRoom',
        queryParameters: {'EntityId': roomId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(data['Data'] ?? data);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get conversation details');
        }
      } else {
        return ApiResponse.error('Failed to get conversation details: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting conversation details: $e');
      return ApiResponse.networkError('Failed to get conversation details: $e');
    }
  }

  // Mute/unmute bot
  static Future<ApiResponse<bool>> muteBot({
    required String roomId,
    required String accountId,
    required String linkIdExt,
    required String linkId,
    required bool mute,
  }) async {
    try {
      final endpoint = mute ? '/Services/Chat/Bot/Mute' : '/Services/Chat/Bot/Unmute';
      
      final response = await _dio.post(
        endpoint,
        data: {
          'RoomId': roomId,
          'AccountId': accountId,
          'LinkIdExt': linkIdExt,
          'LinkId': linkId,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to ${mute ? 'mute' : 'unmute'} bot');
        }
      } else {
        return ApiResponse.error('Failed to ${mute ? 'mute' : 'unmute'} bot: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error ${mute ? 'muting' : 'unmuting'} bot: $e');
      return ApiResponse.networkError('Failed to ${mute ? 'mute' : 'unmute'} bot: $e');
    }
  }

  // Set need reply status
  static Future<ApiResponse<bool>> setNeedReply({
    required String roomId,
    required bool needReply,
  }) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Chatrooms/SetNeedReply',
        data: {
          'RoomId': roomId,
          'NeedReply': needReply ? 1 : 0,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to set need reply');
        }
      } else {
        return ApiResponse.error('Failed to set need reply: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error setting need reply: $e');
      return ApiResponse.networkError('Failed to set need reply: $e');
    }
  }

  // Pin/unpin conversation
  static Future<ApiResponse<bool>> pinConversation({
    required String roomId,
    required bool pin,
  }) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Chatrooms/PinUnpin',
        data: {
          'RoomId': roomId,
          'IsPin': pin ? 2 : 1,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to ${pin ? 'pin' : 'unpin'} conversation');
        }
      } else {
        return ApiResponse.error('Failed to ${pin ? 'pin' : 'unpin'} conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error ${pin ? 'pinning' : 'unpinning'} conversation: $e');
      return ApiResponse.networkError('Failed to ${pin ? 'pin' : 'unpin'} conversation: $e');
    }
  }

  // Block/unblock contact
  static Future<ApiResponse<bool>> blockContact({
    required String contactId,
    required bool block,
  }) async {
    try {
      final response = await _dio.post(
        '/Services/Chat/Contacts/BlockUnblock',
        data: {
          'ContactId': contactId,
          'IsBlock': block ? 1 : 0,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          return ApiResponse.success(true);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to ${block ? 'block' : 'unblock'} contact');
        }
      } else {
        return ApiResponse.error('Failed to ${block ? 'block' : 'unblock'} contact: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error ${block ? 'blocking' : 'unblocking'} contact: $e');
      return ApiResponse.networkError('Failed to ${block ? 'block' : 'unblock'} contact: $e');
    }
  }

  // Get conversation statistics
  static Future<ApiResponse<Map<String, int>>> getConversationStats() async {
    try {
      final response = await _dio.get('/Services/Chat/Chatrooms/Stats');

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data['IsError'] != true) {
          final stats = Map<String, int>.from(data['Data'] ?? {});
          return ApiResponse.success(stats);
        } else {
          return ApiResponse.error(data['ErrorMsg'] ?? 'Failed to get stats');
        }
      } else {
        return ApiResponse.error('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error getting stats: $e');
      return ApiResponse.networkError('Failed to get stats: $e');
    }
  }

  // Dispose resources
  static void dispose() {
    _httpClient.close();
    _dio.close();
  }
}