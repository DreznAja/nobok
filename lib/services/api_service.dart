import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:nobox_mobile/services/link_resolver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'user_service.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

/// Generic API Response wrapper untuk semua endpoint
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? errorCode;
  final int? statusCode;
  final Map<String, dynamic>? metadata;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.errorCode,
    this.statusCode,
    this.metadata,
  });

  /// Factory constructor untuk response sukses
  factory ApiResponse.success(T data,
      {String? message, Map<String, dynamic>? metadata}) {
    return ApiResponse(
      success: true,
      data: data,
      message: message,
      statusCode: 200,
      metadata: metadata,
    );
  }

  /// Factory constructor untuk response error
  factory ApiResponse.error(
    String message, {
    String? errorCode,
    int? statusCode,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse(
      success: false,
      message: message,
      errorCode: errorCode,
      statusCode: statusCode ?? 400,
      metadata: metadata,
    );
  }

  /// Factory constructor untuk network error
  factory ApiResponse.networkError([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Network connection error',
      errorCode: 'NETWORK_ERROR',
      statusCode: 0,
    );
  }

  /// Factory constructor untuk timeout error
  factory ApiResponse.timeout([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Request timeout',
      errorCode: 'TIMEOUT_ERROR',
      statusCode: 408,
    );
  }

  /// Factory constructor untuk unauthorized error
  factory ApiResponse.unauthorized([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Unauthorized access',
      errorCode: 'UNAUTHORIZED',
      statusCode: 401,
    );
  }

  /// Factory constructor untuk forbidden error
  factory ApiResponse.forbidden([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Access forbidden',
      errorCode: 'FORBIDDEN',
      statusCode: 403,
    );
  }

  /// Factory constructor untuk not found error
  factory ApiResponse.notFound([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Resource not found',
      errorCode: 'NOT_FOUND',
      statusCode: 404,
    );
  }

  /// Factory constructor untuk server error
  factory ApiResponse.serverError([String? message]) {
    return ApiResponse(
      success: false,
      message: message ?? 'Internal server error',
      errorCode: 'SERVER_ERROR',
      statusCode: 500,
    );
  }

  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    try {
      final bool isSuccess = json['success'] == true ||
          json['Success'] == true ||
          json['IsError'] != true ||
          (json['code'] != null && json['code'] >= 200 && json['code'] < 300) ||
          (json['Code'] != null && json['Code'] >= 200 && json['Code'] < 300);

      T? data;
      final raw = json['data'] ?? json['Data'];
      if (isSuccess && raw != null && fromJsonT != null) {
        data = fromJsonT(raw);
      }

      return ApiResponse<T>(
        success: isSuccess,
        data: data,
        message: json['message']?.toString() ??
            json['Message']?.toString() ??
            json['error']?.toString() ??
            json['Error']?.toString(),
        errorCode: json['errorCode']?.toString() ??
            json['ErrorCode']?.toString() ??
            json['code']?.toString() ??
            json['Code']?.toString(),
        statusCode: (json['statusCode'] ??
            json['StatusCode'] ??
            json['code'] ??
            json['Code']) as int?,
        metadata: (json['metadata'] ?? json['Metadata']) is Map<String, dynamic>
            ? (json['metadata'] ?? json['Metadata']) as Map<String, dynamic>
            : null,
      );
    } catch (e) {
      return ApiResponse<T>.error('Failed to parse response: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data,
      'message': message,
      'errorCode': errorCode,
      'statusCode': statusCode,
      'metadata': metadata,
    };
  }

  /// Check if response is successful
  bool get isSuccess => success;

  /// Check if response is error
  bool get isError => !success;

  /// Check if error is network related
  bool get isNetworkError => errorCode == 'NETWORK_ERROR' || statusCode == 0;

  /// Check if error is timeout
  bool get isTimeoutError => errorCode == 'TIMEOUT_ERROR' || statusCode == 408;

  /// Check if error is authentication related
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  /// Check if error is client error (4xx)
  bool get isClientError =>
      statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Check if error is server error (5xx)
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Get user-friendly error message
  String get userMessage {
    if (success) return message ?? 'Success';

    switch (errorCode) {
      case 'NETWORK_ERROR':
        return 'Please check your internet connection';
      case 'TIMEOUT_ERROR':
        return 'Request timed out. Please try again';
      case 'UNAUTHORIZED':
        return 'Please login to continue';
      case 'FORBIDDEN':
        return 'You don\'t have permission to access this';
      case 'NOT_FOUND':
        return 'The requested resource was not found';
      case 'SERVER_ERROR':
        return 'Server is temporarily unavailable';
      default:
        return message ?? 'An error occurred';
    }
  }

  /// Transform data using a function
  ApiResponse<R> transform<R>(R Function(T) transformer) {
    if (!success || data == null) {
      return ApiResponse<R>(
        success: success,
        message: message,
        errorCode: errorCode,
        statusCode: statusCode,
        metadata: metadata,
      );
    }

    try {
      final transformedData = transformer(data!);
      return ApiResponse<R>(
        success: true,
        data: transformedData,
        message: message,
        statusCode: statusCode,
        metadata: metadata,
      );
    } catch (e) {
      return ApiResponse<R>.error('Data transformation failed: $e');
    }
  }

  /// Map data to another type
  ApiResponse<R> map<R>(R Function(T) mapper) {
    return transform(mapper);
  }

  /// Chain another API call if this one is successful
  Future<ApiResponse<R>> then<R>(
    Future<ApiResponse<R>> Function(T) next,
  ) async {
    if (!success || data == null) {
      return ApiResponse<R>(
        success: success,
        message: message,
        errorCode: errorCode,
        statusCode: statusCode,
        metadata: metadata,
      );
    }

    try {
      return await next(data!);
    } catch (e) {
      return ApiResponse<R>.error('Chained operation failed: $e');
    }
  }

  /// Fold the response into a single value
  R fold<R>(
    R Function(String error) onError,
    R Function(T data) onSuccess,
  ) {
    if (success && data != null) {
      return onSuccess(data!);
    } else {
      return onError(userMessage);
    }
  }

  @override
  String toString() {
    return 'ApiResponse{success: $success, data: $data, message: $message, errorCode: $errorCode, statusCode: $statusCode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiResponse<T> &&
        other.success == success &&
        other.data == data &&
        other.message == message &&
        other.errorCode == errorCode &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode {
    return success.hashCode ^
        data.hashCode ^
        message.hashCode ^
        errorCode.hashCode ^
        statusCode.hashCode;
  }
}

/// Paginated API Response
class PaginatedApiResponse<T> extends ApiResponse<List<T>> {
  final int? currentPage;
  final int? totalPages;
  final int? totalItems;
  final int? itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedApiResponse({
    required bool success,
    List<T>? data,
    String? message,
    String? errorCode,
    int? statusCode,
    Map<String, dynamic>? metadata,
    this.currentPage,
    this.totalPages,
    this.totalItems,
    this.itemsPerPage,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
  }) : super(
          success: success,
          data: data,
          message: message,
          errorCode: errorCode,
          statusCode: statusCode,
          metadata: metadata,
        );

  factory PaginatedApiResponse.success(
    List<T> data, {
    String? message,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    int? itemsPerPage,
    Map<String, dynamic>? metadata,
  }) {
    return PaginatedApiResponse(
      success: true,
      data: data,
      message: message,
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      itemsPerPage: itemsPerPage,
      hasNextPage:
          currentPage != null && totalPages != null && currentPage < totalPages,
      hasPreviousPage: currentPage != null && currentPage > 1,
      metadata: metadata,
    );
  }

  factory PaginatedApiResponse.error(
    String message, {
    String? errorCode,
    int? statusCode,
    Map<String, dynamic>? metadata,
  }) {
    return PaginatedApiResponse(
      success: false,
      message: message,
      errorCode: errorCode,
      statusCode: statusCode,
      metadata: metadata,
    );
  }

  factory PaginatedApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    try {
      final bool isSuccess = json['success'] == true ||
          json['Success'] == true ||
          json['IsError'] != true;

      List<T>? data;
      if (isSuccess) {
        final dataField =
            json['data'] ?? json['Data'] ?? json['items'] ?? json['Items'];
        if (dataField is List) {
          data = dataField.map((item) => fromJsonT(item)).toList();
        }
      }

      final pagination = json['pagination'] ?? json['Pagination'] ?? {};

      return PaginatedApiResponse(
        success: isSuccess,
        data: data,
        message: json['message']?.toString() ?? json['Message']?.toString(),
        errorCode:
            json['errorCode']?.toString() ?? json['ErrorCode']?.toString(),
        statusCode: json['statusCode'] ?? json['StatusCode'],
        currentPage: pagination['currentPage'] ?? pagination['CurrentPage'],
        totalPages: pagination['totalPages'] ?? pagination['TotalPages'],
        totalItems: pagination['totalItems'] ?? pagination['TotalItems'],
        itemsPerPage: pagination['itemsPerPage'] ?? pagination['ItemsPerPage'],
        hasNextPage:
            pagination['hasNextPage'] ?? pagination['HasNextPage'] ?? false,
        hasPreviousPage: pagination['hasPreviousPage'] ??
            pagination['HasPreviousPage'] ??
            false,
        metadata: json['metadata'] as Map<String, dynamic>? ??
            json['Metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      return PaginatedApiResponse.error(
          'Failed to parse paginated response: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['pagination'] = {
      'currentPage': currentPage,
      'totalPages': totalPages,
      'totalItems': totalItems,
      'itemsPerPage': itemsPerPage,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };
    return json;
  }

  @override
  String toString() {
    return 'PaginatedApiResponse{success: $success, items: ${data?.length ?? 0}, currentPage: $currentPage, totalPages: $totalPages, totalItems: $totalItems}';
  }
}

class ApiService {
  static const String baseUrl = 'https://id.nobox.ai';
  static String? _authToken;

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static String? get authToken => _authToken;

  // Timer untuk real-time polling
  static Timer? _messagePollingTimer;
  static StreamController<List<NoboxMessage>>? _messageStreamController;

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'NoboxFlutterApp/1.0'
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      print('🔥 Using auth token: ${_authToken?.substring(0, 20)}...');
    } else {
      print('🔥 No auth token available');
    }

    return headers;
  }

  Future<ApiResponse<Map<String, dynamic>>> postRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    final decoded = jsonDecode(response.body);
    final map = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    return ApiResponse.fromJson<Map<String, dynamic>>(
      map,
      (data) =>
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>?> getChatroomInfo(
      String linkIdExt, int channelId) async {
    final url = Uri.parse('$baseUrl/Chatroom/Info');
    final body = {
      "Take": 50,
      "Skip": 0,
      "EqualityFilter": {"CtIdExt": linkIdExt, "ChId": channelId}
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  /// ✅ FIXED: Smart upload with stream error fallback
  static Future<ApiResponse<UploadedFile>> uploadFileWithFallback({
    required File file,
    String? customFilename,
  }) async {
    try {
      final fileSize = await file.length();
      print('🔥 Upload file size: ${formatFileSize(fileSize)}');
      
      // For large files (>5MB) or known problematic formats, use base64 directly
      final filename = customFilename ?? file.path.split('/').last;
      final extension = filename.toLowerCase().split('.').last;
      final isLargeFile = fileSize > 5 * 1024 * 1024;
      final isProblematicFormat = ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'pdf', 'doc', 'docx'].contains(extension);
      
      if (isLargeFile || isProblematicFormat) {
        print('🔥 Using base64 upload for large/problematic file: $filename');
        return await uploadFileBase64(file: file, customFilename: customFilename);
      }
      
      // Try multipart first for smaller files
      try {
        print('🔥 Attempting multipart upload for: $filename');
        return await uploadFileMultipart(file: file, customFilename: customFilename);
      } catch (streamError) {
        print('🔥 Multipart failed, falling back to base64: $streamError');
        return await uploadFileBase64(file: file, customFilename: customFilename);
      }
    } catch (e) {
      print('🔥 Upload failed completely: $e');
      return ApiResponse.error('Upload failed: $e');
    }
  }

  static Future<ApiResponse<UploadedFile>> uploadFileBase64({
    required File file,
    String? customFilename,
  }) async {
    try {
      print('🔥 Uploading file via base64: ${file.path}');

      // Read file bytes
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);

      // Get filename and MIME type
      final filename = customFilename ?? file.path.split('/').last;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      print('🔥 File size: ${formatFileSize(bytes.length)}');
      print('🔥 MIME type: $mimeType');

      final requestBody = {
        'filename': filename,
        'mimetype': mimeType,
        'data': base64Data,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/Inbox/UploadFile/UploadBase64'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(
              const Duration(seconds: 120)); // Longer timeout for large files

      print('🔥 Upload response status: ${response.statusCode}');
      print('🔥 Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Error'] == null) {
          final uploadData = data['Data'];
          final uploadedFile = UploadedFile(
            filename: uploadData['Filename'] ?? filename,
            originalName: uploadData['OriginalName'] ?? filename,
          );

          print('🔥 File uploaded successfully: ${uploadedFile.filename}');
          return ApiResponse.success(uploadedFile);
        } else {
          return ApiResponse.error(data['Error'].toString());
        }
      } else {
        return _handleErrorResponse(response, 'Failed to upload file');
      }
    } catch (e) {
      print('🔥 Error uploading file: $e');
      return ApiResponse.error('Upload failed: $e');
    }
  }

  /// ✅ IMPROVED: Multipart upload with better stream handling
  static Future<ApiResponse<UploadedFile>> uploadFileMultipart({
    required File file,
    String? customFilename,
  }) async {
    try {
      print('🔥 Uploading file via multipart: ${file.path}');

      final filename = customFilename ?? file.path.split('/').last;
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
      final fileSize = await file.length();

      print('🔥 File: $filename, Size: ${formatFileSize(fileSize)}, MIME: $mimeType');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/Inbox/UploadFile/UploadFile'),
      );

      // Add headers
      request.headers.addAll(_headers);

      // ✅ FIXED: Better stream handling for multipart
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      print('🔥 Sending multipart request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Upload timeout', const Duration(seconds: 120));
        },
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      print('🔥 Upload response status: ${response.statusCode}');
      print('🔥 Upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Error'] == null) {
          final uploadData = data['Data'];
          final uploadedFile = UploadedFile(
            filename: uploadData['Filename'] ?? filename,
            originalName: uploadData['OriginalName'] ?? filename,
          );

          print('🔥 File uploaded successfully: ${uploadedFile.filename}');
          return ApiResponse.success(uploadedFile);
        } else {
          return ApiResponse.error(data['Error'].toString());
        }
      } else {
        return _handleErrorResponse(response, 'Failed to upload file');
      }
    } catch (e) {
      print('🔥 Error uploading file: $e');
      // Check if it's a stream error and suggest fallback
      if (e.toString().contains('stream') || e.toString().contains('Stream')) {
        throw Exception('STREAM_ERROR: $e');
      }
      return ApiResponse.error('Upload failed: $e');
    }
  }

  /// 🔥 Start real-time message polling - Enhanced version
  static Stream<List<NoboxMessage>> startMessagePolling({
    int? linkId,
    required int channelId,
    String? linkIdExt,
    Duration interval = const Duration(seconds: 3),
  }) {
    final channelIdToUse = 1;

    return Stream.periodic(interval).asyncMap((_) async {
      try {
        final response = await getMessages(
          linkId: linkId,
          channelId: channelIdToUse,
          linkIdExt: linkIdExt,
          take: 50,
          limit: 0,
          orderBy: '',
          orderDirection: '',
        );

        // ✅ Simple null check saja
        if (response != null) {
          return response.data ??
              <NoboxMessage>[]; // Return only the List<NoboxMessage>
        } else {
          return <NoboxMessage>[]; // Empty list
        }
      } catch (e) {
        print('🔥 Error polling messages: $e');
        return <NoboxMessage>[]; // Return empty list on error
      }
    });
  }

  /// 🔥 Stop real-time message polling
  static void stopMessagePolling() {
    _messagePollingTimer?.cancel();
    _messagePollingTimer = null;
    _messageStreamController?.close();
    _messageStreamController = null;
    print('🔥 Message polling stopped');
  }

static Future<ApiResponse<NoboxMessage>> sendMessageWithAttachment({
  required String content,
  required int channelId,
  required int linkId,
  required String linkIdExt,
  required String attachmentFilename,
  int bodyType = 5,
}) async {
  try {
    print('🔥 === SENDING MESSAGE WITH ATTACHMENT ===');
    print('🔥 Content: "$content"');
    print('🔥 BodyType: $bodyType');
    print('🔥 Attachment: $attachmentFilename');

    // ✅ FIXED: Proper content handling for different media types
    String messageContent = content;
    if (content.trim().isEmpty || content == '📷 Image' || content == '🎵 Audio' || content == '🎥 Video' || content == '📄 File') {
      // Set appropriate content based on bodyType
      switch (bodyType) {
        case 2:
          // ✅ CRITICAL: Check if it's a voice note
          if (attachmentFilename.toLowerCase().contains('voice') || 
              content.toLowerCase().contains('voice') ||
              content.contains('🎤')) {
            messageContent = content.isNotEmpty ? content : '🎤 Voice note';
          } else {
            messageContent = '🎵 Audio file';
          }
          break;
        case 3:
          messageContent = '📷 Image';
          break;
        case 4:
          messageContent = '🎥 Video';
          break;
        case 5:
        default:
          messageContent = '📎 File';
          break;
      }
    }

    print('🔥 Final content: "$messageContent"');

    // ✅ CRITICAL: Create proper attachment JSON with voice note detection
    String formattedAttachment;
    
    if (attachmentFilename.startsWith('{')) {
      formattedAttachment = attachmentFilename;
    } else {
      // Create proper attachment JSON with voice note flag
      final isVoiceNote = bodyType == 2 && (
        attachmentFilename.toLowerCase().contains('voice') ||
        content.toLowerCase().contains('voice') ||
        content.contains('🎤')
      );
      
      final attachmentData = {
        'Filename': attachmentFilename,
        'OriginalName': attachmentFilename.split('/').last,
        'IsVoiceNote': isVoiceNote, // Add voice note flag
        'BodyType': bodyType,
      };
      formattedAttachment = jsonEncode(attachmentData);
      print('🔥 Created attachment JSON: $formattedAttachment');
    }

    return await sendMessage(
      content: messageContent,
      channelId: channelId,
      linkId: linkId,
      linkIdExt: linkIdExt,
      bodyType: bodyType,
      attachment: formattedAttachment,
    );
  } catch (e) {
    print('🔥 Error sending message with attachment: $e');
    return ApiResponse.error('Failed to send message with attachment: $e');
  }
}

  /// ✅ IMPROVED: Pick and upload file with smart fallback
  static Future<ApiResponse<UploadedFile>> pickAndUploadFile({
    FileType fileType = FileType.any,
    List<String>? allowedExtensions,
    bool useBase64 = false,
  }) async {
    try {
      print('🔥 Picking file with type: $fileType');

      // Request appropriate permissions
      final hasPermission = await _requestFilePermissions(
        fileType: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (!hasPermission) {
        return ApiResponse.error(
            'Storage permission is required to select files. Please grant permission in app settings.',
            errorCode: 'PERMISSION_DENIED');
      }

      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return ApiResponse.error('No file selected');
      }

      final file = File(result.files.single.path!);

      // Check file size (limit to 25MB for videos, 10MB for others)
      final fileSize = await file.length();
      final maxSize = fileType == FileType.video ? 25 * 1024 * 1024 : 10 * 1024 * 1024;
      
      if (fileSize > maxSize) {
        final maxSizeStr = formatFileSize(maxSize);
        return ApiResponse.error('File too large. Maximum size is $maxSizeStr');
      }

      print('🔥 Selected file: ${file.path}');
      print('🔥 File size: ${formatFileSize(fileSize)}');

      // ✅ FIXED: Use smart upload with fallback
      if (useBase64) {
        return await uploadFileBase64(file: file);
      } else {
        return await uploadFileWithFallback(file: file);
      }
    } catch (e) {
      print('🔥 Error picking/uploading file: $e');

      if (e.toString().contains('Permission denied') ||
          e.toString().contains('permission')) {
        return ApiResponse.error(
            'Permission denied. Please enable storage access in your device settings.',
            errorCode: 'PERMISSION_ERROR');
      }

      return ApiResponse.error('File operation failed: $e');
    }
  }

  static Future<ApiResponse<UploadedFile>> pickAndUploadImage({
    required ImageSource source,
    bool useBase64 = false,
  }) async {
    try {
      print('🔥 Picking image from: $source');

      // Request appropriate permission
      bool hasPermission = false;

      if (source == ImageSource.camera) {
        hasPermission = await _requestCameraPermission();
      } else {
        // For gallery, use file permissions with image type
        hasPermission = await _requestFilePermissions(fileType: FileType.image);
      }

      if (!hasPermission) {
        final permissionType =
            source == ImageSource.camera ? 'Camera' : 'Photo';
        return ApiResponse.error(
            '$permissionType permission is required. Please grant permission in app settings.',
            errorCode: 'PERMISSION_DENIED');
      }

      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image == null) {
        return ApiResponse.error('No image selected');
      }

      final file = File(image.path);
      print('🔥 Selected image: ${file.path}');

      // ✅ FIXED: Use smart upload with fallback
      if (useBase64) {
        return await uploadFileBase64(file: file);
      } else {
        return await uploadFileWithFallback(file: file);
      }
    } catch (e) {
      print('🔥 Error picking/uploading image: $e');

      if (e.toString().contains('Permission denied') ||
          e.toString().contains('permission')) {
        return ApiResponse.error(
            'Permission denied. Please enable camera/photo access in your device settings.',
            errorCode: 'PERMISSION_ERROR');
      }

      return ApiResponse.error('Image operation failed: $e');
    }
  }

  static int getBodyTypeForFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
        return 3; // Image
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
      case 'mkv':
        return 4; // Video
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'aac':
      case 'm4a':
      case 'flac':
        return 2; // Audio
      default:
        return 5; // File
    }
  }

  /// Get file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 🔥 Internal method untuk polling messages
  static Future<void> _pollMessages({
    int? linkId,
    int? channelId,
    String? linkIdExt,
  }) async {
    try {
      final response = await getMessages(
        linkId: linkId,
        channelId: channelId,
        linkIdExt: linkIdExt,
        limit: 0,
        orderBy: '',
        orderDirection: '',
      );

      if (response.success &&
          _messageStreamController != null &&
          !_messageStreamController!.isClosed) {
        _messageStreamController!.add(response.data ?? []);
      }
    } catch (e) {
      print('🔥 Error polling messages: $e');
      // Don't close the stream on error, just log it
    }
  }

  /// 🔥 Login endpoint
// 🔥 PERBAIKAN Login untuk memastikan user data yang konsisten

  static Future<ApiResponse<User>> login(String username, String password,
      {String? captchaToken}) async {
    try {
      print('🔥 Attempting login to: $baseUrl/AccountAPI/GenerateToken');

      final Map<String, dynamic> requestBody = {
        'username': username,
        'password': password,
      };

      if (captchaToken != null && captchaToken.isNotEmpty) {
        requestBody['recaptchaToken'] = captchaToken;
        print('🔥 Including reCAPTCHA token in request');
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/AccountAPI/GenerateToken'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Response status: ${response.statusCode}');
      print('🔥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return ApiResponse.error('Server returned empty response');
        }

        try {
          final data = jsonDecode(response.body);
          String? token = data['token']?.toString();
          if (token != null && token.isNotEmpty) {
            setAuthToken(token);
            print('🔥 Login successful, token set');

            // ✅ PERBAIKAN: Extract user data dengan prioritas yang benar
            // In the login method after successful authentication:
            String userId = data['userId']?.toString() ??
                data['accountId']?.toString() ??
                data['id']?.toString() ??
                username; // Use username as fallback ID

            String userName = data['name']?.toString() ??
                data['displayName']?.toString() ??
                data['fullName']?.toString() ??
                username;

// 🔑 CRITICAL: Set current user with correct data
            await UserService.setCurrentUser(
              userId: userId, // Will be used for senderId comparison
              username: username, // Login username (email)
              name: userName, // Display name
            );
            // 🔥 TAMBAHAN: Validate bahwa user data sudah benar
            if (!UserService.validateCurrentUserData()) {
              print('⚠️ Warning: User data validation failed after login');
              UserService.debugLogCurrentUser();
            } else {
              print('✅ User data validation passed');
              UserService.debugLogCurrentUser();
            }

            final user = User(
              id: userId,
              username: username,
              email: username,
              name: userName,
            );

            print('🔥 User identity saved successfully');
            print('🔥 - ID: $userId');
            print('🔥 - Username: $username');
            print('🔥 - Display Name: $userName');
            print('🔥 - Will show as: Me ($userName)');

            return ApiResponse.success(user);
          } else {
            return ApiResponse.error('Token not found in response');
          }
        } catch (parseError) {
          print('🔥 JSON Parse Error: $parseError');
          return ApiResponse.error('Invalid response format from server');
        }
      } else if (response.statusCode == 400) {
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData['Error'] != null) {
              final error = errorData['Error'];
              String errorMessage = error['Message'] ?? 'Authentication failed';
              String? errorCode = error['Code'];

              if (errorCode == 'CaptchaRequired' || errorCode == 'Recaptcha') {
                print('🔥 reCAPTCHA validation required');
                return ApiResponse.error(
                  'Please complete the security verification.',
                  errorCode: 'CAPTCHA_REQUIRED',
                );
              }

              print('🔥 Login failed: $errorMessage');
              return ApiResponse.error(errorMessage);
            }
          }
          return ApiResponse.error('Invalid username or password');
        } catch (parseError) {
          return ApiResponse.error('Invalid username or password');
        }
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Invalid username or password');
      } else {
        return _handleErrorResponse(response, 'Login failed');
      }
    } catch (e) {
      print('🔥 Unexpected error: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }

  static Future<bool> _requestFilePermissions({
    FileType fileType = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (!Platform.isAndroid) {
      return true; // iOS handles permissions automatically
    }

    // Get Android version info
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final androidVersion = androidInfo.version.sdkInt;

    print('🔥 Android SDK version: $androidVersion');

    List<Permission> permissionsToRequest = [];

    if (androidVersion >= 33) {
      // Android 13+ (API 33+) - Use granular media permissions
      switch (fileType) {
        case FileType.image:
          permissionsToRequest.add(Permission.photos);
          break;
        case FileType.video:
          permissionsToRequest.add(Permission.videos);
          break;
        case FileType.audio:
          permissionsToRequest.add(Permission.audio);
          break;
        case FileType.any:
        case FileType.custom:
        default:
          // For general files, we need multiple permissions
          permissionsToRequest.addAll([
            Permission.photos,
            Permission.videos,
            Permission.audio,
          ]);
          break;
      }
    } else if (androidVersion >= 30) {
      // Android 11+ (API 30+) - Use MANAGE_EXTERNAL_STORAGE for broader access
      permissionsToRequest.add(Permission.manageExternalStorage);

      // Fallback to storage if manage external storage is denied
      if (!(await Permission.manageExternalStorage.isGranted)) {
        permissionsToRequest.add(Permission.storage);
      }
    } else {
      // Android 10 and below - Use legacy storage permission
      permissionsToRequest.add(Permission.storage);
    }

    print(
        '🔥 Requesting permissions: ${permissionsToRequest.map((p) => p.toString()).join(', ')}');

    // Request permissions
    Map<Permission, PermissionStatus> statuses = {};

    for (Permission permission in permissionsToRequest) {
      final status = await permission.request();
      statuses[permission] = status;
      print('🔥 Permission $permission: $status');
    }

    // Check if we have at least one granted permission
    final hasAnyGranted = statuses.values.any((status) =>
        status == PermissionStatus.granted ||
        status == PermissionStatus.limited);

    if (!hasAnyGranted) {
      // Show explanation dialog if permissions were denied
      final hasPermanentlyDenied = statuses.values
          .any((status) => status == PermissionStatus.permanentlyDenied);

      if (hasPermanentlyDenied) {
        print('🔥 Permissions permanently denied - directing to settings');
        return await _showPermissionDialog();
      } else {
        print('🔥 Permissions denied');
        return false;
      }
    }

    print('🔥 File permissions granted successfully');
    return true;
  }

  static Future<bool> _requestCameraPermission() async {
    final permission = Permission.camera;
    final status = await permission.request();

    print('🔥 Camera permission: $status');

    if (status == PermissionStatus.granted) {
      return true;
    } else if (status == PermissionStatus.permanentlyDenied) {
      return await _showPermissionDialog(isCamera: true);
    }

    return false;
  }

  static Future<bool> _showPermissionDialog({bool isCamera = false}) async {
    // This would need to be called from a widget context
    // For now, we'll just open settings
    final opened = await openAppSettings();
    print('🔥 Settings opened: $opened');
    return false; // Return false as user needs to manually grant permission
  }

  /// 🔥 Get Contact List
  static Future<ApiResponse<List<ContactModel>>> getContactList(
      {int take = 50, int skip = 0, int? limit}) async {
    try {
      print('🔥 Getting contact list...');

      final requestBody = {
        'IncludeColumns': ['Id', 'Name'],
        'ColumnSelection': 1,
        'Take': take,
        'Skip': skip,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Nobox/Contact/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Contact list response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          final contacts =
              entities.map((json) => ContactModel.fromJson(json)).toList();
          return ApiResponse.success(contacts);
        } else {
          return ApiResponse.success([]);
        }
      } else {
        return _handleErrorResponse(response, 'Failed to get contacts');
      }
    } catch (e) {
      print('🔥 Error getting contacts: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// ✅ NEW: Get Link List - Specific method untuk fetch links sebagai contact options
  static Future<ApiResponse<List<LinkModel>>> getLinkList({
    int? channelId,
    int take = 50,
    int skip = 0,
  }) async {
    try {
      print('🔥 Getting link list for channel: $channelId...');

      final Map<String, dynamic> requestBody = {
        'IncludeColumns': ['Id', 'IdExt', 'Name'],
        'ColumnSelection': 1,
        'Take': take,
        'Skip': skip,
      };

      if (channelId != null) {
        requestBody['EqualityFilter'] = {'ChId': channelId};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatlinkcontacts/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Link list response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          final links = entities.map((json) => LinkModel.fromJson(json)).toList();
          print('🔥 Successfully got ${links.length} links');
          return ApiResponse.success(links);
        } else {
          return ApiResponse.success([]);
        }
      } else {
        return _handleErrorResponse(response, 'Failed to get links');
      }
    } catch (e) {
      print('🔥 Error getting links: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// 🔥 Get Chat Links
  static Future<ApiResponse<List<ChatLinkModel>>> getChatLinks({
    int? channelId,
    int? contactId,
    int take = 50,
    int skip = 0,
  }) async {
    try {
      print('🔥 Getting chat links...');

      final Map<String, dynamic> requestBody = {
        'IncludeColumns': ['Id', 'IdExt', 'Name'],
        'ColumnSelection': 1,
        'Take': take,
        'Skip': skip,
      };

      final Map<String, dynamic> equalityFilter = <String, dynamic>{};
      if (contactId != null) {
        equalityFilter['CtId'] = contactId;
      }
      if (channelId != null) {
        equalityFilter['ChId'] = channelId;
      }
      if (equalityFilter.isNotEmpty) {
        requestBody['EqualityFilter'] = equalityFilter;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatlinkcontacts/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Chat links response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          final chatLinks =
              entities.map((json) => ChatLinkModel.fromJson(json)).toList();
          print('🔥 Successfully got ${chatLinks.length} chat links');
          return ApiResponse.success(chatLinks);
        } else {
          return ApiResponse.success([]);
        }
      } else {
        return _handleErrorResponse(response, 'Failed to get chat links');
      }
    } catch (e) {
      print('🔥 Error getting chat links: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  static Future<ApiResponse<List<NoboxMessage>>> getMessages({
    int? linkId,
    int? channelId,
    String? linkIdExt,
    int take = 50,
    int skip = 0,
    required int limit,
    required String orderBy,
    required String orderDirection,
  }) async {
    try {
      // Use Channel ID 1 as default
      final channelIdToUse = channelId ?? 1;
      print(
          '🔥 Getting messages for LinkId: $linkId, ChannelId: $channelIdToUse, LinkIdExt: $linkIdExt');

      // Step 1: Find chatroom first to get RoomId
      print('🔥 Step 1: Finding chatroom with original parameters');
      final chatroomResponse = await _getChatroomInfo(
        linkId: linkId,
        channelId: channelIdToUse,
        linkIdExt: linkIdExt,
      );

      int? roomId;
      if (chatroomResponse.success &&
          chatroomResponse.data != null &&
          chatroomResponse.data!.isNotEmpty) {
        roomId = chatroomResponse.data!.first['Id'];
        print('🔥 Found RoomId: $roomId');
      } else {
        print('🔥 Chatroom not found, trying alternative parameters');

        // Try with ChannelId only
        final altResponse1 = await _getChatroomInfo(channelId: channelIdToUse);
        if (altResponse1.success &&
            altResponse1.data != null &&
            altResponse1.data!.isNotEmpty) {
          roomId = altResponse1.data!.first['Id'];
          print('🔥 Found RoomId with ChannelId: $roomId');
        } else if (linkIdExt != null && linkIdExt.isNotEmpty) {
          // Try with LinkIdExt only
          final altResponse2 = await _getChatroomInfo(linkIdExt: linkIdExt);
          if (altResponse2.success &&
              altResponse2.data != null &&
              altResponse2.data!.isNotEmpty) {
            roomId = altResponse2.data!.first['Id'];
            print('🔥 Found RoomId with LinkIdExt: $roomId');
          }
        }
      }

      if (roomId == null) {
        print('🔥 Cannot find RoomId for given parameters');
        return ApiResponse.success(
          <NoboxMessage>[],
          message: 'Cannot find chatroom for given parameters',
        );
      }

      // Step 2: Get messages using correct endpoint
      print('🔥 Step 2: Getting messages with RoomId: $roomId');

      final Map<String, dynamic> requestBody = {
        'Take': take,
        'Skip': skip,
        'EqualityFilter': {
          'RoomId': roomId,
        },
      };

      // FIXED: Remove OrderBy field - backend doesn't support it
      // The messages will be returned in their natural order from the database
      // We'll handle sorting on the client side after receiving the data

      print('🔥 Request body for messages: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatmessages/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      print('🔥 Messages response status: ${response.statusCode}');
      print('🔥 Messages response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Error'] != null) {
          print('🔥 Backend returned error: ${data['Error']}');
          return ApiResponse.error(data['Error'].toString());
        }

        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          print('🔥 Found ${entities.length} messages');

          final messages = entities.map((json) {
            try {
              return NoboxMessage.fromMessagesJson(json);
            } catch (e) {
              print('🔥 Error parsing message: $e');
              print('🔥 Message JSON: $json');
              // Return fallback message
              return NoboxMessage(
                id: json['Id']?.toString() ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                senderId: json['SenderId']?.toString() ?? 'Unknown',
                content: json['Content']?.toString() ??
                    json['Body']?.toString() ??
                    'Message could not be parsed',
                createdAt: json['CreatedAt'] != null
                    ? DateTime.tryParse(json['CreatedAt'].toString()) ??
                        DateTime.now()
                    : DateTime.now(),
                linkId: linkId ?? 0,
                channelId: channelIdToUse,
                bodyType: json['BodyType'] ?? 1,
                roomId: 0,
              );
            }
          }).toList();

          // CLIENT-SIDE SORTING: Handle sorting based on parameters
          if (orderBy.isNotEmpty && orderDirection.isNotEmpty) {
            if (orderBy.toLowerCase() == 'createdat' ||
                orderBy.toLowerCase() == 'createddt') {
              if (orderDirection.toLowerCase() == 'desc') {
                messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                print('🔥 Messages sorted: newest first (desc)');
              } else {
                messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                print('🔥 Messages sorted: oldest first (asc)');
              }
            } else if (orderBy.toLowerCase() == 'id') {
              if (orderDirection.toLowerCase() == 'desc') {
                messages.sort((a, b) => b.id.compareTo(a.id));
              } else {
                messages.sort((a, b) => a.id.compareTo(b.id));
              }
            }
          } else {
            // Default sorting: newest first
            messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            print('🔥 Messages sorted: newest first (default)');
          }

          print('🔥 Successfully loaded ${messages.length} messages');
          if (messages.isNotEmpty) {
            print(
                '🔥 First message (newest): ${messages.first.content} at ${messages.first.createdAt}');
            if (messages.length > 1) {
              print(
                  '🔥 Last message (oldest): ${messages.last.content} at ${messages.last.createdAt}');
            }
          }

          return ApiResponse.success(messages);
        } else {
          print('🔥 No messages found');
          return ApiResponse.success(<NoboxMessage>[]);
        }
      } else {
        print('🔥 Failed to get messages: ${response.statusCode}');
        return _handleErrorResponse(response, 'Failed to get messages');
      }
    } catch (e) {
      print('🔥 Error getting messages: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// 🔥 Helper method untuk mendapatkan info chatroom
  static Future<ApiResponse<List<Map<String, dynamic>>>> _getChatroomInfo({
    int? linkId,
    int? channelId,
    String? linkIdExt,
    int take = 50,
    int skip = 0,
  }) async {
    try {
      print(
          '🔥 Mencari chatroom info dengan LinkId: $linkId, ChannelId: $channelId, LinkIdExt: $linkIdExt');

      final Map<String, dynamic> requestBody = {
        'Take': take,
        'Skip': skip,
      };

      final Map<String, dynamic> equalityFilter = <String, dynamic>{};

      if (linkId != null && linkId > 0) {
        equalityFilter['CtId'] = linkId;
        print('🔥 Menambahkan CtId: $linkId');
      }
      if (linkIdExt != null && linkIdExt.isNotEmpty && linkIdExt != '0') {
        equalityFilter['CtIdExt'] = linkIdExt;
        print('🔥 Menambahkan CtIdExt: $linkIdExt');
      }
      if (channelId != null && channelId > 0) {
        equalityFilter['ChId'] = channelId;
        print('🔥 Menambahkan ChId: $channelId');
      }

      if (equalityFilter.isNotEmpty) {
        requestBody['EqualityFilter'] = equalityFilter;
      }

      print('🔥 Request body untuk chatroom: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatrooms/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Response chatroom info: ${response.statusCode}');
      print('🔥 Response body chatroom: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          print('🔥 Ditemukan ${entities.length} record chatroom');

          if (entities.isNotEmpty) {
            for (int i = 0; i < entities.length; i++) {
              print('🔥 Chatroom $i: ${entities[i]}');
            }
          }

          return ApiResponse.success(entities.cast<Map<String, dynamic>>());
        } else {
          return ApiResponse.success(<Map<String, dynamic>>[]);
        }
      } else {
        return _handleErrorResponse(
            response, 'Gagal mendapatkan info chatroom');
      }
    } catch (e) {
      print('🔥 Error mendapatkan info chatroom: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  static Future<String?> fetchFirstAccountId(int channelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Services/Nobox/Account/List'),
        headers: _headers,
        body: jsonEncode({
          "IncludeColumns": ["Id", "Name", "Channel"],
          "ColumnSelection": 1,
          "EqualityFilter": {"Channel": channelId},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entities = data['Entities'] as List<dynamic>?;
        if (entities != null && entities.isNotEmpty) {
          return entities.first['Id'].toString(); // ambil AccountId pertama
        }
      }
      return null;
    } catch (e) {
      print("🔥 fetchFirstAccountId error: $e");
      return null;
    }
  }

// 🔥 ApiService.dart

  static Future<String?> _fetchAccountId(int channelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Services/Nobox/Account/List'),
        headers: _headers,
        body: jsonEncode({
          "EqualityFilter": {"Channel": channelId},
          "IncludeColumns": ["Id", "Name", "Channel"],
          "ColumnSelection": 1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entities = data['Entities'] as List?;
        if (entities != null && entities.isNotEmpty) {
          return entities[0]['Id'].toString(); // ambil AccountId pertama
        }
      }
      return null;
    } catch (e) {
      print("🔥 Error fetchAccountId: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _fetchAccountIdWithFallback(
      int channelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Services/Nobox/Account/List'),
        headers: _headers,
        body: jsonEncode({
          "EqualityFilter": {"Channel": channelId},
          "IncludeColumns": ["Id", "Name", "Channel"],
          "ColumnSelection": 1
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entities = data['Entities'] as List?;
        if (entities != null && entities.isNotEmpty) {
          return {
            'channelId': channelId, // 🔥 tetap integer
            'accountId':
                entities[0]['Id'].toString(), // 🔥 string sesuai backend
          };
        } else if (channelId != 1) {
          print(
              "⚠️ No AccountIds for channel $channelId → fallback ke channel 1");
          return await _fetchAccountIdWithFallback(1);
        }
      }
      return null;
    } catch (e) {
      print("🔥 Error fetchAccountIdWithFallback: $e");
      return null;
    }
  }

// 🔥 PERBAIKAN UTAMA: Pastikan sendMessage menggunakan user info yang konsisten

static Future<ApiResponse<NoboxMessage>> sendMessage({
  required String content,
  required int channelId,
  required int linkId,
  int bodyType = 1,
  String? attachment,
  required String linkIdExt,
}) async {
  try {
    print('🔥 === SEND MESSAGE START ===');
    print('🔥 Content: "$content"');
    print('🔥 BodyType: $bodyType');
    print('🔥 Attachment: $attachment');

    if (!UserService.isLoggedIn) {
      return ApiResponse.error('User not logged in', errorCode: 'NOT_LOGGED_IN');
    }

    String? accountId = await _fetchAccountId(channelId);
    if (accountId == null) {
      print('⚠️ No AccountIds for channel $channelId → fallback ke channel 1');
      accountId = await _fetchAccountId(1);
    }
    if (accountId == null) {
      return ApiResponse.error('❌ No AccountIds available', errorCode: 'NO_ACCOUNT_ID');
    }

    final requestBody = {
      'ChannelId': channelId,
      'LinkId': linkId,
      'AccountIds': accountId,
      'BodyType': bodyType,
      'Body': content.isEmpty ? ' ' : content, // Use space if empty to avoid server issues
    };

    if (attachment != null && attachment.isNotEmpty) {
      requestBody['Attachment'] = attachment;
      print('🔥 Added attachment: $attachment');
    }

    print('🔥 Request body: ${jsonEncode(requestBody)}');

    final response = await http
        .post(
          Uri.parse('$baseUrl/Inbox/Send'),
          headers: _headers,
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 15));

    print('🔥 Send response status: ${response.statusCode}');
    print('🔥 Send response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData['IsError'] == true) {
        final errorMessage = responseData['Error']?.toString();
        return ApiResponse.error(errorMessage ?? 'Unknown backend error');
      }

      final currentUserId = UserService.currentUserId!;
      final currentUserName = UserService.currentUserName ??
          UserService.currentUsername ??
          'User';

      // Ambil timestamp dari server kalau ada
      final serverCreatedAt = responseData['CreatedAt'] != null
          ? DateTime.parse(responseData['CreatedAt']).toLocal()
          : DateTime.now().toLocal();

      final sentMessage = NoboxMessage(
        id: responseData['MessageId']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: currentUserId,
        content: content,
        createdAt: serverCreatedAt,
        linkId: linkId,
        channelId: channelId,
        bodyType: bodyType,
        attachment: attachment, // This is crucial - make sure attachment is preserved
        roomId: 0,
        isIncoming: false,
        senderName: currentUserName,
        ack: 1,
      );

      print('🔥 Created sent message with attachment: ${sentMessage.attachment}');
      return ApiResponse.success(sentMessage, message: 'Message sent');
    }

    return ApiResponse.error('Failed with status ${response.statusCode}');
  } catch (e) {
    return ApiResponse.error('Exception: $e');
  }
}


  /// Helper untuk recovery dan retry
  static Future<ApiResponse<NoboxMessage>> _recoverAndRetry({
    required String content,
    required int channelId,
    int bodyType = 1,
    String? attachment,
    String? accountIds,
    String? linkIdExt,
  }) async {
    try {
      print('🔥 === RECOVERY ATTEMPT ===');

      // Fetch fresh LinkId
      final newLinkId = await _fetchValidLinkId(channelId, linkIdExt);
      if (newLinkId == null) {
        return ApiResponse.error(
            'Session recovery failed. Please refresh chat list and try again.',
            errorCode: 'RECOVERY_FAILED');
      }

      print('🔥 Recovery got new LinkId: $newLinkId');

      // Update cache
      if (linkIdExt != null && linkIdExt.isNotEmpty) {
        LinkResolver.seedOne(linkIdExt: linkIdExt, linkId: newLinkId);
      }

      // Retry dengan LinkId baru
      final retryBody = {
        'ChannelId': channelId,
        'BodyType': bodyType,
        'Body': content,
        'LinkId': newLinkId,
      };

      if (accountIds != null && accountIds.isNotEmpty) {
        retryBody['AccountIds'] = accountIds;
      }
      if (attachment != null && attachment.isNotEmpty) {
        retryBody['Attachment'] = attachment;
      }

      print('🔥 Retry request body: ${jsonEncode(retryBody)}');

      final retryResponse = await http
          .post(
            Uri.parse('$baseUrl/Inbox/Send'),
            headers: _headers,
            body: jsonEncode(retryBody),
          )
          .timeout(const Duration(seconds: 15));

      print('🔥 Retry response status: ${retryResponse.statusCode}');
      print('🔥 Retry response body: ${retryResponse.body}');

      if (retryResponse.statusCode == 200) {
        final retryData = jsonDecode(retryResponse.body);

        if (retryData['IsError'] != true) {
          print('🔥 Recovery successful!');
          return ApiResponse.success(
            NoboxMessage(
              id: retryData['MessageId']?.toString() ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              senderId: 'me',
              content: content,
              createdAt: DateTime.now(),
              linkId: newLinkId,
              channelId: channelId,
              bodyType: bodyType,
              attachment: attachment,
              roomId: 0,
            ),
            message: 'Message sent (after recovery)',
          );
        }
      }

      return ApiResponse.error(
          'Message sending failed even after recovery. Please try again later.',
          errorCode: 'RETRY_FAILED');
    } catch (e) {
      print('🔥 Recovery exception: $e');
      return ApiResponse.error('Recovery failed: $e',
          errorCode: 'RECOVERY_ERROR');
    }
  }

  /// Helper untuk fetch valid LinkId
  static Future<int?> _fetchValidLinkId(
      int channelId, String? linkIdExt) async {
    try {
      print(
          '🔥 Fetching valid LinkId for ChannelId: $channelId, LinkIdExt: $linkIdExt');

      // Strategy 1: Gunakan Chatlinkcontacts endpoint
      final requestBody = {
        'IncludeColumns': ['Id', 'IdExt'],
        'ColumnSelection': 1,
        'Take': 50,
        'Skip': 0,
        'EqualityFilter': {'ChId': channelId}
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatlinkcontacts/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Chatlinkcontacts response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null && data['Entities'] is List) {
          final entities = data['Entities'] as List;

          if (entities.isNotEmpty) {
            // Jika ada LinkIdExt, cari yang matching
            if (linkIdExt != null && linkIdExt.isNotEmpty) {
              for (final entity in entities) {
                if (entity['IdExt']?.toString() == linkIdExt) {
                  final linkId = int.tryParse(entity['Id']?.toString() ?? '');
                  if (linkId != null) {
                    print(
                        '🔥 Found matching LinkId: $linkId for LinkIdExt: $linkIdExt');
                    return linkId;
                  }
                }
              }
            }

            // Fallback: ambil entity pertama
            final firstEntity = entities.first;
            final linkId = int.tryParse(firstEntity['Id']?.toString() ?? '');
            if (linkId != null) {
              print('🔥 Using first available LinkId: $linkId');
              return linkId;
            }
          }
        }
      }

      // Strategy 2: Coba endpoint Chatrooms
      final chatroomBody = {
        'Take': 50,
        'Skip': 0,
        'EqualityFilter': {'ChId': channelId}
      };

      final chatroomResponse = await http
          .post(
            Uri.parse('$baseUrl/Services/Chat/Chatrooms/List'),
            headers: _headers,
            body: jsonEncode(chatroomBody),
          )
          .timeout(const Duration(seconds: 10));

      if (chatroomResponse.statusCode == 200) {
        final chatroomData = jsonDecode(chatroomResponse.body);
        if (chatroomData['Entities'] != null &&
            chatroomData['Entities'] is List) {
          final entities = chatroomData['Entities'] as List;
          if (entities.isNotEmpty) {
            final firstEntity = entities.first;
            final linkId = int.tryParse(firstEntity['CtId']?.toString() ?? '');
            if (linkId != null) {
              print('🔥 Found LinkId from Chatrooms: $linkId');
              return linkId;
            }
          }
        }
      }

      print('🔥 Failed to fetch valid LinkId');
      return null;
    } catch (e) {
      print('🔥 Error fetching LinkId: $e');
      return null;
    }
  }

  /// 🔥 Get Channels
  static Future<ApiResponse<List<ChannelModel>>> getChannels() async {
    try {
      print('🔥 Getting channels...');

      final requestBody = {
        'IncludeColumns': ['Id', 'Nm'],
        'ColumnSelection': 1,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Master/Channel/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Channels response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          final channels =
              entities.map((json) => ChannelModel.fromJson(json)).toList();
          return ApiResponse.success(channels);
        } else {
          return ApiResponse.success([]);
        }
      } else {
        return _handleErrorResponse(response, 'Failed to get channels');
      }
    } catch (e) {
      print('🔥 Error getting channels: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// 🔥 Get Accounts
  static Future<ApiResponse<List<AccountModel>>> getAccounts(
      {int? channelId}) async {
    try {
      print('🔥 Getting accounts...');

      final Map<String, dynamic> requestBody = {
        'IncludeColumns': ['Id', 'Name', 'Channel'],
        'ColumnSelection': 1,
      };

      if (channelId != null) {
        requestBody['EqualityFilter'] = {'Channel': channelId};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/Services/Nobox/Account/List'),
            headers: _headers,
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      print('🔥 Accounts response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Entities'] != null) {
          final List entities = data['Entities'];
          final accounts =
              entities.map((json) => AccountModel.fromJson(json)).toList();
          return ApiResponse.success(accounts);
        } else {
          return ApiResponse.success([]);
        }
      } else {
        return _handleErrorResponse(response, 'Failed to get accounts');
      }
    } catch (e) {
      print('🔥 Error getting accounts: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  /// 🔥 Helper method untuk handle error responses
  static ApiResponse<T> _handleErrorResponse<T>(
      http.Response response, String defaultMessage) {
    try {
      if (response.body.isNotEmpty) {
        final errorData = jsonDecode(response.body);
        if (errorData['Error'] != null) {
          String errorMessage = errorData['Error']['Message'] ??
              errorData['Error'] ??
              defaultMessage;
          String? errorCode = errorData['Error']['Code'];
          return ApiResponse.error(errorMessage, errorCode: errorCode);
        } else if (errorData['message'] != null) {
          return ApiResponse.error(errorData['message']);
        }
      }
      return ApiResponse.error('$defaultMessage (${response.statusCode})');
    } catch (parseError) {
      return ApiResponse.error('$defaultMessage (${response.statusCode})');
    }
  }

  static void clearMessageCache() {
    print('🔥 ApiService: message cache cleared');
  }

  /// 🔥 Logout - Enhanced cleanup
  static void logout() {
    _authToken = null;
    stopMessagePolling();
    // Clear user data
    UserService.clearCurrentUser();
    print(
        '🔥 User logged out, token cleared, user data cleared, polling stopped');
  }

  /// 🔥 Test connection
  static Future<ApiResponse<bool>> testConnection() async {
    try {
      print('🔥 Testing connection to: $baseUrl');

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Accept': 'text/html,application/json'},
      ).timeout(const Duration(seconds: 10));

      final success = response.statusCode >= 200 && response.statusCode < 400;
      String message = success
          ? 'Connection successful (${response.statusCode})'
          : 'Server returned ${response.statusCode}';

      print('🔥 Connection test result: $message');

      return ApiResponse.success(success, message: message);
    } catch (e) {
      print('🔥 Connection test failed: $e');
      return ApiResponse.error('Connection failed: $e');
    }
  }

  /// 🔥 Get current authentication status
  static bool get isAuthenticated =>
      _authToken != null && _authToken!.isNotEmpty;

  /// 🔥 Get polling status
  static bool get isPollingActive =>
      _messagePollingTimer != null && _messagePollingTimer!.isActive;

  /// 🔥 Refresh messages manually (for pull-to-refresh)
  static Future<ApiResponse<List<NoboxMessage>>> refreshMessages({
    int? linkId,
    int? channelId,
    String? linkIdExt,
    int take = 50,
  }) async {
    print('🔥 Manual refresh messages triggered');
    return await getMessages(
      linkId: linkId,
      channelId: channelId ?? 1,
      linkIdExt: linkIdExt,
      take: take,
      skip: 0, limit: 0, orderBy: '',
      orderDirection: '', // Always start from the beginning for refresh
    );
  }
}

// Model classes
class ContactModel {
  final String id;
  final String name;

  ContactModel({required this.id, required this.name});

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
    );
  }

  @override
  String toString() => 'ContactModel{id: $id, name: $name}';
}

/// ✅ NEW: Model khusus untuk Link sebagai Contact option
class LinkModel {
  final String id;
  final String idExt;
  final String name;

  LinkModel({required this.id, required this.idExt, required this.name});

  factory LinkModel.fromJson(Map<String, dynamic> json) {
    return LinkModel(
      id: json['Id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? '',
      name: json['Name']?.toString() ?? json['Nm']?.toString() ?? 'Link ${json['Id']?.toString() ?? 'Unknown'}',
    );
  }

  @override
  String toString() => 'LinkModel{id: $id, idExt: $idExt, name: $name}';
}

class ChatLinkModel {
  final String id;
  final String idExt;
  final String name;

  ChatLinkModel({required this.id, required this.idExt, required this.name});

  factory ChatLinkModel.fromJson(Map<String, dynamic> json) {
    return ChatLinkModel(
      id: json['Id']?.toString() ?? '',
      idExt: json['IdExt']?.toString() ?? '',
      name: json['Name']?.toString() ??
          json['Nm']?.toString() ??
          'Chat ${json['Id']?.toString() ?? 'Unknown'}',
    );
  }

  @override
  String toString() => 'ChatLinkModel{id: $id, idExt: $idExt, name: $name}';
}

class ChannelModel {
  final int id;
  final String name;

  ChannelModel({required this.id, required this.name});

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: int.tryParse(json['Id']?.toString() ?? '0') ?? 0,
      name: json['Nm']?.toString() ?? '',
    );
  }

  @override
  String toString() => 'ChannelModel{id: $id, name: $name}';
}

class AccountModel {
  final String id;
  final String name;
  final int channel;

  AccountModel({required this.id, required this.name, required this.channel});

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['Id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      channel: int.tryParse(json['Channel']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  String toString() => 'AccountModel{id: $id, name: $name, channel: $channel}';
}

class UploadedFile {
  final String filename;
  final String originalName;

  UploadedFile({required this.filename, required this.originalName});

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      filename: json['Filename']?.toString() ?? '',
      originalName: json['OriginalName']?.toString() ?? '',
    );
  }

  @override
  String toString() =>
      'UploadedFile{filename: $filename, originalName: $originalName}';
}

/// API Response Extensions
extension ApiResponseExtensions<T> on ApiResponse<T> {
  /// Execute a function if response is successful
  ApiResponse<T> onSuccess(void Function(T data) callback) {
    if (success && data != null) {
      callback(data!);
    }
    return this;
  }

  /// Execute a function if response is error
  ApiResponse<T> onError(void Function(String error) callback) {
    if (!success) {
      callback(userMessage);
    }
    return this;
  }

  /// Execute a function regardless of success/error
  ApiResponse<T> onComplete(void Function(ApiResponse<T> response) callback) {
    callback(this);
    return this;
  }
}

/// Utility functions for creating common responses
class ApiResponseUtils {
  /// Create a loading response (for UI states)
  static ApiResponse<T> loading<T>([String? message]) {
    return ApiResponse<T>(
      success: false,
      message: message ?? 'Loading...',
      errorCode: 'LOADING',
    );
  }

  /// Create a cached response
  static ApiResponse<T> cached<T>(T data, [String? message]) {
    return ApiResponse<T>(
      success: true,
      data: data,
      message: message ?? 'Data from cache',
      metadata: {'cached': true},
    );
  }

  /// Combine multiple responses
  static ApiResponse<List<T>> combine<T>(List<ApiResponse<T>> responses) {
    final errors = responses.where((r) => !r.success).toList();
    if (errors.isNotEmpty) {
      return ApiResponse.error(
        'Multiple errors: ${errors.map((e) => e.message).join(', ')}',
      );
    }

    final data = responses
        .where((r) => r.success && r.data != null)
        .map((r) => r.data!)
        .toList();

    return ApiResponse.success(data);
  }
}