  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import '../services/voice_service.dart';
  import 'dart:async';
  import 'dart:io';

  class VoiceRecorderWidget extends StatefulWidget {
    final Function(String voicePath, Duration duration) onVoiceRecorded;
    final VoidCallback onCancel;

    const VoiceRecorderWidget({
      Key? key,
      required this.onVoiceRecorded,
      required this.onCancel,
    }) : super(key: key);

    @override
    State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
  }

  class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
      with TickerProviderStateMixin {
    bool _isRecording = false;
    bool _isInitializing = true;
    Duration _recordingDuration = Duration.zero;
    Timer? _timer;
    late AnimationController _pulseController;
    late AnimationController _scaleController;
    late AnimationController _waveController;
    late Animation<double> _pulseAnimation;
    late Animation<double> _scaleAnimation;
    late Animation<double> _waveAnimation;

    @override
    void initState() {
      super.initState();
      
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      _scaleController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      
      _waveController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      
      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.2,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ));
      
      _waveAnimation = Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ));
      
      _setupVoiceServiceCallbacks();
      _initializeAndStartRecording();
    }
    
    void _setupVoiceServiceCallbacks() {
      VoiceService.onRecordingUpdate = (duration) {
        if (mounted) {
          setState(() {
            _recordingDuration = duration;
          });
        }
      };
      
      VoiceService.onRecordingStateChanged = (isRecording) {
        if (mounted) {
          setState(() {
            _isRecording = isRecording;
            _isInitializing = false;
          });
          
          if (isRecording) {
            _pulseController.repeat(reverse: true);
            _waveController.repeat(reverse: true);
          } else {
            _pulseController.stop();
            _waveController.stop();
          }
        }
      };
    }
    
    Future<void> _initializeAndStartRecording() async {
      try {
        await VoiceService.initialize();
        await _startRecording();
      } catch (e) {
        print('🔥 Error initializing voice recording: $e');
        _showError('Failed to initialize voice recording: ${e.toString().replaceAll('Exception: ', '')}');
        widget.onCancel();
      }
    }
    
    @override
    void dispose() {
      _timer?.cancel();
      _pulseController.dispose();
      _scaleController.dispose();
      _waveController.dispose();
      super.dispose();
    }
    
    Future<void> _startRecording() async {
      try {
        final recordingPath = await VoiceService.startRecording();
        
        if (recordingPath != null) {
          // Start local timer as backup
          _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
            if (_isRecording && mounted) {
              setState(() {
                _recordingDuration = _recordingDuration + const Duration(milliseconds: 100);
              });
            }
          });
        } else {
          throw Exception('Failed to start recording');
        }
        
      } catch (e) {
        print('🔥 Error starting recording: $e');
        _showError('Failed to start recording: ${e.toString().replaceAll('Exception: ', '')}');
        widget.onCancel();
      }
    }
    
    Future<void> _stopAndSendRecording() async {
      try {
        final voicePath = await VoiceService.stopRecording();
        _timer?.cancel();
        
        if (voicePath != null && voicePath.isNotEmpty) {
          // Verify file exists and has content
          final file = File(voicePath);
          if (await file.exists()) {
            final fileSize = await file.length();
            if (fileSize > 0) {
              print('🔥 Voice recording completed: $voicePath (${VoiceService.formatFileSize(fileSize)})');
              widget.onVoiceRecorded(voicePath, _recordingDuration);
              return;
            }
          }
        }
        
        _showError('Recording failed - no audio captured');
        widget.onCancel();
      } catch (e) {
        print('🔥 Error stopping recording: $e');
        _showError('Failed to stop recording: ${e.toString().replaceAll('Exception: ', '')}');
        widget.onCancel();
      }
    }
    
    void _cancelRecording() async {
      try {
        await VoiceService.stopRecording();
        _timer?.cancel();
        widget.onCancel();
      } catch (e) {
        print('🔥 Error canceling recording: $e');
        widget.onCancel();
      }
    }
    
    void _showError(String message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
    
    Widget _buildActionButton({
      required IconData icon,
      required VoidCallback onTap,
      required Color color,
      double size = 60,
    }) {
      return GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: size * 0.4,
                ),
              ),
            );
          },
        ),
      );
    }
    
    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Recording status
            Text(
              _isInitializing 
                  ? 'Initializing Microphone...'
                  : _isRecording 
                      ? 'Recording Voice Message (AAC)'
                      : 'Ready to Record',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF212121),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Duration display
            Text(
              VoiceService.formatDuration(_recordingDuration),
              style: GoogleFonts.poppins(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                color: _isRecording 
                    ? const Color(0xFF007AFF)
                    : const Color(0xFF757575),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Animated waveform
            Container(
              height: 80,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(30, (index) {
                  final heights = [15, 25, 20, 35, 18, 28, 22, 30, 16, 26];
                  final baseHeight = heights[index % heights.length].toDouble();
                  
                  return AnimatedBuilder(
                    animation: _waveAnimation,
                    builder: (context, child) {
                      final animatedHeight = _isRecording 
                          ? baseHeight * _waveAnimation.value
                          : baseHeight * 0.3;
                      
                      return Container(
                        width: 3,
                        height: animatedHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _isRecording 
                              ? const Color(0xFF007AFF).withOpacity(0.8)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                _buildActionButton(
                  icon: Icons.close,
                  onTap: _cancelRecording,
                  color: Colors.red,
                ),
                
                // Record/Stop button (main action)
                GestureDetector(
                  onTap: _isRecording ? _stopAndSendRecording : null,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isInitializing
                                ? Colors.grey[400]
                                : _isRecording 
                                    ? const Color(0xFF007AFF)
                                    : Colors.grey[400],
                            shape: BoxShape.circle,
                            boxShadow: _isRecording ? [
                              BoxShadow(
                                color: const Color(0xFF007AFF).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ] : null,
                          ),
                          child: _isInitializing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isRecording ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 36,
                                ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Send button
                _buildActionButton(
                  icon: Icons.send,
                  onTap: _isRecording ? _stopAndSendRecording : () {},
                  color: _isRecording 
                      ? const Color(0xFF4CAF50)
                      : Colors.grey,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            Text(
              _isInitializing
                  ? 'Setting up microphone...'
                  : _isRecording 
                      ? 'Tap stop or send to finish recording'
                      : 'Tap microphone to start recording',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Format indicator
            if (_isRecording || !_isInitializing)
              Text(
                'Recording in WAV format',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF007AFF),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 16),
          ],
        ),
      );
    }
  }