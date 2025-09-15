import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_service.dart';
import 'dart:async';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final String filename;
  final Duration duration;
  final bool isMyMessage;

  const VoiceMessagePlayer({
    Key? key,
    required this.audioUrl,
    required this.filename,
    this.duration = const Duration(seconds: 30),
    this.isMyMessage = false,
  }) : super(key: key);

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer>
    with TickerProviderStateMixin {
  bool _isPlaying = false;
  bool _isCurrentlyPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _playButtonController;
  late Animation<double> _playButtonAnimation;
  StreamSubscription? _playbackSubscription;

  @override
  void initState() {
    super.initState();
    
    _totalDuration = widget.duration;
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.easeInOut,
    ));
    
    _playButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _playButtonController,
      curve: Curves.easeInOut,
    ));
    
    _setupVoiceServiceCallbacks();
  }
  
  void _setupVoiceServiceCallbacks() {
    // Set up voice service callbacks
    VoiceService.onPlaybackUpdate = (position, duration) {
      if (mounted && VoiceService.isPlayingVoice(widget.audioUrl)) {
        setState(() {
          _currentPosition = position;
          if (duration.inMilliseconds > 0) {
            _totalDuration = duration;
          }
        });
      }
    };
    
    VoiceService.onPlaybackStateChanged = (isPlaying) {
      if (mounted) {
        final wasPlayingThis = _isCurrentlyPlaying;
        _isCurrentlyPlaying = isPlaying && VoiceService.isPlayingVoice(widget.audioUrl);
        
        setState(() {
          _isPlaying = _isCurrentlyPlaying;
        });
        
        if (_isCurrentlyPlaying) {
          _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
          _waveController.reset();
          if (wasPlayingThis) {
            // Reset position when this voice message stops
            setState(() {
              _currentPosition = Duration.zero;
            });
          }
        }
      }
    };
  }
  
  @override
  void dispose() {
    _waveController.dispose();
    _playButtonController.dispose();
    _playbackSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _togglePlayback() async {
    try {
      _playButtonController.forward().then((_) {
        _playButtonController.reverse();
      });
      
      if (_isPlaying && _isCurrentlyPlaying) {
        await VoiceService.stopPlayback();
      } else {
        // Stop any other playing voice message first
        if (VoiceService.isPlaying) {
          await VoiceService.stopPlayback();
          // Small delay to ensure clean state
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        await VoiceService.playVoiceMessage(widget.audioUrl);
      }
    } catch (e) {
      print('🔥 Error toggling voice playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error playing voice: ${e.toString().replaceAll('Exception: ', '')}'),
                ),
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
  }
  
  @override
  Widget build(BuildContext context) {
    final progressPercentage = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isMyMessage 
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isMyMessage 
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: AnimatedBuilder(
              animation: _playButtonAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _playButtonAnimation.value,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.isMyMessage 
                          ? Colors.white.withOpacity(0.2)
                          : const Color(0xFF007AFF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isMyMessage 
                              ? Colors.white 
                              : const Color(0xFF007AFF)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Waveform and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform visualization
                Container(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(25, (index) {
                      final isActive = progressPercentage * 25 > index;
                      final heights = [12, 20, 16, 24, 14, 18, 22, 15, 19, 17];
                      final baseHeight = heights[index % heights.length].toDouble();
                      
                      return AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (context, child) {
                          final animatedHeight = _isPlaying && isActive
                              ? baseHeight * _waveAnimation.value
                              : baseHeight * 0.4;
                          
                          return Container(
                            width: 2.5,
                            height: animatedHeight,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (widget.isMyMessage 
                                      ? Colors.white.withOpacity(0.9)
                                      : const Color(0xFF007AFF))
                                  : (widget.isMyMessage 
                                      ? Colors.white.withOpacity(0.3)
                                      : Colors.grey[400]),
                              borderRadius: BorderRadius.circular(1.25),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // Duration and progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying 
                          ? VoiceService.formatDuration(_currentPosition)
                          : '0:00',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: widget.isMyMessage 
                            ? Colors.white.withOpacity(0.8)
                            : Colors.grey[600],
                      ),
                    ),
                    Text(
                      VoiceService.formatDuration(_totalDuration),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: widget.isMyMessage 
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Voice icon with MP3 indicator
          Column(
            children: [
              Icon(
                Icons.mic,
                size: 16,
                color: widget.isMyMessage 
                    ? Colors.white.withOpacity(0.6)
                    : Colors.grey[500],
              ),
              Text(
                'WAV',
                style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: widget.isMyMessage 
                      ? Colors.white.withOpacity(0.5)
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}