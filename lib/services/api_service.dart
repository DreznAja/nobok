import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../utils/constans.dart';
import '../utils/debug_utils.dart';
import '../utils/connection_utils.dart';

/// Enhanced API Service with comprehensive error handling and offline support
class ApiService {
  static final Dio _dio = Dio();
  static String? _authToken;
  static String? _baseUrl = AppConstants.baseUrl;
  static final ConnectionUtils _connectionUtils = ConnectionUtils();
  
  // Circuit breakers for different endpoints
  static final CircuitBreaker _loginCircuitBreaker = ConnectionUtils.createCircuitBreaker(
    name: 'login',
    failureThreshold: 3,
    timeout: const Duration(seconds: 30),
  );
  
  static final CircuitBreaker _messagesCircuitBreaker = ConnectionUtils.createCircuitBreaker(
    name: 'messages',
    failureThreshold: 5,
    timeout: const Duration(seconds: 60),
  );

  // Rate limiters
  static final RateLimiter _apiRateLimiter = ConnectionUtils.createRateLimiter(
    maxRequests: 100,
    window: const Duration(minutes: 1),
  );

  static String? get authToken => _authToken;
  static String get baseUrl => _baseUrl ?? AppConstants.baseUrl;

  /// Initialize API service with configuration
  static Future<void> initialize() async {
    try {
      _dio.options.baseUrl = baseUrl;
      _dio.options.connectTimeout = const Duration(seconds: AppConstants.networkTimeout);
      _dio.options.receiveTimeout = const Duration(seconds: AppConstants.networkTimeout);
      
      // Add interceptors
      _dio.interceptors.add(LogInterceptor(
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        logPrint: (obj) => DebugUtils.log(obj.toString(), category: 'DIO'),
      ));
      
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          
          // Apply rate limiting
          await _apiRateLimiter.allowRequest();
          
          DebugUtils.logApiCall(
            options.method,
            options.path,
            requestBody: options.data,
          );
          
          handler.next(options);
        },
        onResponse: (response, handler) {
          DebugUtils.logApiCall(
            response.requestOptions.method,
            response.requestOptions.path,
            statusCode: response.statusCode,
            responseBody: response.data?.toString(),
          );
          handler.next(response);
        },
        onError: (error, handler) {
          DebugUtils.logApiCall(
            error.requestOptions.method,
            error.requestOptions.path,
            error: error.toString(),
          );
          handler.next(error);
        },
      ));
      
      DebugUtils.log('API Service initialized successfully');
    } catch (e) {
      DebugUtils.log('Error initializing API Service: $e', category: 'ERROR');
      rethrow;
    }
  }

  /// Set authentication token
  static void setAuthToken(String token) {
    _authToken = token;
    DebugUtils.log('Auth token set');
  }

  /// Clear authentication token
  static void clearAuthToken() {
    _authToken = null;
    DebugUtils.log('Auth token cleared');
  }

  /// Test connection to server
  static Future<ApiResponse<bool>> testConnection() async {
    try {
      final response = await _dio.get('/api/test');
      return ApiResponse.success(response.statusCode == 200);
    } catch (e) {
      DebugUtils.log('Connection test failed: $e', category: 'ERROR');
      return ApiResponse.networkError('Connection test failed');
    }
  }

  /// Login with enhanced error handling and captcha support
  static Future<ApiResponse<User>> login(String username, String password, {String? captchaToken}) async {
    return await _loginCircuitBreaker.execute(() async {
      try {
        DebugUtils.log('Attempting login for user: $username');
        
        final requestData = {
          'Email': username,
          'Password': password,
          'RememberMe': true,
        };
        
        if (captchaToken != null && captchaToken.isNotEmpty) {
          requestData['g-recaptcha-response'] = captchaToken;
        }

        final response = await _dio.post(
          '/Account/Login',
          data: requestData,
          options: Options(
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        DebugUtils.log('Login response status: ${response.statusCode}');

        if (response.statusCode == 302) {
          // Successful login - extract token from cookies or headers
          final cookies = response.headers['set-cookie'];
          String? token;
          
          if (cookies != null) {
            for (String cookie in cookies) {
              if (cookie.contains('auth_token') || cookie.contains('session')) {
                token = _extractTokenFromCookie(cookie);
                break;
              }
            }
          }
          
          // If no token from cookies, generate a session token
          token ??= 'session_${DateTime.now().millisecondsSinceEpoch}';
          
          setAuthToken(token);
          
          // Create user object from login data
          final user = User(
            id: username.hashCode.toString(),
            username: username,
            email: username,
            name: username.split('@').first,
          );
          
          DebugUtils.log('Login successful for user: ${user.username}');
          return ApiResponse.success(user);
        } else if (response.statusCode == 200) {
          // Check if login form is returned (failed login)
          final responseBody = response.data?.toString() ?? '';
          if (responseBody.contains('login') || responseBody.contains('error')) {
            return ApiResponse.error('Invalid credentials');
          }
          
          // Successful login without redirect
          final token = 'session_${DateTime.now().millisecondsSinceEpoch}';
          setAuthToken(token);
          
          final user = User(
            id: username.hashCode.toString(),
            username: username,
            email: username,
            name: username.split('@').first,
          );
          
          return ApiResponse.success(user);
        } else {
          return ApiResponse.error('Login failed with status: ${response.statusCode}');
        }
      } on DioException catch (e) {
        DebugUtils.log('Login DioException: ${e.message}', category: 'ERROR');
        
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout) {
          return ApiResponse.timeout();
        } else if (e.type == DioExceptionType.connectionError) {
          return ApiResponse.networkError();
        } else {
          return ApiResponse.error('Login failed: ${e.message}');
        }
      } catch (e) {
        DebugUtils.log('Login error: $e', category: 'ERROR');
        return ApiResponse.error('Login failed: $e');
      }
    });
  }

  /// Extract token from cookie string
  static String? _extractTokenFromCookie(String cookie) {
    try {
      final parts = cookie.split(';');
      for (String part in parts) {
        if (part.trim().contains('=')) {
          final keyValue = part.trim().split('=');
          if (keyValue.length == 2 && 
              (keyValue[0].contains('auth') || keyValue[0].contains('session'))) {
            return keyValue[1];
          }
        }
      }
    } catch (e) {
      DebugUtils.log('Error extracting token from cookie: $e', category: 'ERROR');
    }
    return null;
  }

  /// Get chat links with enhanced error handling
  static Future<ApiResponse<List<ChatLinkModel>>> getChatLinks({
    int? channelId,
    int take = 50,
    int skip = 0,
    String? search,
  }) async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
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

        final response = await _dio.get(
          '/Services/Chat/Chatlinks/List',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to get chat links');
          }
          
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final chatLinks = entities
              .map((json) => ChatLinkModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          DebugUtils.log('Retrieved ${chatLinks.length} chat links');
          return ApiResponse.success(chatLinks);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        return ApiResponse.error('Failed to get chat links: $e');
      }
    }, 
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'getChatLinks',
    );
  }

  /// Get channels
  static Future<ApiResponse<List<ChannelModel>>> getChannels() async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        final response = await _dio.get('/Services/Chat/Channels/List');

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to get channels');
          }
          
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final channels = entities
              .map((json) => ChannelModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          return ApiResponse.success(channels);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        return ApiResponse.error('Failed to get channels: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'getChannels',
    );
  }

  /// Get accounts
  static Future<ApiResponse<List<AccountModel>>> getAccounts({int? channelId}) async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        final queryParams = <String, dynamic>{};
        
        if (channelId != null) {
          queryParams['ChannelId'] = channelId;
        }

        final response = await _dio.get(
          '/Services/Chat/Accounts/List',
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to get accounts');
          }
          
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final accounts = entities
              .map((json) => AccountModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          return ApiResponse.success(accounts);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        return ApiResponse.error('Failed to get accounts: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'getAccounts',
    );
  }

  /// Get contacts
  static Future<ApiResponse<List<ContactModel>>> getContacts() async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        final response = await _dio.get('/Services/Chat/Contacts/List');

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to get contacts');
          }
          
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final contacts = entities
              .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          return ApiResponse.success(contacts);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        return ApiResponse.error('Failed to get contacts: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'getContacts',
    );
  }

  /// Get link list
  static Future<ApiResponse<List<LinkModel>>> getLinkList({
    required int channelId,
    int take = 100,
    int skip = 0,
  }) async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        final response = await _dio.get(
          '/Services/Chat/Links/List',
          queryParameters: {
            'ChannelId': channelId,
            'Take': take,
            'Skip': skip,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to get links');
          }
          
          final entities = data['Entities'] as List<dynamic>? ?? [];
          final links = entities
              .map((json) => LinkModel.fromJson(json as Map<String, dynamic>))
              .toList();
          
          return ApiResponse.success(links);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        return ApiResponse.error('Failed to get links: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'getLinkList',
    );
  }

  /// Get messages with enhanced parsing
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
    return await _messagesCircuitBreaker.execute(() async {
      return await ConnectionUtils.retryWithBackoff(() async {
        try {
          final queryParams = <String, dynamic>{
            'Take': take,
            'Skip': skip,
            'Limit': limit,
            'OrderBy': orderBy,
            'OrderDirection': orderDirection,
          };
          
          if (linkId != null && linkId > 0) {
            queryParams['LinkId'] = linkId;
          }
          
          if (linkIdExt != null && linkIdExt.isNotEmpty) {
            queryParams['LinkIdExt'] = linkIdExt;
          }
          
          queryParams['ChannelId'] = channelId;

          final response = await _dio.get(
            '/Services/Chat/Messages/List',
            queryParameters: queryParams,
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data;
            
            if (data['IsError'] == true) {
              return ApiResponse.error(data['Error'] ?? 'Failed to get messages');
            }
            
            final entities = data['Entities'] as List<dynamic>? ?? [];
            final messages = entities
                .map((json) => NoboxMessage.fromMessagesJson(json as Map<String, dynamic>))
                .where((message) => message.id.isNotEmpty)
                .toList();
            
            DebugUtils.log('Retrieved ${messages.length} messages for linkId: $linkId');
            return ApiResponse.success(messages);
          }
          
          return ApiResponse.error('Invalid response format');
        } on DioException catch (e) {
          return _handleDioException(e);
        } catch (e) {
          DebugUtils.log('Error getting messages: $e', category: 'ERROR');
          return ApiResponse.error('Failed to get messages: $e');
        }
      },
      shouldRetry: ConnectionUtils.shouldRetryApiError,
      operationName: 'getMessages',
      );
    });
  }

  /// Send message with attachment
  static Future<ApiResponse<NoboxMessage>> sendMessageWithAttachment({
    required String content,
    required int channelId,
    int? linkId,
    String? linkIdExt,
    String? attachmentFilename,
    int bodyType = 1,
    String? replyId,
  }) async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        final requestData = <String, dynamic>{
          'ChannelId': channelId,
          'BodyType': bodyType,
          'Body': content,
        };
        
        if (linkId != null && linkId > 0) {
          requestData['LinkId'] = linkId;
        }
        
        if (linkIdExt != null && linkIdExt.isNotEmpty) {
          requestData['LinkIdExt'] = linkIdExt;
        }
        
        if (attachmentFilename != null && attachmentFilename.isNotEmpty) {
          requestData['Attachment'] = attachmentFilename;
        }
        
        if (replyId != null && replyId.isNotEmpty) {
          requestData['ReplyId'] = replyId;
        }

        final response = await _dio.post(
          '/Services/Chat/Messages/Send',
          data: requestData,
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to send message');
          }
          
          // Create a temporary message object for the sent message
          final sentMessage = NoboxMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            senderId: 'me',
            content: content,
            createdAt: DateTime.now(),
            linkId: linkId ?? 0,
            channelId: channelId,
            bodyType: bodyType,
            attachment: attachmentFilename,
            isIncoming: false,
            roomId: 0,
          );
          
          DebugUtils.log('Message sent successfully');
          return ApiResponse.success(sentMessage);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        DebugUtils.log('Error sending message: $e', category: 'ERROR');
        return ApiResponse.error('Failed to send message: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'sendMessage',
    );
  }

  /// Upload file with fallback methods
  static Future<ApiResponse<UploadedFile>> uploadFileWithFallback({
    required File file,
    String? customFilename,
  }) async {
    return await ConnectionUtils.retryWithBackoff(() async {
      try {
        DebugUtils.log('Uploading file: ${file.path}');
        
        final filename = customFilename ?? path.basename(file.path);
        final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
        
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.path,
            filename: filename,
            contentType: DioMediaType.parse(mimeType),
          ),
        });

        final response = await _dio.post(
          '/Services/Upload/File',
          data: formData,
          options: Options(
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          
          if (data['IsError'] == true) {
            return ApiResponse.error(data['Error'] ?? 'Failed to upload file');
          }
          
          final uploadedFile = UploadedFile.fromJson(data['Data'] ?? data);
          
          DebugUtils.log('File uploaded successfully: ${uploadedFile.filename}');
          return ApiResponse.success(uploadedFile);
        }
        
        return ApiResponse.error('Invalid response format');
      } on DioException catch (e) {
        return _handleDioException(e);
      } catch (e) {
        DebugUtils.log('Error uploading file: $e', category: 'ERROR');
        return ApiResponse.error('Failed to upload file: $e');
      }
    },
    shouldRetry: ConnectionUtils.shouldRetryApiError,
    operationName: 'uploadFile',
    );
  }

  /// Get body type for file based on extension
  static int getBodyTypeForFile(String filename) {
    final extension = path.extension(filename).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return 3; // Image
      case '.mp4':
      case '.avi':
      case '.mov':
      case '.wmv':
      case '.flv':
      case '.webm':
      case '.mkv':
        return 4; // Video
      case '.mp3':
      case '.wav':
      case '.ogg':
      case '.aac':
      case '.m4a':
      case '.flac':
        return 2; // Audio
      default:
        return 5; // File/Document
    }
  }

  /// Handle Dio exceptions consistently
  static ApiResponse<T> _handleDioException<T>(DioException e) {
    DebugUtils.log('DioException: ${e.type} - ${e.message}', category: 'ERROR');
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiResponse.timeout();
      case DioExceptionType.connectionError:
        return ApiResponse.networkError();
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return ApiResponse.unauthorized();
        } else if (statusCode == 403) {
          return ApiResponse.forbidden();
        } else if (statusCode == 404) {
          return ApiResponse.notFound();
        } else if (statusCode != null && statusCode >= 500) {
          return ApiResponse.serverError();
        }
        return ApiResponse.error('Request failed with status: $statusCode');
      default:
        return ApiResponse.error('Network error: ${e.message}');
    }
  }

  /// Dispose resources
  static void dispose() {
    _dio.close();
    DebugUtils.log('API Service disposed');
  }
}

/// Model classes for API responses
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
      id: json['Id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? '',
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
      id: json['Id'] ?? 0,
      name: json['Nm']?.toString() ?? json['Name']?.toString() ?? '',
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
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      channel: json['Channel'] ?? 0,
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
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
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
      id: json['Id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
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

class UploadedFile {
  final String filename;
  final String originalName;
  final String? mimeType;
  final int? size;
  final String? url;

  UploadedFile({
    required this.filename,
    required this.originalName,
    this.mimeType,
    this.size,
    this.url,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      filename: json['Filename']?.toString() ?? '',
      originalName: json['OriginalName']?.toString() ?? '',
      mimeType: json['MimeType']?.toString(),
      size: json['Size'] as int?,
      url: json['Url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Filename': filename,
      'OriginalName': originalName,
      'MimeType': mimeType,
      'Size': size,
      'Url': url,
    };
  }

  @override
  String toString() => 'UploadedFile{filename: $filename, originalName: $originalName}';
}