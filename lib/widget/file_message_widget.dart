import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_service.dart';

class FileMessageWidget extends StatefulWidget {
  final String fileUrl;
  final String filename;
  final int fileSize;
  final bool isMyMessage;

  const FileMessageWidget({
    Key? key,
    required this.fileUrl,
    required this.filename,
    required this.fileSize,
    this.isMyMessage = false,
  }) : super(key: key);

  @override
  State<FileMessageWidget> createState() => _FileMessageWidgetState();
}

class _FileMessageWidgetState extends State<FileMessageWidget>
    with TickerProviderStateMixin {
  bool _isDownloading = false;
  bool _isSharing = false;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _buttonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final filePath = await MediaService.downloadFileToDevice(
        widget.fileUrl,
        widget.filename,
      );

      if (filePath.isNotEmpty) {
        _showSuccessMessage('File downloaded successfully');
      } else {
        _showErrorMessage('Failed to download file');
      }
    } catch (e) {
      _showErrorMessage('Download error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _shareFile() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      // Handle different file types
      if (MediaService.isImageFile(widget.filename)) {
        await MediaService.shareImageFromUrl(widget.fileUrl, widget.filename);
      } else {
        await MediaService.shareFileFromUrl(widget.fileUrl, widget.filename);
      }
      _showSuccessMessage('File shared successfully');
    } catch (e) {
      _showErrorMessage('Share error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      bool success = false;
      
      if (MediaService.isImageFile(widget.filename)) {
        success = await MediaService.downloadImageToGallery(widget.fileUrl, widget.filename);
        if (success) {
          _showSuccessMessage('Image saved to gallery');
        } else {
          _showErrorMessage('Failed to save image to gallery');
        }
      } else if (MediaService.isVideoFile(widget.filename)) {
        success = await MediaService.saveVideoToGallery(widget.fileUrl, widget.filename);
        if (success) {
          _showSuccessMessage('Video saved to gallery');
        } else {
          _showErrorMessage('Failed to save video to gallery');
        }
      } else {
        // For other files, download to device storage
        final filePath = await MediaService.downloadFileToDevice(widget.fileUrl, widget.filename);
        if (filePath.isNotEmpty) {
          _showSuccessMessage('File downloaded to device');
        } else {
          _showErrorMessage('Failed to download file');
        }
      }
    } catch (e) {
      _showErrorMessage('Save error: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
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
          backgroundColor: const Color(0xFFF44336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    Color? color,
  }) {
    return GestureDetector(
      onTapDown: (_) => _buttonController.forward(),
      onTapUp: (_) => _buttonController.reverse(),
      onTapCancel: () => _buttonController.reverse(),
      onTap: isLoading ? null : onTap,
      child: AnimatedBuilder(
        animation: _buttonAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _buttonAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: (color ?? const Color(0xFF007AFF)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (color ?? const Color(0xFF007AFF)).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: color ?? const Color(0xFF007AFF),
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          icon,
                          color: color ?? const Color(0xFF007AFF),
                          size: 16,
                        ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: color ?? const Color(0xFF007AFF),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileIcon = MediaService.getFileIcon(widget.filename);
    final fileColor = MediaService.getFileColor(widget.filename);
    final formattedSize = MediaService.formatFileSize(widget.fileSize);
    final isMediaFile = MediaService.isImageFile(widget.filename) || MediaService.isVideoFile(widget.filename);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isMyMessage 
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isMyMessage 
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File info row
          Row(
            children: [
              // File icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fileColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  fileIcon,
                  color: fileColor,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // File details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.filename,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isMyMessage 
                            ? Colors.white 
                            : const Color(0xFF212121),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedSize,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: widget.isMyMessage 
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              // Save/Download button
              _buildActionButton(
                icon: isMediaFile ? Icons.save_alt : Icons.download_rounded,
                label: isMediaFile ? 'Save' : 'Download',
                onTap: isMediaFile ? _saveToGallery : _downloadFile,
                isLoading: _isDownloading,
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _shareFile,
                isLoading: _isSharing,
                color: const Color(0xFF007AFF),
              ),
            ],
          ),
        ],
      ),
    );
  }
}