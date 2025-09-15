import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../services/user_service.dart';
import '../models/message_model.dart';
import '../utils/channel_renderer.dart';
import '../utils/last_message_renderer.dart';
import '../utils/message_tail_painter.dart';
import '../widget/voice_message_player.dart';
import '../widget/voice_recorder_widget.dart';
import '../widget/enhanced_image_viewer.dart';
import '../widget/video_player_widget.dart';
import '../widget/file_message_widget.dart';
import '../screens/media_compose_screen.dart';
import '../screens/contact_detail_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatLinkModel chatLink;
  final ChannelModel channel;
  final List<AccountModel> accounts;

  const ChatRoomScreen({
    Key? key,
    required this.chatLink,
    required this.channel,
    required this.accounts,
  }) : super(key: key);

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // State Variables
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMoreMessages = true;
  bool _showScrollToBottom = false;
  
  // Data Collections
  List<NoboxMessage> _messages = [];
  NoboxMessage? _replyingToMessage;
  
  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 50;
  
  // Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color myMessageBubble = Color(0xFF007AFF);
  static const Color otherMessageBubble = Color(0xFFE0E0E0);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color replyBorderColor = Color(0xFF34C759);
  static const Color replyBackgroundColor = Color(0xFFF0F8F0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupScrollController();
    _loadMessages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    VoiceService.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      // Show/hide scroll to bottom button
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = showButton;
        });
      }
      
      // Load more messages when scrolled to top
      if (_scrollController.position.pixels <= 100) {
        _loadMoreMessages();
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        take: _pageSize,
        skip: 0,
        orderBy: 'CreatedAt',
        orderDirection: 'desc',
      );

      if (response.success && response.data != null) {
        setState(() {
          _messages = response.data!.reversed.toList();
          _hasMoreMessages = response.data!.length == _pageSize;
        });
        
        _scrollToBottom();
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load messages: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _isLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      
      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        take: _pageSize,
        skip: _currentPage * _pageSize,
        orderBy: 'CreatedAt',
        orderDirection: 'desc',
      );

      if (response.success && response.data != null) {
        final newMessages = response.data!.reversed.toList();
        
        setState(() {
          _messages.insertAll(0, newMessages);
          _hasMoreMessages = response.data!.length == _pageSize;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load more messages: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Create message content with reply if needed
      String finalContent = content;
      if (_replyingToMessage != null) {
        final repliedToName = _getContactDisplayName(_replyingToMessage!);
        final replyPreview = _replyingToMessage!.content.length > 50 
            ? '${_replyingToMessage!.content.substring(0, 50)}...'
            : _replyingToMessage!.content;
        
        finalContent = '> $repliedToName: $replyPreview\n\n$content';
      }

      final response = await ApiService.sendMessageWithAttachment(
        content: finalContent,
        channelId: widget.channel.id,
        linkId: int.tryParse(widget.chatLink.id),
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        bodyType: 1, // Text message
        replyId: _replyingToMessage?.id,
      );

      if (response.success) {
        _messageController.clear();
        _clearReply();
        await _loadMessages(); // Refresh messages
        _scrollToBottom();
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _clearReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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

  Future<void> _showMediaPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: primaryBlue),
              title: Text(
                'Camera',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: primaryBlue),
              title: Text(
                'Gallery',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: primaryBlue),
              title: Text(
                'Document',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await _navigateToMediaCompose(
          mediaFile: file,
          mediaType: 'image',
          filename: pickedFile.name,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickDocument() async {
    // Implementation for document picker
    _showErrorSnackBar('Document picker not implemented yet');
  }

  Future<void> _navigateToMediaCompose({
    File? mediaFile,
    String? mediaUrl,
    required String mediaType,
    required String filename,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MediaComposeScreen(
          mediaFile: mediaFile,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
          filename: filename,
          chatLink: widget.chatLink,
          channel: widget.channel,
          replyingToMessage: _replyingToMessage,
        ),
      ),
    );

    if (result != null && result['success'] == true) {
      _clearReply();
      await _loadMessages();
      _scrollToBottom();
    }
  }

  void _showVoiceRecorder() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VoiceRecorderWidget(
        onVoiceRecorded: (voicePath, duration) async {
          Navigator.pop(context);
          await _navigateToMediaCompose(
            mediaFile: File(voicePath),
            mediaType: 'audio',
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
          );
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showContactDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(
          contactName: widget.chatLink.name,
          contactId: widget.chatLink.id,
          phoneNumber: widget.chatLink.idExt,
          accountType: 'Bot',
          needReply: false,
          muteAiAgent: false,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildAppBar() {
    return Container(
      color: primaryBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
            
            // Contact Avatar
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.chatLink.name.toLowerCase().contains('grup') || 
                widget.chatLink.name.toLowerCase().contains('group')
                  ? Icons.group
                  : Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Contact Info
            Expanded(
              child: GestureDetector(
                onTap: _showContactDetail,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.chatLink.name.isNotEmpty 
                        ? widget.chatLink.name 
                        : 'Chat ${widget.chatLink.id}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.channel.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            IconButton(
              onPressed: () {
                // Show more options
              },
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyIndicator() {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    
    final contactName = _getContactDisplayName(_replyingToMessage!);
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: replyBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: replyBorderColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: replyBorderColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyingToMessage!.content.length > 60
                      ? '${_replyingToMessage!.content.substring(0, 60)}...'
                      : _replyingToMessage!.content,
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
          IconButton(
            onPressed: _clearReply,
            icon: const Icon(
              Icons.close,
              size: 16,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(NoboxMessage message) {
    final isFromMe = message.isFromMe;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            // Contact avatar for incoming messages
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFD3D3D3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
          
          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment: isFromMe 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(message, isFromMe),
                const SizedBox(height: 4),
                _buildMessageMeta(message, isFromMe),
              ],
            ),
          ),
          
          // Tail for message bubble
          if (isFromMe) ...[
            CustomPaint(
              size: const Size(8, 20),
              painter: RightMessageTailPainter(myMessageBubble),
            ),
          ] else ...[
            CustomPaint(
              size: const Size(8, 20),
              painter: LeftMessageTailPainter(otherMessageBubble),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(NoboxMessage message, bool isFromMe) {
    switch (message.bodyType) {
      case 2: // Audio
        return _buildAudioMessage(message, isFromMe);
      case 3: // Image
        return _buildImageMessage(message, isFromMe);
      case 4: // Video
        return _buildVideoMessage(message, isFromMe);
      case 5: // File
        return _buildFileMessage(message, isFromMe);
      case 7: // Sticker
        return _buildStickerMessage(message, isFromMe);
      case 9: // Location
        return _buildLocationMessage(message, isFromMe);
      default: // Text
        return _buildTextMessage(message, isFromMe);
    }
  }

  Widget _buildTextMessage(NoboxMessage message, bool isFromMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isFromMe ? myMessageBubble : otherMessageBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isFromMe ? 18 : 4),
            bottomRight: Radius.circular(isFromMe ? 4 : 18),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isFromMe ? Colors.white : textPrimary,
            fontSize: 14,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildImageMessage(NoboxMessage message, bool isFromMe) {
    String? imageUrl;
    
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      try {
        final attachmentData = jsonDecode(message.attachment!);
        final filename = attachmentData['Filename'] ?? attachmentData['filename'];
        imageUrl = filename?.toString();
      } catch (e) {
        imageUrl = message.attachment;
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildTextMessage(message, isFromMe);
    }

    // Ensure URL is complete
    if (!imageUrl.startsWith('http')) {
      imageUrl = 'https://id.nobox.ai/upload/$imageUrl';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EnhancedImageViewer(
              imageUrl: imageUrl!,
              filename: message.fileName ?? 'image.jpg',
            ),
          ),
        );
      },
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isFromMe ? myMessageBubble : otherMessageBubble,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isFromMe ? Colors.white : textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMessage(NoboxMessage message, bool isFromMe) {
    String? videoUrl;
    
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      try {
        final attachmentData = jsonDecode(message.attachment!);
        final filename = attachmentData['Filename'] ?? attachmentData['filename'];
        videoUrl = filename?.toString();
      } catch (e) {
        videoUrl = message.attachment;
      }
    }

    if (videoUrl == null || videoUrl.isEmpty) {
      return _buildTextMessage(message, isFromMe);
    }

    if (!videoUrl.startsWith('http')) {
      videoUrl = 'https://id.nobox.ai/upload/$videoUrl';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerWidget(
              videoUrl: videoUrl!,
              filename: message.fileName ?? 'video.mp4',
            ),
          ),
        );
      },
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isFromMe ? myMessageBubble : otherMessageBubble,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isFromMe ? Colors.white : textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMessage(NoboxMessage message, bool isFromMe) {
    String? audioUrl;
    
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      try {
        final attachmentData = jsonDecode(message.attachment!);
        final filename = attachmentData['Filename'] ?? attachmentData['filename'];
        audioUrl = filename?.toString();
      } catch (e) {
        audioUrl = message.attachment;
      }
    }

    if (audioUrl == null || audioUrl.isEmpty) {
      return _buildTextMessage(message, isFromMe);
    }

    if (!audioUrl.startsWith('http')) {
      audioUrl = 'https://id.nobox.ai/upload/$audioUrl';
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: VoiceMessagePlayer(
        audioUrl: audioUrl,
        filename: message.fileName ?? 'audio.wav',
        duration: const Duration(seconds: 30),
        isMyMessage: isFromMe,
      ),
    );
  }

  Widget _buildFileMessage(NoboxMessage message, bool isFromMe) {
    String? fileUrl;
    String filename = 'document.pdf';
    int fileSize = 0;
    
    if (message.attachment != null && message.attachment!.isNotEmpty) {
      try {
        final attachmentData = jsonDecode(message.attachment!);
        final filenameFromData = attachmentData['Filename'] ?? attachmentData['filename'];
        final originalName = attachmentData['OriginalName'] ?? attachmentData['originalName'];
        final size = attachmentData['Size'] ?? attachmentData['size'];
        
        fileUrl = filenameFromData?.toString();
        filename = originalName?.toString() ?? filename;
        fileSize = int.tryParse(size?.toString() ?? '0') ?? 0;
      } catch (e) {
        fileUrl = message.attachment;
      }
    }

    if (fileUrl == null || fileUrl.isEmpty) {
      return _buildTextMessage(message, isFromMe);
    }

    if (!fileUrl.startsWith('http')) {
      fileUrl = 'https://id.nobox.ai/upload/$fileUrl';
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: FileMessageWidget(
        fileUrl: fileUrl,
        filename: filename,
        fileSize: fileSize,
        isMyMessage: isFromMe,
      ),
    );
  }

  Widget _buildStickerMessage(NoboxMessage message, bool isFromMe) {
    // Implementation for sticker messages
    return _buildTextMessage(message, isFromMe);
  }

  Widget _buildLocationMessage(NoboxMessage message, bool isFromMe) {
    // Implementation for location messages
    return _buildTextMessage(message, isFromMe);
  }

  Widget _buildMessageMeta(NoboxMessage message, bool isFromMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isFromMe) ...[
            Text(
              _getContactDisplayName(message),
              style: const TextStyle(
                fontSize: 11,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _formatMessageTime(message.createdAt),
            style: const TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
          if (isFromMe) ...[
            const SizedBox(width: 4),
            _buildMessageStatus(message),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageStatus(NoboxMessage message) {
    IconData icon;
    Color color;
    
    switch (message.ack) {
      case 1:
        icon = Icons.access_time;
        color = Colors.grey;
        break;
      case 2:
        icon = Icons.done;
        color = Colors.grey;
        break;
      case 3:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case 5:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case 4:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      default:
        icon = Icons.access_time;
        color = Colors.grey;
    }
    
    return Icon(
      icon,
      size: 12,
      color: color,
    );
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showMessageOptions(NoboxMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: primaryBlue),
              title: Text(
                'Reply',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingToMessage = message;
                });
                _messageFocusNode.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: primaryBlue),
              title: Text(
                'Copy',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Reply indicator
            _buildReplyIndicator(),
            
            // Input row
            Row(
              children: [
                // Attachment button
                IconButton(
                  onPressed: _showMediaPicker,
                  icon: const Icon(
                    Icons.attach_file,
                    color: primaryBlue,
                    size: 24,
                  ),
                ),
                
                // Text input
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      style: GoogleFonts.poppins(fontSize: 16),
                      maxLines: null,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(
                          color: textSecondary,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                
                // Voice/Send button
                IconButton(
                  onPressed: _messageController.text.trim().isNotEmpty || _isSending
                    ? _sendMessage
                    : _showVoiceRecorder,
                  icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                        ),
                      )
                    : Icon(
                        _messageController.text.trim().isNotEmpty
                          ? Icons.send
                          : Icons.mic,
                        color: primaryBlue,
                        size: 24,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    if (!_showScrollToBottom) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      right: 16,
      child: FloatingActionButton.small(
        onPressed: _scrollToBottom,
        backgroundColor: primaryBlue,
        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          strokeWidth: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // App Bar
          _buildAppBar(),
          
          // Messages
          Expanded(
            child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      reverse: false,
                      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0 && _isLoadingMore) {
                          return _buildLoadingMoreIndicator();
                        }
                        
                        final messageIndex = _isLoadingMore ? index - 1 : index;
                        if (messageIndex >= _messages.length) {
                          return const SizedBox.shrink();
                        }
                        
                        return _buildMessageBubble(_messages[messageIndex]);
                      },
                    ),
                    
                    // Scroll to bottom button
                    _buildScrollToBottomButton(),
                  ],
                ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }
}