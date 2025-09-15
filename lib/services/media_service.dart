import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

class MediaService {
  static final Dio _dio = Dio();
  
  /// Download and save image to gallery using Gal
  static Future<bool> downloadImageToGallery(String imageUrl, String filename) async {
    try {
      print('🔥 Starting image download to gallery: $imageUrl');
      
      // Request gallery permission using Gal
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
        hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          throw Exception('Gallery access denied');
        }
      }
      
      // Download image to bytes first
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Create temporary file with proper image extension
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _getImageExtension(filename);
        final tempPath = '${tempDir.path}/temp_image_$timestamp.$extension';
        
        // Write bytes to file
        final file = File(tempPath);
        await file.writeAsBytes(response.data!);
        
        // Save to gallery using Gal
        await Gal.putImage(tempPath, album: 'NoBox');
        
        // Clean up temp file
        await file.delete();
        
        print('🔥 Image saved to gallery successfully');
        return true;
      }
      
      return false;
    } catch (e) {
      print('🔥 Error saving image to gallery: $e');
      return false;
    }
  }
  
  /// Share image from URL with proper MIME type and filename
  static Future<void> shareImageFromUrl(String imageUrl, String filename) async {
    try {
      print('🔥 Starting image share: $imageUrl');
      
      // Download image to bytes
      final response = await _dio.get<List<int>>(
        imageUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Get proper image extension and create safe filename
        final extension = _getImageExtension(filename);
        final safeFilename = _createSafeImageFilename(filename, extension);
        
        // Create temporary file with proper image extension
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempPath = '${tempDir.path}/share_image_$timestamp.$extension';
        
        // Write bytes to file
        final file = File(tempPath);
        await file.writeAsBytes(response.data!);
        
        // Verify file was created
        if (await file.exists() && await file.length() > 0) {
          // Get proper MIME type for image
          final mimeType = _getImageMimeType(extension);
          
          print('🔥 Sharing image: $tempPath as $safeFilename with MIME: $mimeType');
          
          // Share the file with proper MIME type and filename
          await Share.shareXFiles(
            [XFile(tempPath, mimeType: mimeType, name: safeFilename)],
            text: 'Image shared from NoBox Chat',
          );
          
          print('🔥 Image shared successfully');
          
          // Clean up after a delay
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              print('🔥 Error cleaning up temp file: $e');
            }
          });
        } else {
          throw Exception('Failed to create temporary image file');
        }
      } else {
        throw Exception('Failed to download image from server');
      }
    } catch (e) {
      print('🔥 Error sharing image: $e');
      throw Exception('Failed to share image: $e');
    }
  }
  
  /// Share file from URL with proper MIME type detection
  static Future<void> shareFileFromUrl(String fileUrl, String filename) async {
    try {
      print('🔥 Starting file share: $fileUrl');
      
      // Create safe filename
      final safeFilename = _createSafeFilename(filename);
      
      // Download file to bytes
      final response = await _dio.get<List<int>>(
        fileUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('🔥 Download progress: $progress%');
          }
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Create temporary file
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempPath = '${tempDir.path}/share_file_$timestamp\_$safeFilename';
        
        // Write bytes to file
        final file = File(tempPath);
        await file.writeAsBytes(response.data!);
        
        // Verify file was created successfully
        if (await file.exists() && await file.length() > 0) {
          // Get proper MIME type
          final mimeType = _getMimeType(filename);
          
          print('🔥 Sharing file: $tempPath as $safeFilename with MIME: $mimeType');
          
          // Share the file with proper MIME type
          await Share.shareXFiles(
            [XFile(tempPath, mimeType: mimeType, name: safeFilename)],
            text: 'File shared from NoBox Chat',
          );
          
          print('🔥 File shared successfully');
          
          // Clean up after sharing
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              print('🔥 Error cleaning up temp file: $e');
            }
          });
        } else {
          throw Exception('Failed to create temporary file');
        }
      } else {
        throw Exception('Failed to download file from server');
      }
    } catch (e) {
      print('🔥 Error sharing file: $e');
      throw Exception('Failed to share file: $e');
    }
  }
  
  /// Download file to device storage with proper permissions
  static Future<String> downloadFileToDevice(String fileUrl, String filename) async {
    try {
      print('🔥 Starting file download: $fileUrl');
      
      // Create safe filename
      final safeFilename = _createSafeFilename(filename);
      
      // Get app documents directory (no special permissions needed)
      final appDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${appDir.path}/Downloads');
      
      // Ensure directory exists
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${downloadsDir.path}/${timestamp}_$safeFilename';
      
      // Download file to bytes first
      final response = await _dio.get<List<int>>(
        fileUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 10),
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('🔥 Download progress: $progress%');
          }
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Write bytes to file
        final file = File(filePath);
        await file.writeAsBytes(response.data!);
        
        // Verify file was created
        if (await file.exists() && await file.length() > 0) {
          print('🔥 File downloaded to: $filePath');
          return filePath;
        } else {
          throw Exception('Failed to create downloaded file');
        }
      } else {
        throw Exception('Failed to download file from server');
      }
    } catch (e) {
      print('🔥 Error downloading file: $e');
      throw Exception('Failed to download file: $e');
    }
  }
  
  /// Save video to gallery with better error handling
  static Future<bool> saveVideoToGallery(String videoUrl, String filename) async {
    try {
      print('🔥 Starting video save to gallery: $videoUrl');
      
      // Check gallery access
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
        hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          throw Exception('Gallery access denied');
        }
      }
      
      // Download video to bytes with longer timeout
      final response = await _dio.get<List<int>>(
        videoUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 10), // Longer timeout for videos
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            print('🔥 Video download progress: $progress%');
          }
        },
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Create temporary file with proper video extension
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _getVideoExtension(filename);
        final tempPath = '${tempDir.path}/temp_video_$timestamp.$extension';
        
        // Write bytes to file
        final file = File(tempPath);
        await file.writeAsBytes(response.data!);
        
        // Verify file was created
        if (await file.exists() && await file.length() > 0) {
          // Save to gallery
          await Gal.putVideo(tempPath, album: 'NoBox');
          
          // Clean up temp file
          await file.delete();
          
          print('🔥 Video saved to gallery successfully');
          return true;
        } else {
          throw Exception('Failed to create video file');
        }
      }
      
      return false;
    } catch (e) {
      print('🔥 Error saving video to gallery: $e');
      return false;
    }
  }
  
  /// Create safe filename specifically for images
  static String _createSafeImageFilename(String originalFilename, String extension) {
    // Extract name without extension
    String nameWithoutExt = originalFilename;
    if (originalFilename.contains('.')) {
      nameWithoutExt = originalFilename.substring(0, originalFilename.lastIndexOf('.'));
    }
    
    // Clean the name
    String safeName = nameWithoutExt
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-_]'), '_');
    
    // Ensure name is not too long
    if (safeName.length > 50) {
      safeName = safeName.substring(0, 50);
    }
    
    // Return with proper image extension
    return '$safeName.$extension';
  }
  
  /// Get proper image extension
  static String _getImageExtension(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension)) {
      return extension;
    }
    return 'jpg'; // Default to jpg for images
  }
  
  /// Get proper video extension
  static String _getVideoExtension(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    if (['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm'].contains(extension)) {
      return extension;
    }
    return 'mp4'; // Default to mp4 for videos
  }
  
  /// Get file extension from filename
  static String _getFileExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  }
  
  /// Get proper MIME type for images
  static String _getImageMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
  
  /// Get proper MIME type for any file
  static String _getMimeType(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    // Image types
    if (isImageFile(filename)) {
      return _getImageMimeType(extension);
    }
    
    // Video types
    if (isVideoFile(filename)) {
      switch (extension) {
        case 'mp4':
          return 'video/mp4';
        case 'avi':
          return 'video/x-msvideo';
        case 'mov':
          return 'video/quicktime';
        case 'mkv':
          return 'video/x-matroska';
        case 'webm':
          return 'video/webm';
        default:
          return 'video/mp4';
      }
    }
    
    // Audio types
    if (isAudioFile(filename)) {
      switch (extension) {
        case 'mp3':
          return 'audio/mpeg';
        case 'wav':
          return 'audio/wav';
        case 'aac':
          return 'audio/aac';
        case 'm4a':
          return 'audio/mp4';
        case 'ogg':
          return 'audio/ogg';
        default:
          return 'audio/mpeg';
      }
    }
    
    // Document types
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      default:
        return 'application/octet-stream';
    }
  }
  
  /// Create safe filename by removing invalid characters
  static String _createSafeFilename(String filename) {
    // Remove or replace invalid characters
    String safeFilename = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_');
    
    // Ensure filename is not too long
    if (safeFilename.length > 100) {
      final extension = _getFileExtension(safeFilename);
      final nameWithoutExt = safeFilename.substring(0, safeFilename.lastIndexOf('.'));
      safeFilename = '${nameWithoutExt.substring(0, 90)}.$extension';
    }
    
    // Ensure it has an extension
    if (!safeFilename.contains('.')) {
      safeFilename += '.bin';
    }
    
    return safeFilename;
  }
  
  /// Get file size in human readable format
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Get file icon based on extension
  static IconData getFileIcon(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Icons.video_file;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  /// Get file color based on extension
  static Color getFileColor(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.pink;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Colors.deepPurple;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'mkv':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }
  
  /// Check if file is an image
  static bool isImageFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }
  
  /// Check if file is an audio file
  static bool isAudioFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'].contains(extension);
  }
  
  /// Check if file is a video file
  static bool isVideoFile(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    return ['mp4', 'avi', 'mov', 'mkv', 'wmv', 'flv', 'webm'].contains(extension);
  }
  
  /// Download voice message for local playback
  static Future<String?> downloadVoiceForPlayback(String voiceUrl) async {
    try {
      print('🔥 Downloading voice for playback: $voiceUrl');
      
      // Create voice cache directory
      final tempDir = await getTemporaryDirectory();
      final voiceDir = Directory('${tempDir.path}/voice_cache');
      
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      
      // Create unique filename based on URL
      final urlHash = voiceUrl.hashCode.abs().toString();
      final filename = 'voice_$urlHash.wav'; // Changed to WAV
      final localPath = '${voiceDir.path}/$filename';
      
      // Check if already cached
      if (await File(localPath).exists()) {
        final fileSize = await File(localPath).length();
        if (fileSize > 0) {
          print('🔥 Using cached voice file: $localPath');
          return localPath;
        } else {
          // Delete corrupted cache file
          await File(localPath).delete();
        }
      }
      
      // Download voice to bytes
      final response = await _dio.get<List<int>>(
        voiceUrl,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // Write bytes to file
        final file = File(localPath);
        await file.writeAsBytes(response.data!);
        
        // Verify file was created
        if (await file.exists() && await file.length() > 0) {
          print('🔥 Voice downloaded successfully: $localPath');
          return localPath;
        }
      }
      
      throw Exception('Failed to download voice message');
    } catch (e) {
      print('🔥 Error downloading voice: $e');
      return null;
    }
  }
}