import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String filename;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.filename,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _showControls = true;
  String? _errorMessage;
  
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundColor = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _initializeVideo();
    _fadeController.forward();
  }

  Future<void> _initializeVideo() async {
    try {
      print('🔥 Initializing video player for: ${widget.videoUrl}');
      
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        httpHeaders: {
          'User-Agent': 'NoboxFlutterApp/1.0',
          'Accept': 'video/*',
        },
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _totalDuration = _controller!.value.duration;
        });

        // Listen to position changes
        _controller!.addListener(() {
          if (mounted) {
            setState(() {
              _currentPosition = _controller!.value.position;
              _isPlaying = _controller!.value.isPlaying;
            });
          }
        });

        print('🔥 Video initialized successfully');
        print('🔥 Duration: ${_totalDuration.inSeconds} seconds');
      }
    } catch (e) {
      print('🔥 Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null) return;

    setState(() {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });

    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  void _seekTo(double value) {
    if (_controller == null) return;
    
    final position = Duration(milliseconds: (value * _totalDuration.inMilliseconds).round());
    _controller!.seekTo(position);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _fadeController.forward();
      // Auto-hide controls after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlaying) {
          setState(() {
            _showControls = false;
          });
          _fadeController.reverse();
        }
      });
    } else {
      _fadeController.reverse();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading video...',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.filename,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load video',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _initializeVideo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _downloadVideo(),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Video player
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Controls overlay
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return Opacity(
                opacity: _showControls ? _fadeController.value : 0.0,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Column(
                    children: [
                      // Top bar with title and actions
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.filename,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _downloadVideo,
                                icon: const Icon(
                                  Icons.download,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                onPressed: _shareVideo,
                                icon: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Spacer to push controls to bottom
                      const Spacer(),

                      // Center play/pause button
                      Center(
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                            CurvedAnimation(
                              parent: _scaleController,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _togglePlayPause,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 40,
                              ),
                              iconSize: 40,
                              padding: const EdgeInsets.all(20),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Bottom controls
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Progress slider
                            Row(
                              children: [
                                Text(
                                  _formatDuration(_currentPosition),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 12,
                                      ),
                                    ),
                                    child: Slider(
                                      value: _totalDuration.inMilliseconds > 0
                                          ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
                                          : 0.0,
                                      onChanged: _seekTo,
                                      activeColor: primaryBlue,
                                      inactiveColor: Colors.white30,
                                      thumbColor: primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_totalDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Control buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    final newPosition = _currentPosition - const Duration(seconds: 10);
                                    _controller!.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
                                  },
                                  icon: const Icon(Icons.replay_10),
                                  color: Colors.white,
                                  iconSize: 32,
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: primaryBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _togglePlayPause,
                                    icon: Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    iconSize: 36,
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final newPosition = _currentPosition + const Duration(seconds: 10);
                                    _controller!.seekTo(newPosition < _totalDuration ? newPosition : _totalDuration);
                                  },
                                  icon: const Icon(Icons.forward_10),
                                  color: Colors.white,
                                  iconSize: 32,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo() async {
    try {
      final success = await MediaService.saveVideoToGallery(widget.videoUrl, widget.filename);
      
      if (success) {
        _showSuccessSnackBar('Video saved to gallery');
      } else {
        _showErrorSnackBar('Failed to save video');
      }
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _shareVideo() async {
    try {
      await MediaService.shareFileFromUrl(widget.videoUrl, widget.filename);
      _showSuccessSnackBar('Video shared successfully');
    } catch (e) {
      _showErrorSnackBar('Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF44336),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: FadeTransition(
        opacity: _fadeController,
        child: Stack(
          children: [
            // Background
            Container(
              width: double.infinity,
              height: double.infinity,
              color: backgroundColor,
            ),

            // Content
            if (_isLoading)
              _buildLoadingState()
            else if (_hasError)
              _buildErrorState()
            else if (_controller != null && _controller!.value.isInitialized)
              _buildVideoPlayer()
            else
              _buildErrorState(),

            // Close button (always visible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}