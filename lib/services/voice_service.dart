import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

class VoiceService {
  static FlutterSoundRecorder? _recorder;
  static FlutterSoundPlayer? _player;
  static bool _isRecording = false;
  static bool _isPlaying = false;
  static String? _currentRecordingPath;
  static String? _currentPlayingPath;
  static StreamSubscription? _recorderSubscription;
  static StreamSubscription? _playerSubscription;
  static final Dio _dio = Dio();
  static Duration _recordingDuration = Duration.zero;
  
  // Callbacks for UI updates
  static Function(Duration)? onRecordingUpdate;
  static Function(bool)? onRecordingStateChanged;
  static Function(Duration, Duration)? onPlaybackUpdate; // position, duration
  static Function(bool)? onPlaybackStateChanged;
  
  /// Initialize voice service with better codec support
  static Future<void> initialize() async {
    try {
      print('🔥 Initializing voice service...');
      
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();
      
      await _recorder!.openRecorder();
      await _player!.openPlayer();
      
      print('🔥 Voice service initialized successfully');
    } catch (e) {
      print('🔥 Error initializing voice service: $e');
      throw Exception('Failed to initialize voice service: $e');
    }
  }
  
  /// Dispose voice service
  static Future<void> dispose() async {
    try {
      await stopRecording();
      await stopPlayback();
      
      if (_recorder != null) {
        await _recorder!.closeRecorder();
        _recorder = null;
      }
      
      if (_player != null) {
        await _player!.closePlayer();
        _player = null;
      }
      
      _recorderSubscription?.cancel();
      _playerSubscription?.cancel();
      
      print('🔥 Voice service disposed');
    } catch (e) {
      print('🔥 Error disposing voice service: $e');
    }
  }
  
  /// Start voice recording with WAV codec (most compatible)
  static Future<String?> startRecording() async {
    try {
      print('🔥 Starting voice recording...');
      
      // Check microphone permission
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        throw Exception('Microphone permission denied');
      }
      
      if (_recorder == null) {
        await initialize();
      }
      
      if (_isRecording) {
        print('🔥 Already recording');
        return null;
      }
      
      // Create app-specific directory for recordings
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');
      
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      
      // Create unique filename with WAV extension (most compatible)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${recordingsDir.path}/voice_$timestamp.wav';
      
      // Reset recording duration
      _recordingDuration = Duration.zero;
      
      // Start recording with WAV codec (most compatible)
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath!,
        codec: Codec.pcm16WAV, // Changed to WAV for maximum compatibility
        bitRate: 16000, // Lower bitrate for voice
        sampleRate: 16000, // Standard voice sample rate
        numChannels: 1, // Mono for voice
      );
      
      _isRecording = true;
      onRecordingStateChanged?.call(true);
      
      // Start recording timer
      _recorderSubscription = _recorder!.onProgress!.listen((event) {
        _recordingDuration = event.duration;
        onRecordingUpdate?.call(event.duration);
      });
      
      print('🔥 Voice recording started (WAV): $_currentRecordingPath');
      return _currentRecordingPath;
    } catch (e) {
      print('🔥 Error starting recording: $e');
      _isRecording = false;
      onRecordingStateChanged?.call(false);
      throw Exception('Failed to start recording: $e');
    }
  }
  
  /// Stop voice recording
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _recorder == null) {
        print('🔥 Not recording');
        return null;
      }
      
      print('🔥 Stopping voice recording...');
      
      final path = await _recorder!.stopRecorder();
      _isRecording = false;
      onRecordingStateChanged?.call(false);
      
      _recorderSubscription?.cancel();
      
      // Verify the recorded file exists and has content
      if (path != null && await File(path).exists()) {
        final fileSize = await File(path).length();
        if (fileSize > 0) {
          print('🔥 Voice recording stopped successfully: $path (${formatFileSize(fileSize)})');
          return path;
        } else {
          print('🔥 Recorded file is empty');
          await File(path).delete(); // Clean up empty file
          return null;
        }
      }
      
      print('🔥 Recorded file not found');
      return null;
    } catch (e) {
      print('🔥 Error stopping recording: $e');
      _isRecording = false;
      onRecordingStateChanged?.call(false);
      throw Exception('Failed to stop recording: $e');
    }
  }
  
  /// Play voice message from URL or local path
  static Future<void> playVoiceMessage(String audioPath) async {
    try {
      if (_player == null) {
        await initialize();
      }
      
      // Stop current playback if playing
      if (_isPlaying) {
        await stopPlayback();
        // Small delay to ensure clean state
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      String localPath = audioPath;
      
      // If it's a URL, download it first
      if (audioPath.startsWith('http')) {
        print('🔥 Downloading voice from URL: $audioPath');
        final downloadedPath = await _downloadVoiceForPlayback(audioPath);
        if (downloadedPath == null) {
          throw Exception('Failed to download voice message');
        }
        localPath = downloadedPath;
      }
      
      // Verify file exists
      if (!await File(localPath).exists()) {
        throw Exception('Voice file not found: $localPath');
      }
      
      print('🔥 Playing voice message: $localPath');
      
      _currentPlayingPath = audioPath; // Store original path for comparison
      
      // Use WAV codec for playback (most compatible)
      await _player!.startPlayer(
        fromURI: localPath,
        codec: Codec.pcm16WAV, // Specify WAV codec for consistency
        whenFinished: () {
          print('🔥 Voice playback finished');
          _isPlaying = false;
          _currentPlayingPath = null;
          onPlaybackStateChanged?.call(false);
          _playerSubscription?.cancel();
        },
      );
      
      _isPlaying = true;
      onPlaybackStateChanged?.call(true);
      
      // Listen to playback progress
      _playerSubscription = _player!.onProgress!.listen((event) {
        onPlaybackUpdate?.call(event.position, event.duration);
      });
      
    } catch (e) {
      print('🔥 Error playing voice message: $e');
      _isPlaying = false;
      _currentPlayingPath = null;
      onPlaybackStateChanged?.call(false);
      throw Exception('Failed to play voice message: $e');
    }
  }
  
  /// Download voice message for playback with better error handling
  static Future<String?> _downloadVoiceForPlayback(String voiceUrl) async {
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
  
  /// Stop voice playback
  static Future<void> stopPlayback() async {
    try {
      if (_player != null && _isPlaying) {
        await _player!.stopPlayer();
        _isPlaying = false;
        _currentPlayingPath = null;
        onPlaybackStateChanged?.call(false);
        _playerSubscription?.cancel();
        print('🔥 Voice playback stopped');
      }
    } catch (e) {
      print('🔥 Error stopping playback: $e');
    }
  }
  
  /// Get recording duration
  static Duration get recordingDuration => _recordingDuration;
  
  /// Check if currently recording
  static bool get isRecording => _isRecording;
  
  /// Check if currently playing
  static bool get isPlaying => _isPlaying;
  
  /// Get current playing path
  static String? get currentPlayingPath => _currentPlayingPath;
  
  /// Get recording path
  static String? get currentRecordingPath => _currentRecordingPath;
  
  /// Format duration for display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  /// Format file size
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Clean up old voice cache files
  static Future<void> cleanupVoiceCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final voiceDir = Directory('${tempDir.path}/voice_cache');
      
      if (await voiceDir.exists()) {
        final files = await voiceDir.list().toList();
        final now = DateTime.now();
        
        for (final file in files) {
          if (file is File) {
            final stat = await file.stat();
            final age = now.difference(stat.modified);
            
            // Delete files older than 7 days
            if (age.inDays > 7) {
              await file.delete();
              print('🔥 Cleaned up old voice cache: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      print('🔥 Error cleaning voice cache: $e');
    }
  }
  
  /// Get voice message duration from file
  static Future<Duration> getVoiceDuration(String filePath) async {
    try {
      if (_player == null) {
        await initialize();
      }
      
      // For now, return a default duration
      // You can implement actual duration detection if needed
      return const Duration(seconds: 30);
    } catch (e) {
      print('🔥 Error getting voice duration: $e');
      return const Duration(seconds: 30);
    }
  }
  
  /// Check if a voice message is currently playing this specific audio
  static bool isPlayingVoice(String audioPath) {
    return _isPlaying && _currentPlayingPath == audioPath;
  }
}