import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../services/user_service.dart';
import '../models/message_model.dart';
import '../utils/last_message_renderer.dart';
import '../utils/message_tail_painter.dart';
import '../widget/voice_message_player.dart';
import '../widget/voice_recorder_widget.dart';
import '../widget/enhanced_image_viewer.dart';
import '../widget/video_player_widget.dart';
import '../widget/file_message_widget.dart';
import 'media_compose_screen.dart';
import 'contact_detail_screen.dart';

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

class _ChatRoomScreenState extends State<ChatRoomScreen> with TickerProviderStateMixin {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // State
  List<NoboxMessage> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMoreMessages = true;
  NoboxMessage? _replyingToMessage;
  bool _showVoiceRecorder = false;
  
  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 50;
  
  // Real-time updates
  Timer? _realTimeTimer;
  
  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  
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
    _setupAnimations();
    _setupScrollController();
    _loadMessages();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _realTimeTimer?.cancel();
    super.dispose();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
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
          _hasMoreMessages = response.data!.length >= _pageSize;
          _currentPage = 0;
        });
        
        _scrollToBottom();
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      print('🔥 Error loading messages: $e');
      _showErrorSnackBar('Failed to load messages: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        take: _pageSize,
        skip: nextPage * _pageSize,
        orderBy: 'CreatedAt',
        orderDirection: 'desc',
      );

      if (response.success && response.data != null) {
        final newMessages = response.data!.reversed.toList();
        
        setState(() {
          _messages.insertAll(0, newMessages);
          _currentPage = nextPage;
          _hasMoreMessages = newMessages.length >= _pageSize;
        });
      }
    } catch (e) {
      print('🔥 Error loading more messages: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForNewMessages();
    });
  }

  Future<void> _checkForNewMessages() async {
    if (_messages.isEmpty) return;

    try {
      final lastMessage = _messages.last;
      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        take: 10,
        skip: 0,
        orderBy: 'CreatedAt',
        orderDirection: 'desc',
      );

      if (response.success && response.data != null) {
        final newMessages = response.data!.where((msg) {
          return msg.createdAt.isAfter(lastMessage.createdAt);
        }).toList();

        if (newMessages.isNotEmpty) {
          setState(() {
            _messages.addAll(newMessages);
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('🔥 Error checking for new messages: $e');
    }
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Create optimistic message
      final tempMessage = NoboxMessage(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        senderId: UserService.currentUserId ?? 'me',
        content: content,
        createdAt: DateTime.now(),
        linkId: int.tryParse(widget.chatLink.id) ?? 0,
        channelId: widget.channel.id,
        bodyType: 1,
        isIncoming: false,
        roomId: 0,
      );

      // Add to UI immediately
      setState(() {
        _messages.add(tempMessage);
        _messageController.clear();
        _replyingToMessage = null;
      });
      
      _scrollToBottom();

      // Send to server
      final response = await ApiService.sendMessage(
        content: content,
        channelId: widget.channel.id,
        linkId: int.tryParse(widget.chatLink.id),
        linkIdExt: widget.chatLink.idExt.isNotEmpty ? widget.chatLink.idExt : null,
        replyId: _replyingToMessage?.id,
      );

      if (response.success) {
        // Replace temp message with real one
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = tempMessage.copyWith(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              ack: 2,
            );
          }
        });
      } else {
        // Mark as failed
        setState(() {
          final index = _messages.indexWhere((msg) => msg.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = tempMessage.copyWith(
              id: 'failed_${tempMessage.id}',
              ack: 4,
            );
          }
        });
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      print('🔥 Error sending message: $e');
      _showErrorSnackBar('Failed to send message: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _setReplyMessage(NoboxMessage message) {
    setState(() {
      _replyingToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        await _navigateToMediaCompose(
          mediaFile: file,
          mediaType: 'image',
          filename: pickedFile.name,
        );
      }
    } catch (e) {
      print('🔥 Error picking image: $e');
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final filename = result.files.first.name;
        
        String mediaType = 'file';
        if (filename.toLowerCase().endsWith('.jpg') || 
            filename.toLowerCase().endsWith('.jpeg') || 
            filename.toLowerCase().endsWith('.png') || 
            filename.toLowerCase().endsWith('.gif')) {
          mediaType = 'image';
        } else if (filename.toLowerCase().endsWith('.mp4') || 
                   filename.toLowerCase().endsWith('.mov') || 
                   filename.toLowerCase().endsWith('.avi')) {
          mediaType = 'video';
        } else if (filename.toLowerCase().endsWith('.mp3') || 
                   filename.toLowerCase().endsWith('.wav') || 
                   filename.toLowerCase().endsWith('.aac')) {
          mediaType = 'audio';
        }

        await _navigateToMediaCompose(
          mediaFile: file,
          mediaType: mediaType,
          filename: filename,
        );
      }
    } catch (e) {
      print('🔥 Error picking file: $e');
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  Future<void> _navigateToMediaCompose({
    File? mediaFile,
    String? mediaUrl,
    required String mediaType,
    required String filename,
  }) async {
    final result = await Navigator.push(
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
      if (result['refresh_needed'] == true) {
        _loadMessages();
      }
    }
  }

  void _showVoiceRecorder() {
    setState(() {
      _showVoiceRecorder = true;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceRecorderWidget(
        onVoiceRecorded: (voicePath, duration) async {
          setState(() {
            _showVoiceRecorder = false;
          });
          
          Navigator.pop(context);
          
          final file = File(voicePath);
          await _navigateToMediaCompose(
            mediaFile: file,
            mediaType: 'audio',
            filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.wav',
          );
        },
        onCancel: () {
          setState(() {
            _showVoiceRecorder = false;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showContactDetails() {
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
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

  Widget _buildMessageBubble(NoboxMessage message) {
    final isFromMe = message.isFromMe;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromMe) ...[
            // Contact avatar
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
              crossAxisAlignment: isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name (for incoming messages)
                if (!isFromMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Text(
                      _getContactDisplayName(message),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                // Message bubble
                Row(
                  mainAxisAlignment: isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Message tail (left side for incoming)
                    if (!isFromMe)
                      CustomPaint(
                        size: const Size(8, 20),
                        painter: LeftMessageTailPainter(otherMessageBubble),
                      ),
                    
                    // Message content
                    Flexible(
                      child: _buildMessageContent(message, isFromMe),
                    ),
                    
                    // Message tail (right side for outgoing)
                    if (isFromMe)
                      CustomPaint(
                        size: const Size(8, 20),
                        painter: RightMessageTailPainter(myMessageBubble),
                      ),
                  ],
                ),
                
                // Message metadata
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isFromMe ? 0 : 12,
                    right: isFromMe ? 12 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.createdAt),
                        style: GoogleFonts.poppins(
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
                ),
              ],
            ),
          ),
          
          if (isFromMe) ...[
            // User avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8, bottom: 4),
              decoration: const BoxDecoration(
                color: primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(NoboxMessage message, bool isFromMe) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply indicator
            if (message.hasReply)
              _buildReplyIndicator(message, isFromMe),
            
            // Message content based on type
            _buildMessageTypeContent(message, isFromMe),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypeContent(NoboxMessage message, bool isFromMe) {
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
    return Text(
      message.content,
      style: TextStyle(
        color: isFromMe ? Colors.white : textPrimary,
        fontSize: 14,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildImageMessage(NoboxMessage message, bool isFromMe) {
    return GestureDetector(
      onTap: () {
        if (message.attachment != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedImageViewer(
                imageUrl: message.attachment!,
                filename: message.fileName ?? 'image.jpg',
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: message.attachment != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachment!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image, size: 48),
                        );
                      },
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 48),
                  ),
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.content,
              style: TextStyle(
                color: isFromMe ? Colors.white : textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoMessage(NoboxMessage message, bool isFromMe) {
    return GestureDetector(
      onTap: () {
        if (message.attachment != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayerWidget(
                videoUrl: message.attachment!,
                filename: message.fileName ?? 'video.mp4',
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (message.attachment != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      message.attachment!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.video_file, size: 48, color: Colors.white),
                        );
                      },
                    ),
                  ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message.content,
              style: TextStyle(
                color: isFromMe ? Colors.white : textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioMessage(NoboxMessage message, bool isFromMe) {
    return VoiceMessagePlayer(
      audioUrl: message.attachment ?? '',
      filename: message.fileName ?? 'audio.wav',
      isMyMessage: isFromMe,
    );
  }

  Widget _buildFileMessage(NoboxMessage message, bool isFromMe) {
    return FileMessageWidget(
      fileUrl: message.attachment ?? '',
      filename: message.fileName ?? 'document.pdf',
      fileSize: 0, // You might want to get this from the message
      isMyMessage: isFromMe,
    );
  }

  Widget _buildStickerMessage(NoboxMessage message, bool isFromMe) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: message.attachment != null
          ? Image.network(
              message.attachment!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.emoji_emotions, size: 48),
                );
              },
            )
          : const Center(
              child: Icon(Icons.emoji_emotions, size: 48),
            ),
    );
  }

  Widget _buildLocationMessage(NoboxMessage message, bool isFromMe) {
    return GestureDetector(
      onTap: () {
        // Parse location data and open maps
        final locationParts = message.content.split('[-{=||=}-]');
        if (locationParts.length >= 2) {
          final lat = locationParts[0];
          final lng = locationParts[1];
          final locationName = locationParts.length > 2 ? locationParts[2] : '';
          
          final mapUrl = locationName.isNotEmpty
              ? 'https://www.google.com/maps/search/$locationName/@$lat,$lng,21z'
              : 'https://www.google.com/maps?q=$lat,$lng&z=21';
          
          // Launch URL (you'll need url_launcher package)
          print('🔥 Opening map: $mapUrl');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 48, color: Colors.red),
                  SizedBox(height: 8),
                  Text('Location', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          if (message.content.contains('[-{=||=}-]')) ...[
            const SizedBox(height: 8),
            Text(
              message.content.split('[-{=||=}-]').length > 2 
                  ? message.content.split('[-{=||=}-]')[2]
                  : 'Shared Location',
              style: TextStyle(
                color: isFromMe ? Colors.white : textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(NoboxMessage message, bool isFromMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isFromMe 
            ? Colors.white.withOpacity(0.2)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isFromMe ? Colors.white : primaryBlue,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to ${_getContactDisplayName(message)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFromMe ? Colors.white : primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.replyMsg ?? 'Message',
            style: TextStyle(
              fontSize: 11,
              color: isFromMe ? Colors.white70 : textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
      size: 14,
      color: color,
    );
  }

  void _showMessageOptions(NoboxMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                _setReplyMessage(message);
              },
            ),
            if (message.isFromMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content));
                _showSuccessSnackBar('Message copied to clipboard');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(NoboxMessage message) async {
    try {
      final response = await ApiService.deleteMessage(
        messageId: message.id,
        roomId: widget.chatLink.id,
      );

      if (response.success) {
        setState(() {
          _messages.removeWhere((msg) => msg.id == message.id);
        });
        _showSuccessSnackBar('Message deleted');
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      print('🔥 Error deleting message: $e');
      _showErrorSnackBar('Failed to delete message: $e');
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildReplyPreview() {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    
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
                  'Replying to ${_getContactDisplayName(_replyingToMessage!)}',
                  style: TextStyle(
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
          GestureDetector(
            onTap: _clearReply,
            child: Icon(
              Icons.close,
              size: 20,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button
            GestureDetector(
              onTap: _showAttachmentOptions,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: primaryBlue,
                  size: 24,
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Message input
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
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Send/Voice button
            GestureDetector(
              onTap: _messageController.text.trim().isNotEmpty 
                  ? _sendMessage 
                  : _showVoiceRecorder,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(
                        _messageController.text.trim().isNotEmpty 
                            ? Icons.send 
                            : Icons.mic,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('Voice Message'),
              onTap: () {
                Navigator.pop(context);
                _showVoiceRecorder();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMessage(NoboxMessage message, bool isFromMe) {
    return Row(
      children: [
        Icon(
          Icons.audiotrack,
          color: isFromMe ? Colors.white : textPrimary,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audio Message',
                style: TextStyle(
                  color: isFromMe ? Colors.white : textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                message.fileName ?? 'audio.wav',
                style: TextStyle(
                  color: isFromMe ? Colors.white70 : textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            // Play audio
            if (message.attachment != null) {
              VoiceService.playVoiceMessage(message.attachment!);
            }
          },
          child: Icon(
            Icons.play_circle_fill,
            color: isFromMe ? Colors.white : primaryBlue,
            size: 32,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: _showContactDetails,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chatLink.name.isNotEmpty 
                          ? widget.chatLink.name 
                          : 'Chat ${widget.chatLink.id}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.channel.name,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'archive':
                  _archiveConversation();
                  break;
                case 'resolve':
                  _markAsResolved();
                  break;
                case 'refresh':
                  _loadMessages();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, size: 20),
                    SizedBox(width: 12),
                    Text('Archive'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resolve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 12),
                    Text('Mark as Resolved'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Reply preview
          _buildReplyPreview(),
          
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation by sending a message',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == 0 && _isLoadingMore) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          
                          final messageIndex = _isLoadingMore ? index - 1 : index;
                          return _buildMessageBubble(_messages[messageIndex]);
                        },
                      ),
          ),
          
          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Future<void> _archiveConversation() async {
    try {
      final response = await ApiService.archiveConversation(widget.chatLink.id);
      
      if (response.success) {
        _showSuccessSnackBar('Conversation archived');
        Navigator.pop(context, {'refresh_needed': true});
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      print('🔥 Error archiving conversation: $e');
      _showErrorSnackBar('Failed to archive conversation: $e');
    }
  }

  Future<void> _markAsResolved() async {
    try {
      final response = await ApiService.markAsResolved(widget.chatLink.id);
      
      if (response.success) {
        _showSuccessSnackBar('Conversation marked as resolved');
        Navigator.pop(context, {'refresh_needed': true});
      } else {
        _showErrorSnackBar(response.userMessage);
      }
    } catch (e) {
      print('🔥 Error marking as resolved: $e');
      _showErrorSnackBar('Failed to mark as resolved: $e');
    }
  }
}