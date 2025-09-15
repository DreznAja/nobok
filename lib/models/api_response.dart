/// ✅ Final ApiResponse (gabungan versi lama & versi lengkap)
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
  factory ApiResponse.success(
    T data, {
    String? message,
    Map<String, dynamic>? metadata,
  }) {
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

  /// ✅ fromJson generic parser
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    try {
      final bool isSuccess = json['success'] == true ||
          json['Success'] == true ||
          json['IsError'] != true ||
          (json['code'] != null &&
              json['code'] >= 200 &&
              json['code'] < 300) ||
          (json['Code'] != null &&
              json['Code'] >= 200 &&
              json['Code'] < 300);

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
            ? (json['metadata'] ?? json['Metadata'])
                as Map<String, dynamic>
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
