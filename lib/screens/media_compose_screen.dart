import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/message_model.dart';
import '../services/user_service.dart';

class MediaComposeScreen extends StatefulWidget {
  final File? mediaFile;
  final String? mediaUrl;
  final String mediaType; // 'image', 'video', 'audio', 'file'
  final String filename;
  final ChatLinkModel chatLink;
  final ChannelModel channel;
  final NoboxMessage? replyingToMessage;

  const MediaComposeScreen({
    Key? key,
    this.mediaFile,
    this.mediaUrl,
    required this.mediaType,
    required this.filename,
    required this.chatLink,
    required this.channel,
    this.replyingToMessage,
  }) : super(key: key);

  @override
  State<MediaComposeScreen> createState() => _MediaComposeScreenState();
}

class _MediaComposeScreenState extends State<MediaComposeScreen>
    with TickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isSending = false;
  bool _isUploading = false;
  String? _uploadProgress;
  UploadedFile? _uploadedFile;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  
  // Colors matching existing design
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);
  static const Color replyBorderColor = Color(0xFF34C759);
  static const Color replyBackgroundColor = Color(0xFFF0F8F0);

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController.forward();
    _fadeController.forward();
    
    // Auto-upload file if provided
    if (widget.mediaFile != null) {
      _uploadMediaFile();
    }
    
    // Auto focus caption field after animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _uploadMediaFile() async {
    if (widget.mediaFile == null) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 'Preparing ${widget.mediaType}...';
    });

    try {
      ApiResponse<UploadedFile> uploadResponse;
      
      setState(() {
        _uploadProgress = 'Uploading ${widget.mediaType}...';
      });

      // Use smart upload with fallback
      uploadResponse = await ApiService.uploadFileWithFallback(
        file: widget.mediaFile!,
        customFilename: widget.filename,
      );

      if (uploadResponse.success && uploadResponse.data != null) {
        setState(() {
          _uploadedFile = uploadResponse.data;
          _uploadProgress = '${widget.mediaType.capitalize()} ready to send';
        });
        
        _showSuccessSnackBar('${widget.mediaType.capitalize()} uploaded successfully');
      } else {
        _showErrorSnackBar(uploadResponse.userMessage);
        _goBack();
      }
    } catch (e) {
      print('🔥 Error uploading media: $e');
      _showErrorSnackBar('Failed to upload ${widget.mediaType}: $e');
      _goBack();
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _sendMediaMessage() async {
    if (_uploadedFile == null || _isSending) return;
    
    final caption = _captionController.text.trim();
    
    setState(() {
      _isSending = true;
    });

    try {
      // Create content based on media type and caption
      String content = _createMediaContent(caption);
      
      // Add reply prefix if replying
      if (widget.replyingToMessage != null) {
        final repliedToName = _getContactDisplayName(widget.replyingToMessage!);
        final replyPreview = widget.replyingToMessage!.content.length > 50 
            ? '${widget.replyingToMessage!.content.substring(0, 50)}...'
            : widget.replyingToMessage!.content;
        
        content = '> $repliedToName: $replyPreview\n\n$content';
      }
      
      // Get body type for the media
      final bodyType = ApiService.getBodyTypeForFile(_uploadedFile!.filename);
      
      // Create attachment JSON
final Map<String, dynamic> attachmentData = {
  'Filename': _uploadedFile!.filename,
  'OriginalName': _uploadedFile!.originalName,
};

// Add special properties for voice notes
if (widget.mediaType == 'audio' && widget.filename.toLowerCase().contains('voice')) {
  attachmentData['IsVoiceNote'] = true; // sekarang aman
}
      
      final attachmentJson = jsonEncode(attachmentData);
      
      // Send message with attachment
      final messageResponse = await ApiService.sendMessageWithAttachment(
        content: content,
        channelId: widget.channel.id,
        linkId: int.tryParse(widget.chatLink.id) ?? 0,
        linkIdExt: widget.chatLink.idExt,
        attachmentFilename: attachmentJson,
        bodyType: bodyType,
      );

      if (messageResponse.success) {
        _showSuccessSnackBar('${widget.mediaType.capitalize()} sent successfully');
        
        // Navigate back with success result
        Navigator.of(context).pop({
          'success': true,
          'refresh_needed': true,
        });
      } else {
        _showErrorSnackBar(messageResponse.userMessage);
      }
    } catch (e) {
      print('🔥 Error sending media message: $e');
      _showErrorSnackBar('Failed to send ${widget.mediaType}: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  String _createMediaContent(String caption) {
    String baseContent;
    
    switch (widget.mediaType) {
      case 'image':
        baseContent = '📷 Image';
        break;
      case 'video':
        baseContent = '🎥 Video';
        break;
      case 'audio':
        baseContent = widget.filename.toLowerCase().contains('voice') 
            ? '🎤 Voice note' 
            : '🎵 Audio';
        break;
      case 'file':
        baseContent = '📄 ${widget.filename}';
        break;
      default:
        baseContent = '📎 File';
    }
    
    if (caption.isNotEmpty) {
      return '$baseContent\n\n$caption';
    }
    
    return baseContent;
  }

  String _getContactDisplayName(NoboxMessage message) {
    final displayName = message.displayName?.trim();
    final senderName = message.senderName?.trim();
    
    if (displayName != null && displayName.isNotEmpty && displayName != 'null') {
      return displayName;
    }
    
    if (senderName != null && senderName.isNotEmpty && senderName != 'null') {
      return senderName;
    }
    
    return 'Contact';
  }

  void _goBack() {
    Navigator.of(context).pop({
      'success': false,
      'refresh_needed': false,
    });
  }

  void _showSuccessSnackBar(String message) {
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
        backgroundColor: successGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
        backgroundColor: errorRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildMediaPreview() {
    switch (widget.mediaType) {
      case 'image':
        return _buildImagePreview();
      case 'video':
        return _buildVideoPreview();
      case 'audio':
        return _buildAudioPreview();
      case 'file':
        return _buildFilePreview();
      default:
        return _buildGenericPreview();
    }
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
        minHeight: 200,
      ),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.mediaFile != null
            ? Image.file(
                widget.mediaFile!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildErrorPreview('Failed to load image');
                },
              )
            : widget.mediaUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildLoadingPreview(),
                    errorWidget: (context, url, error) => _buildErrorPreview('Failed to load image'),
                  )
                : _buildErrorPreview('No image available'),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.mediaFile != null) ...[
            // For local video file, show thumbnail or video icon
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.video_file,
                size: 64,
                color: Colors.white70,
              ),
            ),
          ],
          
          // Play button overlay
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow,
              size: 40,
              color: Colors.white,
            ),
          ),
          
          // File info overlay
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.filename,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview() {
    final isVoiceNote = widget.filename.toLowerCase().contains('voice');
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVoiceNote 
              ? [const Color(0xFF667eea), const Color(0xFF764ba2)]
              : [const Color(0xFFf093fb), const Color(0xFFf5576c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Icon(
              isVoiceNote ? Icons.mic : Icons.audiotrack,
              size: 40,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            isVoiceNote ? 'Voice Note' : 'Audio File',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.filename,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    final fileIcon = _getFileIcon(widget.filename);
    final fileColor = _getFileColor(widget.filename);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fileColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: fileColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              fileIcon,
              size: 40,
              color: fileColor,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Document File',
            style: TextStyle(
              color: fileColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.filename,
              style: TextStyle(
                color: fileColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericPreview() {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_file,
            size: 48,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 12),
          Text(
            widget.filename,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPreview() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Loading preview...',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPreview(String errorText) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red[400],
          ),
          const SizedBox(height: 12),
          Text(
            errorText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator() {
    if (widget.replyingToMessage == null) return const SizedBox.shrink();
    
    final contactName = _getContactDisplayName(widget.replyingToMessage!);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: replyBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: replyBorderColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: replyBorderColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $contactName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: replyBorderColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.replyingToMessage!.content.length > 60
                      ? '${widget.replyingToMessage!.content.substring(0, 60)}...'
                      : widget.replyingToMessage!.content,
                  style: const TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _captionController,
        focusNode: _focusNode,
        style: GoogleFonts.poppins(fontSize: 16),
        maxLines: null,
        minLines: 1,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: 'Add a caption...',
          hintStyle: const TextStyle(
            color: textSecondary,
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          counterText: '', // Hide character counter
        ),
        textInputAction: TextInputAction.newline,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceWhite,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cancel button
            Expanded(
              child: OutlinedButton(
                onPressed: _isSending ? null : _goBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_isSending || _isUploading || _uploadedFile == null) 
                    ? null 
                    : _sendMediaMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSending 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Sending...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Send ${widget.mediaType.capitalize()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    if (!_isUploading) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _uploadProgress ?? 'Uploading...',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please wait while we prepare your ${widget.mediaType}',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Utility methods for file handling
  IconData _getFileIcon(String filename) {
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
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String filename) {
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
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Send ${widget.mediaType.capitalize()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSending ? null : _goBack,
        ),
        actions: [
          if (_uploadedFile != null && !_isSending && !_isUploading) ...[
            TextButton(
              onPressed: _sendMediaMessage,
              child: const Text(
                'Send',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Reply indicator
          _buildReplyIndicator(),
          
          // Media preview
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Upload progress
                  _buildUploadProgress(),
                  
                  // Media preview
                  _buildMediaPreview(),
                  
                  // Caption input
                  const SizedBox(height: 16),
                  _buildCaptionInput(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }
}

// Extension to capitalize first letter
extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}