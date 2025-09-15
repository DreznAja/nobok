import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:nobox_mobile/services/link_resolver.dart';
import 'package:nobox_mobile/services/user_service.dart';
import 'package:nobox_mobile/services/media_service.dart';
import 'package:nobox_mobile/services/voice_service.dart';
import 'package:nobox_mobile/widget/enhanced_image_viewer.dart';
import 'package:nobox_mobile/widget/voice_recorder_widget.dart';
import 'package:nobox_mobile/widget/voice_message_player.dart';
import 'package:nobox_mobile/screens/media_compose_screen.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/message_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'contact_detail_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nobox_mobile/utils/message_tail_painter.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showAttachmentMenu = false;
  OverlayEntry? _attachmentOverlay;
  bool _isUploading = false;
  String? _uploadProgress;
  bool _showVoiceRecorder = false;

  List<NoboxMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _shouldAutoScroll = true;

  // ✅ NEW: Message selection and action mode
  NoboxMessage? _selectedMessage;
  bool _isActionMode = false;

  // ✅ ENHANCED: Reply functionality with proper message structure
  NoboxMessage? _replyingToMessage;
  bool _isReplying = false;

  // ✅ NEW: Forward functionality
  NoboxMessage? _forwardingMessage;
  bool _isForwarding = false;
  List<ChatLinkModel> _availableChats = [];

  // ✅ ENHANCED: Pin functionality with persistence
  List<String> _pinnedMessageIds = []; // Store only IDs for persistence
  bool _showPinnedMessages = false;
  final GlobalKey<AnimatedListState> _pinnedListKey =
      GlobalKey<AnimatedListState>();

  // ✅ NEW: Animation for jumping to messages
  final GlobalKey _messagesListKey = GlobalKey();
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  StreamSubscription<List<NoboxMessage>>? _messageStreamSubscription;
  Timer? _debounceTimer;
  Timer? _realTimeTimer;
  Timer? _heartbeatTimer;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _replyAnimationController;
  late AnimationController _actionModeController;
  late AnimationController _highlightAnimationController;
  late AnimationController _forwardAnimationController;

  final Set<String> _processedMessageIds = <String>{};
  final Map<String, NoboxMessage> _temporaryMessages = <String, NoboxMessage>{};
  final Map<String, NoboxMessage> _messageCache = <String, NoboxMessage>{};

  DateTime? _lastMessageTimestamp;
  int _lastKnownMessageCount = 0;

  bool _userHasScrolled = false;
  double _lastScrollPosition = 0.0;
  Timer? _scrollDebouncer;
  bool _isAppInForeground = true;

  // Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color myMessageBubble = Color(0xFF007AFF);
  static const Color otherMessageBubble = Color(0xFFE0E0E0);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);
  static const Color replyBorderColor = Color(0xFF34C759);
  static const Color pinColor = Color(0xFFFF9500);
  static const Color replyBackgroundColor = Color(0xFFF0F8F0);
  static const Color forwardColor = Color(0xFF007AFF);
  static const Color forwardBackgroundColor = Color(0xFFF0F4FF);
  // ✅ NEW: Link colors
  static const Color linkColor = Color(0xFF1976D2);
  static const Color linkBackgroundColor = Color(0xFFF3F7FF);
  static const Color visitedLinkColor = Color(0xFF673AB7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _replyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _actionModeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _highlightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _forwardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _setupScrollController();
    _initializeServices();
    _loadPinnedMessages(); // ✅ Load pinned messages from storage
    _initializeChat();
    _loadAvailableChats(); // ✅ Load available chats for forwarding
    _fadeController.forward();

    final linkIdInt = int.tryParse(widget.chatLink.id);
    if ((widget.chatLink.idExt.isNotEmpty) &&
        linkIdInt != null &&
        linkIdInt > 0) {
      LinkResolver.seedOne(linkIdExt: widget.chatLink.idExt, linkId: linkIdInt);
      print('🔥 Seeded LinkResolver: ${widget.chatLink.idExt} -> $linkIdInt');
    }
  }

  // ✅ NEW: Link detection and handling functions
  bool _containsLinks(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    final emailPattern = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    );

    return urlPattern.hasMatch(text) || emailPattern.hasMatch(text);
  }

  List<Map<String, dynamic>> _extractLinks(String text) {
    final List<Map<String, dynamic>> links = [];

    // URL pattern
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    // Email pattern
    final emailPattern = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    );

    // Extract URLs
    urlPattern.allMatches(text).forEach((match) {
      final url = match.group(0);
      if (url != null) {
        links.add({
          'text': url,
          'url': url,
          'type': 'url',
          'start': match.start,
          'end': match.end,
        });
      }
    });

    // Extract emails
    emailPattern.allMatches(text).forEach((match) {
      final email = match.group(0);
      if (email != null) {
        links.add({
          'text': email,
          'url': 'mailto:$email',
          'type': 'email',
          'start': match.start,
          'end': match.end,
        });
      }
    });

    // Sort by start position to maintain order
    links.sort((a, b) => a['start'].compareTo(b['start']));
    return links;
  }

  Future<void> _openLink(String url, String type) async {
    try {
      final Uri uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _showSuccessSnackBar(
            'Opening ${type == 'email' ? 'email client' : 'link'}');
      } else {
        // Copy to clipboard as fallback
        await Clipboard.setData(ClipboardData(text: url));
        _showWarningSnackBar('Cannot open link, copied to clipboard instead');
      }
    } catch (e) {
      print('🔥 Error opening link: $e');
      // Copy to clipboard as fallback
      await Clipboard.setData(ClipboardData(text: url));
      _showWarningSnackBar('Error opening link, copied to clipboard');
    }
  }

  void _showLinkPreview(String url, String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: linkColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    type == 'email' ? Icons.email : Icons.link,
                    color: linkColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type == 'email' ? 'Email Address' : 'Web Link',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        url,
                        style: TextStyle(
                          fontSize: 14,
                          color: linkColor,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Clipboard.setData(ClipboardData(text: url));
                      _showSuccessSnackBar('Link copied to clipboard');
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openLink(url, type);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: linkColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildRichText(String text, bool isAgentMessage) {
    if (!_containsLinks(text)) {
      // No links found, return regular text
      return Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isAgentMessage ? Colors.white : textPrimary,
        ),
        softWrap: true,
      );
    }

    final links = _extractLinks(text);
    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final link in links) {
      final start = link['start'] as int;
      final end = link['end'] as int;
      final linkText = link['text'] as String;
      final linkUrl = link['url'] as String;
      final linkType = link['type'] as String;

      // Add text before the link
      if (currentIndex < start) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, start),
          style: TextStyle(
            fontSize: 14,
            color: isAgentMessage ? Colors.white : textPrimary,
          ),
        ));
      }

      // Add the link
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          fontSize: 14,
          color: isAgentMessage ? Colors.white : linkColor,
          decoration: TextDecoration.underline,
          decorationColor: isAgentMessage ? Colors.white : linkColor,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _showLinkPreview(linkUrl, linkType),
      ));

      currentIndex = end;
    }

    // Add remaining text after the last link
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(
          fontSize: 14,
          color: isAgentMessage ? Colors.white : textPrimary,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
    );
  }

  Widget _buildLinkIndicator(bool isAgentMessage, int linkCount) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAgentMessage
            ? Colors.white.withOpacity(0.15)
            : linkBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAgentMessage
              ? Colors.white.withOpacity(0.3)
              : linkColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.link,
            size: 14,
            color: isAgentMessage ? Colors.white.withOpacity(0.8) : linkColor,
          ),
          const SizedBox(width: 6),
          Text(
            '$linkCount ${linkCount == 1 ? 'link' : 'links'} detected',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isAgentMessage ? Colors.white.withOpacity(0.8) : linkColor,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Load available chats for forwarding
  Future<void> _loadAvailableChats() async {
    try {
      final response = await ApiService.getChatLinks(
        channelId: widget.channel.id,
        take: 100,
      );

      if (response.success && response.data != null) {
        setState(() {
          _availableChats = response.data!
              .where((chat) =>
                  chat.id != widget.chatLink.id) // Exclude current chat
              .toList();
        });
        print(
            '🔥 Loaded ${_availableChats.length} available chats for forwarding');
      }
    } catch (e) {
      print('🔥 Error loading available chats: $e');
    }
  }

  // ✅ NEW: Persistent pin storage methods (kept same as before)
  String get _pinnedMessagesKey =>
      'pinned_messages_${widget.chatLink.id}_${widget.channel.id}';

  Future<void> _loadPinnedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pinnedData = prefs.getStringList(_pinnedMessagesKey) ?? [];
      setState(() {
        _pinnedMessageIds = pinnedData;
      });
      print(
          '🔥 Loaded ${_pinnedMessageIds.length} pinned message IDs from storage');
    } catch (e) {
      print('🔥 Error loading pinned messages: $e');
    }
  }

  Future<void> _savePinnedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pinnedMessagesKey, _pinnedMessageIds);
      print(
          '🔥 Saved ${_pinnedMessageIds.length} pinned message IDs to storage');
    } catch (e) {
      print('🔥 Error saving pinned messages: $e');
    }
  }

  // ✅ ENHANCED: Get pinned messages from current message list
  List<NoboxMessage> get _pinnedMessages {
    return _messages
        .where((message) => _pinnedMessageIds.contains(message.id))
        .toList();
  }

  Future<void> _initializeServices() async {
    try {
      await VoiceService.initialize();
      print('🔥 Voice service initialized');
    } catch (e) {
      print('🔥 Error initializing voice service: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('🔥 App resumed - refreshing messages and reloading pins');
        _isAppInForeground = true;
        _loadPinnedMessages(); // ✅ Reload pins when app resumes
        _refreshMessages();
        _startAggressiveRealTimeUpdates();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        print('🔥 App paused/inactive - saving pins');
        _isAppInForeground = false;
        _savePinnedMessages(); // ✅ Save pins when app pauses
        _realTimeTimer?.cancel();
        break;
      case AppLifecycleState.detached:
        _cleanup();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      final currentPosition = _scrollController.position.pixels;
      final maxScroll = _scrollController.position.maxScrollExtent;

      if ((maxScroll - currentPosition) > 100) {
        if (!_userHasScrolled) {
          setState(() {
            _userHasScrolled = true;
            _shouldAutoScroll = false;
          });
          print('🔥 User scrolled away from bottom - disabling auto scroll');
        }
      } else if ((maxScroll - currentPosition) <= 50) {
        if (_userHasScrolled) {
          setState(() {
            _userHasScrolled = false;
            _shouldAutoScroll = true;
          });
          print('🔥 User scrolled back to bottom - enabling auto scroll');
        }
      }

      _lastScrollPosition = currentPosition;
    });
  }

  @override
  void dispose() {
    _hideAttachmentMenu();
    _savePinnedMessages(); // ✅ Save pins when disposing
    _cleanup();
    VoiceService.dispose();
    super.dispose();
  }

  void _cleanup() {
    WidgetsBinding.instance.removeObserver(this);
    _messageStreamSubscription?.cancel();
    _debounceTimer?.cancel();
    _realTimeTimer?.cancel();
    _heartbeatTimer?.cancel();
    _scrollDebouncer?.cancel();
    _highlightTimer?.cancel();
    ApiService.stopMessagePolling();
    _fadeController.dispose();
    _slideController.dispose();
    _replyAnimationController.dispose();
    _actionModeController.dispose();
    _highlightAnimationController.dispose();
    _forwardAnimationController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
  }

  void _enterActionMode(NoboxMessage message) {
    setState(() {
      _selectedMessage = message;
      _isActionMode = true;
    });
    _actionModeController.forward();
    HapticFeedback.mediumImpact();
  }

  void _exitActionMode() {
    _actionModeController.reverse().then((_) {
      setState(() {
        _selectedMessage = null;
        _isActionMode = false;
      });
    });
  }

  // ✅ ENHANCED: Reply functionality with proper message structure
  void _startReply(NoboxMessage message) {
    _exitActionMode();
    setState(() {
      _replyingToMessage = message;
      _isReplying = true;
    });
    _replyAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  void _cancelReply() {
    _replyAnimationController.reverse().then((_) {
      setState(() {
        _replyingToMessage = null;
        _isReplying = false;
      });
    });
  }

  // ✅ NEW: Forward functionality
  void _startForward(NoboxMessage message) {
    _exitActionMode();
    setState(() {
      _forwardingMessage = message;
      _isForwarding = true;
    });
    _forwardAnimationController.forward();
    _showForwardDialog();
  }

  void _cancelForward() {
    _forwardAnimationController.reverse().then((_) {
      setState(() {
        _forwardingMessage = null;
        _isForwarding = false;
      });
    });
  }

  // ✅ NEW: Show forward dialog
  void _showForwardDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildForwardDialog(),
    );
  }

  // ✅ NEW: Build forward dialog
  Widget _buildForwardDialog() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.forward, color: forwardColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Forward Message',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Select a chat to forward this message',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _cancelForward();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),

          // Message preview
          if (_forwardingMessage != null) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: forwardBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: forwardColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.forward, size: 16, color: forwardColor),
                      const SizedBox(width: 6),
                      Text(
                        'Forwarded from ${_getContactDisplayName(_forwardingMessage!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: forwardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _forwardingMessage!.content.length > 100
                        ? '${_forwardingMessage!.content.substring(0, 100)}...'
                        : _forwardingMessage!.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textPrimary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_forwardingMessage!.attachment != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _getAttachmentIcon(_forwardingMessage!),
                          size: 16,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Has attachment',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Chat list
          Expanded(
            child: _availableChats.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No other chats available',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _availableChats.length,
                    itemBuilder: (context, index) {
                      final chat = _availableChats[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: primaryBlue,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          chat.name.isNotEmpty ? chat.name : 'Chat ${chat.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          chat.idExt.isNotEmpty ? chat.idExt : 'ID: ${chat.id}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: textSecondary,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await _forwardMessageTo(chat);
                          _cancelForward();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Forward message to selected chat
  Future<void> _forwardMessageTo(ChatLinkModel targetChat) async {
    if (_forwardingMessage == null) return;

    try {
      setState(() {
        _isSending = true;
      });

      // Create forwarded content
      final originalSender = _getContactDisplayName(_forwardingMessage!);
      final forwardedContent =
          _createForwardedContent(_forwardingMessage!, originalSender);

      print('🔥 Forwarding message to chat: ${targetChat.name}');
      print('🔥 Forwarded content: $forwardedContent');

      // Send the forwarded message
      final response = await ApiService.sendMessage(
        content: forwardedContent,
        channelId: widget.channel.id,
        linkId: int.parse(targetChat.id),
        linkIdExt: targetChat.idExt,
        bodyType: _forwardingMessage!.bodyType,
        attachment: _forwardingMessage!.attachment,
      );

      if (response.success) {
        _showSuccessSnackBar('Message forwarded to ${targetChat.name}');
        HapticFeedback.lightImpact();
      } else {
        _showErrorSnackBar(
            'Failed to forward message: ${response.userMessage}');
      }
    } catch (e) {
      print('🔥 Error forwarding message: $e');
      _showErrorSnackBar('Error forwarding message: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  // ✅ NEW: Create forwarded content format
  String _createForwardedContent(NoboxMessage message, String originalSender) {
    // Format: ↪️ Forwarded from OriginalSender\n\nOriginalContent
    return '↪️ Forwarded from $originalSender\n\n${message.content}';
  }

  // ✅ NEW: Get attachment icon
  IconData _getAttachmentIcon(NoboxMessage message) {
    switch (message.bodyType) {
      case 2:
        return Icons.audiotrack;
      case 3:
        return Icons.image;
      case 4:
        return Icons.video_library;
      case 5:
        return Icons.attach_file;
      default:
        return Icons.attach_file;
    }
  }

  // ✅ ENHANCED: Pin functionality with persistence
  Future<void> _togglePinMessage(NoboxMessage message) async {
    _exitActionMode();
    setState(() {
      if (_pinnedMessageIds.contains(message.id)) {
        // Unpin message
        _pinnedMessageIds.remove(message.id);
        _showSuccessSnackBar('Message unpinned');
      } else {
        // Pin message
        _pinnedMessageIds.add(message.id);
        _showSuccessSnackBar('Message pinned');
      }
    });
    // ✅ Save immediately after toggling
    await _savePinnedMessages();
  }

  bool _isMessagePinned(NoboxMessage message) {
    return _pinnedMessageIds.contains(message.id);
  }

  void _togglePinnedMessagesView() {
    setState(() {
      _showPinnedMessages = !_showPinnedMessages;
    });
  }

  // ✅ ENHANCED: Reply data structure
  Map<String, dynamic>? _extractReplyData(String content) {
    // Check for reply pattern: > SenderName: ReplyContent\n\nActualMessage
    final replyPattern =
        RegExp(r'^>\s*([^:]+):\s*(.+?)\n\n(.+)$', dotAll: true);
    final match = replyPattern.firstMatch(content);

    if (match != null) {
      return {
        'repliedToSender': match.group(1)?.trim(),
        'repliedToContent': match.group(2)?.trim(),
        'actualContent': match.group(3)?.trim(),
      };
    }

    return null;
  }

  // ✅ NEW: Extract forward data
  Map<String, dynamic>? _extractForwardData(String content) {
    // Check for forward pattern: ↪️ Forwarded from OriginalSender\n\nOriginalContent
    final forwardPattern =
        RegExp(r'^↪️\s*Forwarded from\s*([^\n]+)\n\n(.+)$', dotAll: true);
    final match = forwardPattern.firstMatch(content);

    if (match != null) {
      return {
        'originalSender': match.group(1)?.trim(),
        'originalContent': match.group(2)?.trim(),
      };
    }

    return null;
  }

  // ✅ NEW: Get proper contact name for a message
  String _getContactDisplayName(NoboxMessage message) {
    // If it's an agent message, return "You"
    if (_isAgentMessage(message)) {
      return 'You';
    }

    // Try to get display name first, then sender name
    final displayName = message.displayName?.trim();
    final senderName = message.senderName?.trim();
    final senderId = message.senderId?.trim();

    if (displayName != null &&
        displayName.isNotEmpty &&
        displayName != 'null') {
      return displayName;
    }

    if (senderName != null && senderName.isNotEmpty && senderName != 'null') {
      return senderName;
    }

    // Try to extract name from chatLink if available
    final chatName = widget.chatLink.name?.trim();
    if (chatName != null && chatName.isNotEmpty && chatName != 'null') {
      return chatName;
    }

    // Try to use idExt if it looks like a phone number (format as name)
    final idExt = widget.chatLink.idExt?.trim();
    if (idExt != null && idExt.isNotEmpty) {
      if (idExt.startsWith('+') || idExt.contains('62')) {
        // It's a phone number, format it nicely
        return 'Contact ${idExt.replaceAll('+', '')}';
      }
      return idExt;
    }

    // Fallback to formatted sender ID
    if (senderId != null && senderId.isNotEmpty) {
      return 'Contact ${senderId.substring(0, 8)}...';
    }

    return 'Unknown Contact';
  }

  // ✅ ENHANCED: Find original message that was replied to
  NoboxMessage? _findOriginalMessage(Map<String, dynamic> replyData) {
    final repliedToSender = replyData['repliedToSender'];
    final repliedToContent = replyData['repliedToContent'];

    // Search through messages to find the original
    for (final message in _messages.reversed) {
      final messageContactName = _getContactDisplayName(message);

      // Match by sender name and content
      if (messageContactName == repliedToSender) {
        // Check if content matches (either exact or truncated)
        final originalContent = message.content.trim();
        final replyContent = repliedToContent?.trim() ?? '';

        if (originalContent == replyContent ||
            originalContent.startsWith(replyContent) ||
            replyContent.startsWith(originalContent.substring(0,
                originalContent.length > 50 ? 50 : originalContent.length))) {
          return message;
        }
      }
    }

    return null;
  }

  // ✅ ENHANCED: Navigate to original message with animation
  void _navigateToOriginalMessage(NoboxMessage originalMessage) {
    final messageIndex =
        _messages.indexWhere((m) => m.id == originalMessage.id);
    if (messageIndex == -1) {
      _showErrorSnackBar('Original message not found');
      return;
    }

    // Calculate scroll position
    final itemHeight = 80.0; // Approximate message height
    final targetPosition =
        (messageIndex * itemHeight) - 100; // Offset for better visibility

    // Start highlight animation
    setState(() {
      _highlightedMessageId = originalMessage.id;
    });

    _highlightAnimationController.forward().then((_) {
      _highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _highlightAnimationController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _highlightedMessageId = null;
              });
            }
          });
        }
      });
    });

    // Smooth scroll to message
    _scrollController.animateTo(
      targetPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );

    // Haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _scrollToMessage(NoboxMessage message) {
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex != -1) {
      final itemHeight = 100.0;
      final position = messageIndex * itemHeight;

      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      _showSuccessSnackBar('Jumped to pinned message');

      if (_showPinnedMessages) {
        setState(() {
          _showPinnedMessages = false;
        });
      }
    } else {
      _showErrorSnackBar('Message not found in current view');
    }
  }

  void _handleMessageAction(String action, NoboxMessage message) {
    switch (action) {
      case 'reply':
        _startReply(message);
        break;
      case 'forward':
        _startForward(message);
        break;
      case 'pin':
        _togglePinMessage(message);
        break;
      case 'copy':
        _copyMessageText(message);
        break;
      case 'delete':
        _deleteMessage(message);
        break;
      case 'info':
        _showEnhancedMessageInfo(message);
        break;
    }
  }

  void _copyMessageText(NoboxMessage message) {
    _exitActionMode();
    // ✅ Extract actual content if it's a reply or forward
    final replyData = _extractReplyData(message.content);
    final forwardData = _extractForwardData(message.content);

    String textToCopy = message.content;

    if (replyData != null) {
      textToCopy = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      textToCopy = forwardData['originalContent'] ?? message.content;
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    _showSuccessSnackBar('Message copied to clipboard');
  }

  void _deleteMessage(NoboxMessage message) {
    _exitActionMode();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Message',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to delete this message?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.removeWhere((m) => m.id == message.id);
                _pinnedMessageIds.remove(message.id);
              });
              _savePinnedMessages(); // ✅ Save after removing from pins
              _showSuccessSnackBar('Message deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEnhancedMessageInfo(NoboxMessage message) {
    _exitActionMode();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message Info',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Detailed message information',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.content.isEmpty
                          ? '(No text content)'
                          : message.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: textPrimary,
                        fontStyle: message.content.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  _buildEnhancedInfoRow(
                    Icons.fingerprint,
                    'Message ID',
                    message.id,
                    primaryBlue,
                  ),
                  _buildEnhancedInfoRow(
                    Icons.person,
                    'Sender',
                    _getContactDisplayName(message),
                    successGreen,
                  ),
                  _buildEnhancedInfoRow(
                    Icons.access_time,
                    'Time',
                    _formatDetailedTime(message.createdAt),
                    warningOrange,
                  ),
                  _buildEnhancedInfoRow(
                    Icons.category,
                    'Type',
                    _getMessageTypeString(message.bodyType),
                    const Color(0xFF9C27B0),
                  ),
                  _buildEnhancedInfoRow(
                    Icons.check_circle,
                    'Status',
                    message.isTemporary ? 'Sending...' : 'Delivered',
                    message.isTemporary ? warningOrange : successGreen,
                  ),
                  // ✅ NEW: Show link info
                  if (_containsLinks(message.content)) ...[
                    _buildEnhancedInfoRow(
                      Icons.link,
                      'Contains Links',
                      '${_extractLinks(message.content).length} links',
                      linkColor,
                    ),
                  ],
                  if (message.attachment != null) ...[
                    _buildEnhancedInfoRow(
                      Icons.attach_file,
                      'Attachment',
                      'Yes',
                      const Color(0xFF607D8B),
                    ),
                  ],
                  if (_isMessagePinned(message)) ...[
                    _buildEnhancedInfoRow(
                      Icons.push_pin,
                      'Pinned',
                      'Yes',
                      pinColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _copyMessageText(message);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedInfoRow(
      IconData icon, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getMessageTypeString(int bodyType) {
    switch (bodyType) {
      case 1:
        return 'Text';
      case 2:
        return 'Audio';
      case 3:
        return 'Image';
      case 4:
        return 'Video';
      case 5:
        return 'File';
      default:
        return 'Unknown';
    }
  }

  String _formatDetailedTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(localTime.year, localTime.month, localTime.day);

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    if (messageDate == today) {
      return 'Today ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dayNames[localTime.weekday - 1]}, ${localTime.day} ${monthNames[localTime.month - 1]} ${localTime.year} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    }
  }

  List<NoboxMessage> _mergeMessages(
    List<NoboxMessage> oldMessages,
    List<NoboxMessage> newMessages,
  ) {
    print('🔥 === ULTIMATE MERGE WITH PERFECT DEDUPLICATION ===');
    print('🔥 Old messages: ${oldMessages.length}');
    print('🔥 New messages: ${newMessages.length}');

    final Map<String, NoboxMessage> finalMessagesById =
        <String, NoboxMessage>{};
    final Map<String, NoboxMessage> contentBasedMap = <String, NoboxMessage>{};
    final Set<String> usedMessageIds = <String>{};

    String generateContentKey(NoboxMessage msg) {
      final timeWindow = (msg.createdAt.millisecondsSinceEpoch / 3000).floor();
      return '${msg.senderId}_${msg.content.trim().toLowerCase().hashCode}_$timeWindow';
    }

    final List<NoboxMessage> allMessages = [];
    allMessages.addAll(oldMessages);

    for (final newMsg in newMessages) {
      final existsInOld = oldMessages.any((oldMsg) => oldMsg.id == newMsg.id);
      if (!existsInOld) {
        allMessages.add(newMsg);
      }
    }

    for (final cachedMsg in _messageCache.values) {
      final exists = allMessages.any((m) => m.id == cachedMsg.id);
      if (!exists) {
        allMessages.add(cachedMsg);
      }
    }

    print('🔥 Total messages to process: ${allMessages.length}');

    final filteredMessages = allMessages
    .where((msg) =>
        !msg.content.contains('"msg":"Site.Inbox.HasAsign"') &&
        !msg.content.contains('"msg":"Site.Inbox.HasAsignBy"') && // TAMBAHKAN INI
        !msg.content.contains('HasAsign') && // TAMBAHKAN INI
        msg.content.trim().isNotEmpty)
    .toList();

    print('🔥 After system message filter: ${filteredMessages.length}');

    for (final msg in filteredMessages) {
      if (usedMessageIds.contains(msg.id)) {
        print('🔥 SKIP: Duplicate ID ${msg.id}');
        continue;
      }

      final contentKey = generateContentKey(msg);
      final existingByContent = contentBasedMap[contentKey];

      if (existingByContent != null) {
        print('🔥 CONTENT DUPLICATE DETECTED:');
        print(
            '🔥   Existing: ${existingByContent.id} (${existingByContent.isTemporary ? "temp" : "real"})');
        print(
            '🔥   Current:  ${msg.id} (${msg.isTemporary ? "temp" : "real"})');

        if (msg.isTemporary && !existingByContent.isTemporary) {
          print('🔥   SKIP: Keeping real message, skipping temporary');
          continue;
        } else if (!msg.isTemporary && existingByContent.isTemporary) {
          print('🔥   REPLACE: Replacing temporary with real message');
          usedMessageIds.remove(existingByContent.id);
          finalMessagesById.remove(existingByContent.id);
          contentBasedMap.remove(contentKey);
        } else if (msg.id == existingByContent.id) {
          print('🔥   SKIP: Same exact message');
          continue;
        } else {
          if (msg.createdAt.isAfter(existingByContent.createdAt)) {
            print('🔥   REPLACE: Keeping newer message');
            usedMessageIds.remove(existingByContent.id);
            finalMessagesById.remove(existingByContent.id);
            contentBasedMap.remove(contentKey);
          } else {
            print('🔥   SKIP: Keeping older message');
            continue;
          }
        }
      }

      finalMessagesById[msg.id] = msg;
      usedMessageIds.add(msg.id);
      contentBasedMap[contentKey] = msg;
      _processedMessageIds.add(msg.id);
      _messageCache[msg.id] = msg;

      print(
          '🔥 ✅ ADDED: ${msg.id} - "${msg.content.length > 50 ? msg.content.substring(0, 50) + "..." : msg.content}"');
    }

    final result = finalMessagesById.values.toList();

    result.sort((a, b) {
      final timeComparison = a.createdAt.compareTo(b.createdAt);
      if (timeComparison != 0) return timeComparison;
      return a.id.compareTo(b.id);
    });

    print('🔥 ✅ Final message count: ${result.length}');
    print('🔥 ✅ Message cache size: ${_messageCache.length}');

    return result;
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔥 === INITIALIZING CHAT WITH PERSISTENCE ===');

      if (!UserService.isLoggedIn) {
        await UserService.loadCurrentUser();
      }

      if (!UserService.validateCurrentUserData()) {
        print('⚠️ Warning: User data validation failed during chat init');
        UserService.debugLogCurrentUser();
      }

      await _loadAllMessages();

      _startAggressiveRealTimeUpdates();

      _startHeartbeat();

      setState(() {
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottomInstantly();
          _shouldAutoScroll = true;
          _userHasScrolled = false;
        }
      });
    } catch (e) {
      print('🔥 Error initializing chat: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to initialize chat: $e');
      }
    }
  }

  // ✅ NEW: System message renderer
// ✅ ENHANCED: System message renderer for all types
Widget _buildSystemMessage(NoboxMessage message) {

  // Dalam fungsi _buildSystemMessage, tambahkan error handling yang lebih robust
try {
  // Coba parse JSON dari content
  final String cleanContent = message.content.trim();
  
  // Handle case dimana mungkin ada multiple JSON objects atau format tidak standar
  if (cleanContent.startsWith('{') && cleanContent.endsWith('}')) {
    final Map<String, dynamic> data = jsonDecode(cleanContent);
    // ... kode parsing seperti di atas
  } else if (cleanContent.contains('{') && cleanContent.contains('}')) {
    // Coba ekstrak JSON dari string yang mungkin mengandung tambahan
    final start = cleanContent.indexOf('{');
    final end = cleanContent.lastIndexOf('}') + 1;
    if (start < end) {
      final jsonString = cleanContent.substring(start, end);
      final Map<String, dynamic> data = jsonDecode(jsonString);
      // ... kode parsing seperti di atas
    }
  }
} catch (e) {
  print('🔥 Error parsing system message JSON: $e');
  // Tetap tampilkan sebagai pesan sistem biasa
}

  try {
    // Coba parse JSON dari content
    final Map<String, dynamic> data = jsonDecode(message.content);
    
    if (data.containsKey('msg')) {
      final msgType = data['msg']?.toString() ?? '';
      final user = data['user']?.toString();
      final userHandle = data['userHandle']?.toString();
      final timestamp = message.createdAt;
      
      String displayText = '';
      Color bgColor = Colors.grey.shade100;
      Color textColor = textSecondary;
      
      switch (msgType) {
        case 'Site.Inbox.HasAsignBy':
        case 'Site.Inbox.HasAssignBySystem':
          displayText = 'User ${userHandle ?? 'Unknown'} has been assigned to this conversation by System';
          bgColor = const Color(0xFFE3F2FD); // Light blue
          textColor = const Color(0xFF1976D2); // Dark blue
          break;
          
        case 'Site.Inbox.MuteBotByAgent':
          displayText = 'Bot has been muted by Agent ${userHandle ?? 'Unknown'}';
          bgColor = const Color(0xFFFFEBEE); // Light red
          textColor = const Color(0xFFD32F2F); // Dark red
          break;
          
        case 'Site.Inbox.UnmuteBotByAgent':
          displayText = 'Bot has been unmuted by Agent ${userHandle ?? 'Unknown'}';
          bgColor = const Color(0xFFE8F5E9); // Light green
          textColor = const Color(0xFF388E3C); // Dark green
          break;
          
        default:
          // Untuk tipe system message lainnya
          displayText = msgType.replaceAll('Site.Inbox.', '').replaceAll('By', ' by ');
          break;
      }
      
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontStyle: FontStyle.italic,
                ),
                children: [
                  TextSpan(text: displayText),
                  TextSpan(
                    text: ' • ${_formatSystemTime(timestamp)}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  } catch (e) {
    // Jika bukan JSON, tampilkan sebagai pesan sistem biasa
    print('🔥 Not a JSON system message: $e');
  }
  
  // Fallback untuk pesan sistem biasa (non-JSON)
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

// ✅ ENHANCED: Format time for system messages with date
String _formatSystemTime(DateTime dateTime) {
  final localTime = dateTime.toLocal();
  final now = DateTime.now().toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
  
  if (messageDate == today) {
    return 'Today ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  } else {
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    return '$day/$month ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }
}

  Future<void> _loadAllMessages() async {
    try {
      print('🔥 Loading messages with perfect deduplication...');

      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt,
        take: 1000,
        skip: 0,
        limit: 0,
        orderBy: '',
        orderDirection: '',
      );

      if (response.success && response.data != null) {
        final serverMessages = response.data!;
        print('🔥 Loaded ${serverMessages.length} messages from server');

        setState(() {
          _messages = _mergeMessages(_messages, serverMessages);
          _lastKnownMessageCount = _messages.length;

          if (_messages.isNotEmpty) {
            final latestMessage = _messages
                .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
            _lastMessageTimestamp = latestMessage.createdAt;
          }
        });
      }
    } catch (e) {
      print('🔥 Error loading messages: $e');
      rethrow;
    }
  }

  void _startAggressiveRealTimeUpdates() {
    _realTimeTimer?.cancel();

    _realTimeTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !_isAppInForeground) return;

      try {
        print('🔥 ⚡ Real-time check...');

        final response = await ApiService.getMessages(
          linkId: int.tryParse(widget.chatLink.id),
          channelId: widget.channel.id,
          linkIdExt: widget.chatLink.idExt,
          take: 50,
          skip: 0,
          limit: 0,
          orderBy: '',
          orderDirection: '',
        );

        if (response.success && response.data != null && mounted) {
          final serverMessages = response.data!;

final genuinelyNewMessages = serverMessages.where((serverMsg) {
  final existsInCurrent = _messages.any((m) => m.id == serverMsg.id);
  final isProcessed = _processedMessageIds.contains(serverMsg.id);
  final isSystemMsg = _isSystemMessage(serverMsg); // GUNAKAN FUNGSI BARU
  final hasValidContent = serverMsg.content.trim().isNotEmpty;

  final isNew = !existsInCurrent &&
      !isProcessed &&
      !isSystemMsg &&
      hasValidContent;

  return isNew;
}).toList();

          if (genuinelyNewMessages.isNotEmpty) {
            print(
                '🔥 ⚡ PROCESSING ${genuinelyNewMessages.length} NEW MESSAGES');

            final mergedMessages =
                _mergeMessages(_messages, genuinelyNewMessages);

            setState(() {
              _messages = mergedMessages;
            });

            if (_shouldAutoScroll && !_userHasScrolled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _scrollToBottomSmooth();
              });
            }

            print(
                '🔥 ✅ Real-time update completed. Total messages: ${_messages.length}');
          }
        }
      } catch (e) {
        print('🔥 Real-time update error: $e');
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || !_isAppInForeground) {
        return;
      }

      print('🔥 💗 Heartbeat - keeping connection alive');
    });
  }

  Future<void> _refreshMessages() async {
    if (!mounted) return;

    try {
      print('🔥 🔄 Refreshing messages with perfect deduplication...');

      final response = await ApiService.getMessages(
        linkId: int.tryParse(widget.chatLink.id),
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt,
        take: 1000,
        skip: 0,
        limit: 0,
        orderBy: '',
        orderDirection: '',
      );

      if (response.success && response.data != null && mounted) {
        final serverMessages = response.data!;

        setState(() {
          _messages = _mergeMessages(_messages, serverMessages);
        });

        print(
            '🔥 ✅ Messages refreshed successfully. Total: ${_messages.length}');
      }
    } catch (e) {
      print('🔥 Error refreshing messages: $e');
    }
  }

  void _scrollToBottomInstantly() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _scrollToBottomSmooth() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: successGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _showWarningSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: warningOrange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  child: Text(message,
                      style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: errorRed,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(localTime.year, localTime.month, localTime.day);

    if (messageDate == today) {
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      final day = localTime.day.toString().padLeft(2, '0');
      final month = localTime.month.toString().padLeft(2, '0');
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$day/$month $hour:$minute';
    }
  }

  String _getImageUrl(String? attachment) {
    if (attachment == null || attachment.isEmpty) {
      print('🔥 _getImageUrl: Empty attachment');
      return '';
    }

    print('🔥 _getImageUrl: Processing attachment: $attachment');

    if (attachment.startsWith('http://') || attachment.startsWith('https://')) {
      print('🔥 _getImageUrl: Already full URL: $attachment');
      return attachment;
    }

    if (attachment.startsWith('{') && attachment.endsWith('}')) {
      try {
        final Map<String, dynamic> fileData = jsonDecode(attachment);
        final filename = fileData['Filename'] ?? fileData['filename'];
        if (filename != null && filename.isNotEmpty) {
          final url = filename.startsWith('http')
              ? filename
              : '${ApiService.baseUrl}/upload/$filename';
          print('🔥 _getImageUrl: From JSON data: $url');
          return url;
        }
      } catch (e) {
        print('🔥 _getImageUrl: Error parsing JSON: $e');
      }
    }

    if (attachment.startsWith('upload/')) {
      final url = '${ApiService.baseUrl}/$attachment';
      print('🔥 _getImageUrl: Upload path: $url');
      return url;
    }

    final url = '${ApiService.baseUrl}/upload/$attachment';
    print('🔥 _getImageUrl: Default path: $url');
    return url;
  }

  bool _isImageMessage(NoboxMessage message) {
    if (message.bodyType == 3) return true;

    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final imageExtensions = [
        '.jpg',
        '.jpeg',
        '.png',
        '.gif',
        '.webp',
        '.bmp'
      ];

      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = fileData['Filename'] ?? fileData['filename'] ?? '';
          return imageExtensions
              .any((ext) => filename.toLowerCase().endsWith(ext));
        } catch (e) {
          return false;
        }
      }

      return imageExtensions.any((ext) => attachment.endsWith(ext));
    }

    final content = message.content.toLowerCase();
    return content.contains('📷') ||
        content.contains('image') ||
        content.contains('foto');
  }

  bool _isVideoMessage(NoboxMessage message) {
    if (message.bodyType == 4) return true;

    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final videoExtensions = [
        '.mp4',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.webm',
        '.mkv'
      ];

      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = fileData['Filename'] ?? fileData['filename'] ?? '';
          return videoExtensions
              .any((ext) => filename.toLowerCase().endsWith(ext));
        } catch (e) {
          return false;
        }
      }

      return videoExtensions.any((ext) => attachment.endsWith(ext));
    }

    final content = message.content.toLowerCase();
    return content.contains('🎥') || content.contains('video');
  }

  bool _isAudioMessage(NoboxMessage message) {
    if (message.bodyType == 2) return true;

    if (message.attachment != null && message.attachment!.isNotEmpty) {
      final attachment = message.attachment!.toLowerCase();
      final audioExtensions = ['.mp3', '.wav', '.ogg', '.aac', '.m4a', '.flac'];

      if (attachment.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(attachment);
          final filename = fileData['Filename'] ?? fileData['filename'] ?? '';
          final isVoiceNote = fileData['IsVoiceNote'] == true;

          if (isVoiceNote || filename.toLowerCase().contains('voice')) {
            return true;
          }

          return audioExtensions
              .any((ext) => filename.toLowerCase().endsWith(ext));
        } catch (e) {
          return false;
        }
      }

      return audioExtensions.any((ext) => attachment.endsWith(ext));
    }

    final content = message.content.toLowerCase();
    return content.contains('🎵') ||
        content.contains('🎤') ||
        content.contains('audio') ||
        content.contains('voice');
  }

  bool _isVoiceNote(NoboxMessage message) {
    if (message.bodyType != 2) return false;

    final content = message.content.toLowerCase();
    if (content.contains('🎤') || content.contains('voice note')) {
      return true;
    }

    if (message.attachment != null && message.attachment!.isNotEmpty) {
      if (message.attachment!.startsWith('{')) {
        try {
          final Map<String, dynamic> fileData = jsonDecode(message.attachment!);
          final isVoiceNote = fileData['IsVoiceNote'] == true;
          final filename = fileData['Filename'] ?? fileData['filename'] ?? '';

          return isVoiceNote || filename.toLowerCase().contains('voice');
        } catch (e) {
          return false;
        }
      }

      final attachment = message.attachment!.toLowerCase();
      return attachment.contains('voice');
    }

    return false;
  }

  bool _isFileMessage(NoboxMessage message) {
    if (message.bodyType == 5) return true;

    if (message.attachment != null && message.attachment!.isNotEmpty) {
      return !_isImageMessage(message) &&
          !_isVideoMessage(message) &&
          !_isAudioMessage(message);
    }

    final content = message.content.toLowerCase();
    return content.contains('📎') ||
        content.contains('file') ||
        content.contains('document');
  }

  // ✅ NEW: Build forward indicator
  Widget _buildForwardIndicator(
      Map<String, dynamic> forwardData, bool isAgentMessage) {
    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAgentMessage
            ? Colors.white.withOpacity(0.15)
            : forwardBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color:
                isAgentMessage ? Colors.white.withOpacity(0.8) : forwardColor,
            width: 3,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.forward,
            size: 14,
            color:
                isAgentMessage ? Colors.white.withOpacity(0.9) : forwardColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Forwarded from ${forwardData['originalSender'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAgentMessage
                    ? Colors.white.withOpacity(0.95)
                    : forwardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ ENHANCED: Check if message is a system message
bool _isSystemMessage(NoboxMessage message) {
  final content = message.content;
  
  // Check for various system message patterns
  return content.contains('"msg":"Site.Inbox.') ||
         content.contains('HasAsign') ||
         content.contains('HasAssign') ||
         content.contains('MuteBot') ||
         content.contains('UnmuteBot') ||
         content.contains('assigned') ||
         content.contains('Assigned') ||
         content.contains('muted') ||
         content.contains('unmuted') ||
         (message.senderId.toLowerCase().contains('system') && 
          !message.senderId.toLowerCase().contains('whatsapp'));
}

  Widget _buildMessageBubble(NoboxMessage message) {
    final bool isAgentMessage = _isAgentMessage(message);
    final isOptimistic = message.isTemporary;
    final isFailed = message.isFailed;
    final isPinned = _isMessagePinned(message);
    final isSelected = _selectedMessage?.id == message.id;
    final isHighlighted = _highlightedMessageId == message.id;
    final hasLinks = _containsLinks(message.content);

    if (message.content.contains('"msg":"Site.Inbox.HasAsign"')) {
      return const SizedBox.shrink();
    }
    
      if (_isSystemMessage(message)) {
    return _buildSystemMessage(message);
  }


    final replyData = _extractReplyData(message.content);
    final forwardData = _extractForwardData(message.content);
    final isReplyMessage = replyData != null;
    final isForwardedMessage = forwardData != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        top: 2.5,
        bottom: 2.5,
        left: isAgentMessage ? 40 : 16,
        right: isAgentMessage ? 16 : 40,
      ),
      child: Row(
        mainAxisAlignment:
            isAgentMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Stack(
                children: [
                  // Tonjolan (tail) untuk bubble chat
                  if (isAgentMessage)
                    Positioned(
                      right: -8,
                      bottom: 0,
                      child: CustomPaint(
                        size: Size(8, 12),
                        painter: RightMessageTailPainter(
                          isSelected
                              ? myMessageBubble.withOpacity(0.8)
                              : (isFailed ? errorRed : myMessageBubble),
                          tailLength: 8,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: -8,
                      bottom: 0,
                      child: CustomPaint(
                        size: Size(8, 12),
                        painter: LeftMessageTailPainter(
                          isSelected
                              ? otherMessageBubble.withOpacity(0.8)
                              : otherMessageBubble,
                          tailLength: 12,
                        ),
                      ),
                    ),

                  GestureDetector(
                    onLongPressStart: (details) {
                      _enterActionMode(message);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isAgentMessage
                                ? myMessageBubble.withOpacity(0.8)
                                : otherMessageBubble.withOpacity(0.8))
                            : (isAgentMessage
                                ? (isFailed ? errorRed : myMessageBubble)
                                : otherMessageBubble),
                        borderRadius: isAgentMessage
                            ? const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              )
                            : const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pin indicator
                          if (isPinned) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: pinColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: pinColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Pinned',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: pinColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // TAMBAHKAN INI: Reply indicator
                          if (isReplyMessage) ...[
                            _buildEnhancedReplyIndicator(
                                replyData, isAgentMessage, message),
                            const SizedBox(height: 8),
                          ],

                          if (_isImageMessage(message)) ...[
                            _buildImageContent(message, isAgentMessage,
                                replyData, forwardData),
                          ] else if (_isVideoMessage(message)) ...[
                            _buildVideoContent(message, isAgentMessage,
                                replyData, forwardData),
                          ] else if (_isVoiceNote(message)) ...[
                            _buildVoiceNoteContent(message, isAgentMessage,
                                replyData, forwardData),
                          ] else if (_isAudioMessage(message)) ...[
                            _buildAudioContent(message, isAgentMessage,
                                replyData, forwardData),
                          ] else if (_isFileMessage(message)) ...[
                            _buildFileContent(message, isAgentMessage,
                                replyData, forwardData),
                          ] else ...[
                            _buildTextContent(message, isAgentMessage,
                                isOptimistic, isFailed, replyData, forwardData),
                          ],
                        ],
                      ),
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

// ✅ ENHANCED: Reply indicator with proper message structure
  Widget _buildEnhancedReplyIndicator(Map<String, dynamic> replyData,
      bool isAgentMessage, NoboxMessage currentMessage) {
    final originalMessage = _findOriginalMessage(replyData);

    return GestureDetector(
      onTap: () {
        if (originalMessage != null) {
          _navigateToOriginalMessage(originalMessage);
        } else {
          _showErrorSnackBar('Original message not found');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAgentMessage
              ? Colors.white.withOpacity(0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color:
                  isAgentMessage ? Colors.white.withOpacity(0.8) : primaryBlue,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.reply,
                  size: 14,
                  color: isAgentMessage
                      ? Colors.white.withOpacity(0.9)
                      : primaryBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    replyData['repliedToSender'] ?? 'Unknown Contact',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isAgentMessage
                          ? Colors.white.withOpacity(0.95)
                          : primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              replyData['repliedToContent'] ?? '',
              style: TextStyle(
                fontSize: 12,
                color: isAgentMessage
                    ? Colors.white.withOpacity(0.8)
                    : textSecondary,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(
      NoboxMessage message,
      bool isAgentMessage,
      bool isOptimistic,
      bool isFailed,
      Map<String, dynamic>? replyData,
      Map<String, dynamic>? forwardData) {
    // Get the actual message content (without reply/forward prefix)
    String actualContent = message.content;

    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: 40,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                actualContent,
                style: TextStyle(
                  fontSize: 14,
                  color: isAgentMessage ? Colors.white : textPrimary,
                ),
                softWrap: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    fontStyle:
                        isOptimistic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (isAgentMessage) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isFailed
                        ? Icons.error_outline
                        : (isOptimistic ? Icons.schedule : Icons.done_all),
                    size: 14,
                    color: isFailed
                        ? Colors.white70
                        : (isOptimistic ? Colors.white54 : Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(NoboxMessage message, bool isAgentMessage,
      [Map<String, dynamic>? replyData, Map<String, dynamic>? forwardData]) {
    final imageUrl = _getImageUrl(message.attachment);
    final filename = _getFilenameFromAttachment(message.attachment);

    String actualContent = message.content;
    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    if (imageUrl.isEmpty) {
      return _buildErrorContent('Image not available', isAgentMessage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image container
        GestureDetector(
          onTap: () => _showFullScreenImage(imageUrl, filename),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 240,
              maxHeight: 240,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: 240,
                    height: 240,
                    placeholder: (context, url) => Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        color: isAgentMessage
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isAgentMessage ? Colors.white70 : primaryBlue,
                          ),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      return Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          color: isAgentMessage
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 40,
                              color: isAgentMessage
                                  ? Colors.white70
                                  : textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(
                                fontSize: 12,
                                color: isAgentMessage
                                    ? Colors.white70
                                    : textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Action buttons (download and share)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _downloadImageToGallery(imageUrl, filename),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _shareImageFromUrl(imageUrl, filename),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Caption text (if any)
        if (actualContent.trim().isNotEmpty &&
            !actualContent.startsWith('📷') &&
            actualContent.toLowerCase() != 'image') ...[
          const SizedBox(height: 8),
          _buildRichText(actualContent, isAgentMessage),
        ],

        // Footer with filename and timestamp
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.end, // Sejajarkan dengan bagian bawah
          children: [
            Icon(
              Icons.image,
              size: 14,
              color: isAgentMessage ? Colors.white70 : textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(
                    bottom: 2), // Sedikit padding bawah untuk teks
                child: Text(
                  filename,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.only(
                  top: 2), // Padding atas untuk menurunkan timestamp
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isAgentMessage ? Colors.white70 : textSecondary,
                    ),
                  ),
                  if (isAgentMessage) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.isFailed
                          ? Icons.error_outline
                          : (message.isTemporary
                              ? Icons.schedule
                              : Icons.done_all),
                      size: 12,
                      color: message.isFailed
                          ? Colors.white70
                          : (message.isTemporary
                              ? Colors.white54
                              : Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Update other content builders with reply and forward support
  Widget _buildVideoContent(NoboxMessage message, bool isAgentMessage,
      [Map<String, dynamic>? replyData, Map<String, dynamic>? forwardData]) {
    final videoUrl = _getImageUrl(message.attachment);
    final filename = _getFilenameFromAttachment(message.attachment);

    String actualContent = message.content;
    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    return GestureDetector(
      onTap: () => _showVideoPlayer(videoUrl),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isAgentMessage
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 30,
                    color: isAgentMessage
                        ? Colors.white70
                        : const Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filename,
                        style: TextStyle(
                          fontSize: 14,
                          color: isAgentMessage ? Colors.white : textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (actualContent.trim().isNotEmpty &&
                          !actualContent.startsWith('🎥')) ...[
                        const SizedBox(height: 4),
                        _buildRichText(actualContent, isAgentMessage),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatTime(message.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: isAgentMessage
                                  ? Colors.white70
                                  : textSecondary,
                            ),
                          ),
                          if (isAgentMessage) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isFailed
                                  ? Icons.error_outline
                                  : (message.isTemporary
                                      ? Icons.schedule
                                      : Icons.done_all),
                              size: 14,
                              color: message.isFailed
                                  ? Colors.white70
                                  : (message.isTemporary
                                      ? Colors.white54
                                      : Colors.white),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _downloadFileToDevice(videoUrl, filename),
                      child: Icon(
                        Icons.download,
                        color: isAgentMessage ? Colors.white70 : textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _shareFileFromUrl(videoUrl, filename),
                      child: Icon(
                        Icons.share,
                        color: isAgentMessage ? Colors.white70 : textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceNoteContent(NoboxMessage message, bool isAgentMessage,
      [Map<String, dynamic>? replyData, Map<String, dynamic>? forwardData]) {
    final audioUrl = _getImageUrl(message.attachment);
    final duration = _extractDurationFromContent(message.content);

    String actualContent = message.content;
    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    if (audioUrl.isEmpty) {
      return _buildErrorContent('Voice note not available', isAgentMessage);
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoiceMessagePlayer(
            audioUrl: audioUrl,
            filename: 'Voice Note',
            duration: duration,
            isMyMessage: isAgentMessage,
          ),
          if (actualContent.trim().isNotEmpty &&
              !actualContent.startsWith('🎤') &&
              !actualContent.toLowerCase().contains('voice note')) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildRichText(actualContent, isAgentMessage),
            ),
          ],
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                  ),
                ),
                if (isAgentMessage) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isFailed
                        ? Icons.error_outline
                        : (message.isTemporary
                            ? Icons.schedule
                            : Icons.done_all),
                    size: 14,
                    color: message.isFailed
                        ? Colors.white70
                        : (message.isTemporary ? Colors.white54 : Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(NoboxMessage message, bool isAgentMessage,
      [Map<String, dynamic>? replyData, Map<String, dynamic>? forwardData]) {
    final audioUrl = _getImageUrl(message.attachment);
    final filename = _getFilenameFromAttachment(message.attachment);

    String actualContent = message.content;
    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    return GestureDetector(
      onTap: () => _playAudioMessage(audioUrl),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isAgentMessage
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.audiotrack,
                size: 24,
                color:
                    isAgentMessage ? Colors.white70 : const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAgentMessage ? Colors.white : textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (actualContent.trim().isNotEmpty &&
                      !actualContent.startsWith('🎵')) ...[
                    const SizedBox(height: 4),
                    _buildRichText(actualContent, isAgentMessage),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isAgentMessage ? Colors.white70 : textSecondary,
                        ),
                      ),
                      if (isAgentMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isFailed
                              ? Icons.error_outline
                              : (message.isTemporary
                                  ? Icons.schedule
                                  : Icons.done_all),
                          size: 14,
                          color: message.isFailed
                              ? Colors.white70
                              : (message.isTemporary
                                  ? Colors.white54
                                  : Colors.white),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () => _downloadFileToDevice(audioUrl, filename),
                  child: Icon(
                    Icons.download,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _shareFileFromUrl(audioUrl, filename),
                  child: Icon(
                    Icons.share,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent(NoboxMessage message, bool isAgentMessage,
      [Map<String, dynamic>? replyData, Map<String, dynamic>? forwardData]) {
    final fileUrl = _getImageUrl(message.attachment);
    final filename = _getFilenameFromAttachment(message.attachment);

    String actualContent = message.content;
    if (replyData != null) {
      actualContent = replyData['actualContent'] ?? message.content;
    } else if (forwardData != null) {
      actualContent = forwardData['originalContent'] ?? message.content;
    }

    final fileIcon = MediaService.getFileIcon(filename);
    final fileColor = MediaService.getFileColor(filename);

    return GestureDetector(
      onTap: () => _openFile(fileUrl),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: fileColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon,
                size: 24,
                color: fileColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 14,
                      color: isAgentMessage ? Colors.white : textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (actualContent.trim().isNotEmpty &&
                      !actualContent.startsWith('📄')) ...[
                    const SizedBox(height: 4),
                    _buildRichText(actualContent, isAgentMessage),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isAgentMessage ? Colors.white70 : textSecondary,
                        ),
                      ),
                      if (isAgentMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isFailed
                              ? Icons.error_outline
                              : (message.isTemporary
                                  ? Icons.schedule
                                  : Icons.done_all),
                          size: 14,
                          color: message.isFailed
                              ? Colors.white70
                              : (message.isTemporary
                                  ? Colors.white54
                                  : Colors.white),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () => _downloadFileToDevice(fileUrl, filename),
                  child: Icon(
                    Icons.download,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _shareFileFromUrl(fileUrl, filename),
                  child: Icon(
                    Icons.share,
                    color: isAgentMessage ? Colors.white70 : textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImageToGallery(String imageUrl, String filename) async {
    try {
      print('🔥 Downloading image to gallery: $imageUrl');

      final success =
          await MediaService.downloadImageToGallery(imageUrl, filename);

      if (success) {
        _showSuccessSnackBar('Image saved to gallery');
      } else {
        _showErrorSnackBar('Failed to save image to gallery');
      }
    } catch (e) {
      print('🔥 Error downloading image: $e');
      _showErrorSnackBar(
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _shareImageFromUrl(String imageUrl, String filename) async {
    try {
      print('🔥 Sharing image: $imageUrl');

      await MediaService.shareImageFromUrl(imageUrl, filename);
      _showSuccessSnackBar('Image shared successfully');
    } catch (e) {
      print('🔥 Error sharing image: $e');
      _showErrorSnackBar(
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _downloadFileToDevice(String fileUrl, String filename) async {
    try {
      print('🔥 Downloading file: $fileUrl');

      final filePath =
          await MediaService.downloadFileToDevice(fileUrl, filename);
      _showSuccessSnackBar('File downloaded to: $filePath');
    } catch (e) {
      print('🔥 Error downloading file: $e');
      _showErrorSnackBar(
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<void> _shareFileFromUrl(String fileUrl, String filename) async {
    try {
      print('🔥 Sharing file: $fileUrl');

      await MediaService.shareFileFromUrl(fileUrl, filename);
      _showSuccessSnackBar('File shared successfully');
    } catch (e) {
      print('🔥 Error sharing file: $e');
      _showErrorSnackBar(
          'Error: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  String _getFilenameFromAttachment(String? attachment) {
    if (attachment == null || attachment.isEmpty) return 'File';

    if (attachment.startsWith('{')) {
      try {
        final Map<String, dynamic> fileData = jsonDecode(attachment);
        final originalName =
            fileData['OriginalName'] ?? fileData['originalName'];
        final filename = fileData['Filename'] ?? fileData['filename'];
        return originalName ?? filename ?? 'File';
      } catch (e) {
        return 'File';
      }
    }

    if (attachment.contains('/')) {
      return attachment.split('/').last;
    }

    return attachment;
  }

  Widget _buildErrorContent(String errorText, bool isAgentMessage) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: isAgentMessage ? Colors.white70 : textSecondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorText,
              style: TextStyle(
                fontSize: 12,
                color: isAgentMessage ? Colors.white70 : textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Duration _extractDurationFromContent(String content) {
    final regex = RegExp(r'\((\d{2}):(\d{2})\)');
    final match = regex.firstMatch(content);

    if (match != null) {
      final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
      return Duration(minutes: minutes, seconds: seconds);
    }

    return const Duration(seconds: 30);
  }

  void _showFullScreenImage(String imageUrl, String filename) {
    if (imageUrl.isEmpty) {
      _showErrorSnackBar('Image URL is not available');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedImageViewer(
          imageUrl: imageUrl,
          filename: filename,
        ),
      ),
    );
  }

  void _showVideoPlayer(String videoUrl) {
    _showWarningSnackBar('Video player feature coming soon');
  }

  Future<void> _playAudioMessage(String audioUrl) async {
    try {
      print('🔥 Playing audio: $audioUrl');
      await VoiceService.playVoiceMessage(audioUrl);
    } catch (e) {
      print('🔥 Error playing audio: $e');
      _showErrorSnackBar('Failed to play audio: $e');
    }
  }

  void _openFile(String fileUrl) {
    _showWarningSnackBar('File viewer feature coming soon');
  }

  bool _isAgentMessage(NoboxMessage message) {
    final senderName = (message.senderName ?? '').toLowerCase();
    final displayName = (message.displayName ?? '').toLowerCase();

    if (senderName.contains('agent') || displayName.contains('agent')) {
      return true;
    }

    if (message.isFromMe) {
      return true;
    }

    if (message.content.contains('Sent from NoBox.Ai trial account')) {
      return true;
    }

    final senderId = message.senderId.toLowerCase();
    if (senderId.contains('system') ||
        senderId.contains('agent') ||
        senderId.contains('nobox')) {
      return true;
    }

    return false;
  }

  Widget _buildPinnedMessagesHeader() {
    if (_pinnedMessages.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [pinColor.withOpacity(0.1), pinColor.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: pinColor.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: pinColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.push_pin, color: pinColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_pinnedMessages.length} Pinned Message${_pinnedMessages.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: pinColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Tap to ${_showPinnedMessages ? 'hide' : 'view'} pinned messages',
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _togglePinnedMessagesView,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: pinColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _showPinnedMessages
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: pinColor,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED: Reply bar with proper contact name display
  Widget _buildReplyBar() {
    if (!_isReplying || _replyingToMessage == null) {
      return const SizedBox.shrink();
    }

    final contactName = _getContactDisplayName(_replyingToMessage!);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, -1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _replyAnimationController,
        curve: Curves.easeInOut,
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              replyBackgroundColor,
              replyBackgroundColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border(
            left: BorderSide(color: replyBorderColor, width: 4),
            bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: replyBorderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.reply, color: replyBorderColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $contactName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: replyBorderColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      _replyingToMessage!.content.length > 80
                          ? '${_replyingToMessage!.content.substring(0, 80)}...'
                          : _replyingToMessage!.content,
                      style: const TextStyle(
                        fontSize: 12,
                        color: textPrimary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _cancelReply,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: surfaceWhite,
      child: Column(
        children: [
          _buildReplyBar(),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Column(
              children: [
                if (_isUploading) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryBlue),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _uploadProgress ?? 'Uploading...',
                            style: const TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildEnhancedMessageTextField()),
                    const SizedBox(width: 8),
                    _buildSendOrVoiceButton(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMessageTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleAttachmentMenu,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.attach_file,
                color: Colors.grey[600],
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isReplying ? 'Reply...' : 'Send a message',
                hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          GestureDetector(
            onTap: () => _handleImageUpload(ImageSource.camera),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.camera_alt,
                color: Colors.grey[600],
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAttachmentMenu() {
    if (_showAttachmentMenu) {
      _hideAttachmentMenu();
    } else {
      _showAttachmentMenuOverlay();
    }
  }

  void _showAttachmentMenuOverlay() {
    setState(() {
      _showAttachmentMenu = true;
    });

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    _attachmentOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideAttachmentMenu,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.3),
            ),
          ),
          Positioned(
            bottom: 120 + bottomPadding + (_isReplying ? 60 : 0),
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(
                          top: 20, left: 20, right: 20, bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAttachmentOption(
                            icon: Icons.folder,
                            label: 'Dokumen',
                            color: const Color(0xFF7B68EE),
                            onTap: () => _handleFileUpload(FileType.any),
                          ),
                          _buildAttachmentOption(
                            icon: Icons.image,
                            label: 'Galeri',
                            color: const Color(0xFF4CAF50),
                            onTap: () =>
                                _handleImageUpload(ImageSource.gallery),
                          ),
                          _buildAttachmentOption(
                            icon: Icons.headphones,
                            label: 'Audio',
                            color: const Color(0xFFFF9800),
                            onTap: () => _handleFileUpload(FileType.audio),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(
                          bottom: 20, left: 20, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAttachmentOption(
                            icon: Icons.camera_alt,
                            label: 'Camera',
                            color: const Color(0xFFE91E63),
                            onTap: () => _handleImageUpload(ImageSource.camera),
                          ),
                          _buildAttachmentOption(
                            icon: Icons.video_file,
                            label: 'Video',
                            color: const Color(0xFF9C27B0),
                            onTap: () => _handleFileUpload(FileType.video),
                          ),
                          _buildAttachmentOption(
                            icon: Icons.mic,
                            label: 'Voice',
                            color: const Color(0xFF007AFF),
                            onTap: () {
                              _hideAttachmentMenu();
                              _showVoiceRecordingDialog();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_attachmentOverlay!);
  }

  void _showVoiceRecordingDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceRecorderWidget(
        onVoiceRecorded: (voicePath, duration) async {
          Navigator.of(context).pop();
          await _sendVoiceMessage(voicePath, duration);
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _sendVoiceMessage(String voicePath, Duration duration) async {
    try {
      print('🔥 Sending voice message: $voicePath');

      setState(() {
        _isUploading = true;
        _uploadProgress = 'Uploading voice note...';
      });

      final file = File(voicePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final voiceFilename = 'voice_note_$timestamp.wav';

      final uploadResponse = await ApiService.uploadFileBase64(
        file: file,
        customFilename: voiceFilename,
      );

      if (uploadResponse.success && uploadResponse.data != null) {
        final uploadedFile = uploadResponse.data!;

        setState(() {
          _uploadProgress = 'Sending voice note...';
        });

        final voiceContent =
            '🎤 Voice note (${VoiceService.formatDuration(duration)})';

        final messageResponse = await ApiService.sendMessageWithAttachment(
          content: voiceContent,
          channelId: widget.channel.id,
          linkId: int.tryParse(widget.chatLink.id) ?? 0,
          linkIdExt: widget.chatLink.idExt,
          attachmentFilename: jsonEncode({
            'Filename': uploadedFile.filename,
            'OriginalName': uploadedFile.originalName,
            'IsVoiceNote': true,
            'Duration': duration.inSeconds,
            'Format': 'WAV',
          }),
          bodyType: 2,
        );

        if (messageResponse.success) {
          _showSuccessSnackBar('Voice note sent successfully');
          await _refreshMessages();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottomSmooth();
          });
        } else {
          _showErrorSnackBar(messageResponse.userMessage);
        }
      } else {
        _showErrorSnackBar(uploadResponse.userMessage);
      }
    } catch (e) {
      print('🔥 Error sending voice message: $e');
      _showErrorSnackBar('Failed to send voice message: $e');
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = null;
      });
    }
  }

  // ✅ FIXED: Navigate to media compose screen instead of direct upload
  Future<void> _handleFileUpload(FileType fileType) async {
    _hideAttachmentMenu();

    if (_isUploading) {
      _showWarningSnackBar('Another file is being uploaded');
      return;
    }

    try {
      List<String>? allowedExtensions;
      String mediaType = 'file';

      switch (fileType) {
        case FileType.audio:
          allowedExtensions = ['mp3', 'wav', 'ogg', 'aac', 'm4a'];
          mediaType = 'audio';
          break;
        case FileType.video:
          allowedExtensions = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'];
          mediaType = 'video';
          break;
        case FileType.image:
          allowedExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];
          mediaType = 'image';
          break;
        default:
          mediaType = 'file';
          break;
      }

      // Pick file using file picker
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      final file = File(result.files.single.path!);
      final filename = result.files.single.name;

      // Navigate to compose screen
      final composeResult =
          await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => MediaComposeScreen(
            mediaFile: file,
            mediaType: mediaType,
            filename: filename,
            chatLink: widget.chatLink,
            channel: widget.channel,
            replyingToMessage: _isReplying ? _replyingToMessage : null,
          ),
        ),
      );

      // Handle result from compose screen
      if (composeResult != null && composeResult['success'] == true) {
        if (_isReplying) {
          _cancelReply();
        }

        if (composeResult['refresh_needed'] == true) {
          await _refreshMessages();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottomSmooth();
          });
        }
      }
    } catch (e) {
      print('🔥 Error handling file upload: $e');
      _showErrorSnackBar('Failed to select file: $e');
    }
  }

  // ✅ FIXED: Navigate to media compose screen instead of direct upload
  Future<void> _handleImageUpload(ImageSource source) async {
    _hideAttachmentMenu();

    if (_isUploading) {
      _showWarningSnackBar('Another file is being uploaded');
      return;
    }

    try {
      // Pick image using image picker
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        return; // User canceled
      }

      final file = File(image.path);
      final filename = image.name;

      // Navigate to compose screen
      final composeResult =
          await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (context) => MediaComposeScreen(
            mediaFile: file,
            mediaType: 'image',
            filename: filename,
            chatLink: widget.chatLink,
            channel: widget.channel,
            replyingToMessage: _isReplying ? _replyingToMessage : null,
          ),
        ),
      );

      // Handle result from compose screen
      if (composeResult != null && composeResult['success'] == true) {
        if (_isReplying) {
          _cancelReply();
        }

        if (composeResult['refresh_needed'] == true) {
          await _refreshMessages();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottomSmooth();
          });
        }
      }
    } catch (e) {
      print('🔥 Error handling image upload: $e');
      _showErrorSnackBar('Failed to select image: $e');
    }
  }

  String _getFileMessage(UploadedFile file, int bodyType) {
    switch (bodyType) {
      case 2:
        return '🎵 ${file.originalName}';
      case 3:
        return '📷 ${file.originalName}';
      case 4:
        return '🎥 ${file.originalName}';
      case 5:
        return '📄 ${file.originalName}';
      default:
        return '📎 ${file.originalName}';
    }
  }

  void _hideAttachmentMenu() {
    if (_attachmentOverlay != null) {
      _attachmentOverlay!.remove();
      _attachmentOverlay = null;
    }
    setState(() {
      _showAttachmentMenu = false;
    });
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceRecording() {
    _showVoiceRecordingDialog();
  }

  Widget _buildSendOrVoiceButton() {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    final bool canSend = hasText && !_isSending && !_isUploading;

    return GestureDetector(
      onTap: canSend ? _sendMessage : (hasText ? null : _showVoiceRecording),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: canSend ? primaryBlue : Colors.blue,
          shape: BoxShape.circle,
        ),
        child: (_isSending || _isUploading)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                hasText ? Icons.send : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }

  void _navigateToContactDetail({NoboxMessage? message}) {
    String contactName;
    String contactId;
    String? phoneNumber;

    if (message != null && !message.isFromMe) {
      contactName = _getContactDisplayName(message);
      contactId = message.senderId ?? '';
    } else {
      final chatName = widget.chatLink.name ?? '';
      final chatId = widget.chatLink.id ?? '';

      contactName = chatName.isNotEmpty ? chatName : 'Chat $chatId';
      contactId = chatId;
    }

    final idExt = widget.chatLink.idExt ?? '';
    if (idExt.startsWith('+') || idExt.contains('62')) {
      phoneNumber = idExt;
    }

    String? lastSeen;
    if (_messages.isNotEmpty) {
      final incomingMessages = _messages.where((m) => !m.isFromMe).toList();
      if (incomingMessages.isNotEmpty) {
        final lastMessage = incomingMessages.last;
        lastSeen = _formatTime(lastMessage.createdAt);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(
          contactName: contactName,
          contactId: contactId,
          phoneNumber: phoneNumber,
          lastSeen: lastSeen,
          accountType: 'Bot',
          needReply: false,
          muteAiAgent: false,
          messageTags: [],
          notes: null,
          campaign: null,
          deal: null,
          formTemplate: null,
          formResult: null,
          humanAgents: ['Zaalan Coding'],
        ),
      ),
    );
  }

  Widget _buildBackToBottomButton() {
    if (!_userHasScrolled) return const SizedBox.shrink();

    return Positioned(
      bottom: 80 + (_isReplying ? 60 : 0),
      right: 20,
      child: FloatingActionButton.small(
        backgroundColor: primaryBlue,
        onPressed: () {
          _scrollToBottomSmooth();
          setState(() {
            _userHasScrolled = false;
            _shouldAutoScroll = true;
          });
        },
        child: const Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildEnhancedAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildPinnedMessagesHeader(),
              if (_showPinnedMessages) ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: pinColor.withOpacity(0.05),
                    border: Border(
                      bottom: BorderSide(
                          color: pinColor.withOpacity(0.3), width: 1),
                    ),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _pinnedMessages.length,
                    itemBuilder: (context, index) {
                      final message = _pinnedMessages[index];
                      return GestureDetector(
                        onTap: () => _scrollToMessage(message),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: pinColor.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: pinColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(Icons.push_pin,
                                        color: pinColor, size: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getContactDisplayName(message),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: pinColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Tap to jump',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _togglePinMessage(message),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.close,
                                          color: Colors.grey[600], size: 14),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message.content.length > 100
                                    ? '${message.content.substring(0, 100)}...'
                                    : message.content,
                                style: const TextStyle(
                                    fontSize: 13, color: textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 12, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(message.createdAt),
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[500]),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.touch_app,
                                      size: 12,
                                      color: primaryBlue.withOpacity(0.7)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              Expanded(
                child: _isLoading && _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryBlue),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading messages...',
                              style: TextStyle(
                                color: textSecondary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
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
                                  'Start the conversation!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            key: _messagesListKey,
                            controller: _scrollController,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              if (index >= _messages.length) {
                                return const SizedBox.shrink();
                              }

                              final message = _messages[index];
                              return _buildMessageBubble(message);
                            },
                          ),
              ),
              _buildMessageInput(),
            ],
          ),
          _buildBackToBottomButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildEnhancedAppBar() {
    if (_isActionMode && _selectedMessage != null) {
      return AppBar(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitActionMode,
        ),
        title: Text(
          '1 selected',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.reply, size: 22),
            onPressed: () => _handleMessageAction('reply', _selectedMessage!),
            tooltip: 'Reply',
          ),

          // ✅ NEW: Forward button in action mode
          IconButton(
            icon: const Icon(Icons.forward, size: 22),
            onPressed: () => _handleMessageAction('forward', _selectedMessage!),
            tooltip: 'Forward',
          ),

          IconButton(
            icon: const Icon(Icons.copy, size: 22),
            onPressed: () => _handleMessageAction('copy', _selectedMessage!),
            tooltip: 'Copy',
          ),

          IconButton(
            icon: Icon(
              _isMessagePinned(_selectedMessage!)
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              size: 22,
            ),
            onPressed: () => _handleMessageAction('pin', _selectedMessage!),
            tooltip: _isMessagePinned(_selectedMessage!) ? 'Unpin' : 'Pin',
          ),

          IconButton(
            icon: const Icon(Icons.info_outline, size: 22),
            onPressed: () => _handleMessageAction('info', _selectedMessage!),
            tooltip: 'Info',
          ),

          if (_isAgentMessage(_selectedMessage!)) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 22),
              onPressed: () =>
                  _handleMessageAction('delete', _selectedMessage!),
              tooltip: 'Delete',
            ),
          ],
        ],
      );
    }

    return AppBar(
      backgroundColor: primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      title: GestureDetector(
        onTap: () => _navigateToContactDetail(),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
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
                    (widget.chatLink.name ?? '').isNotEmpty
                        ? (widget.chatLink.name ?? '')
                        : 'Chat ${widget.chatLink.id ?? ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        widget.channel.name ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              _isAppInForeground ? successGreen : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (_pinnedMessages.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pinColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_pinnedMessages.length}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_pinnedMessages.isNotEmpty) ...[
          IconButton(
            icon: Icon(
              _showPinnedMessages ? Icons.push_pin : Icons.push_pin_outlined,
              color: _showPinnedMessages ? pinColor : Colors.white,
            ),
            onPressed: _togglePinnedMessagesView,
            tooltip: 'Pinned Messages',
          ),
        ],
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'contact_info':
                _navigateToContactDetail();
                break;
              case 'refresh':
                _refreshMessages();
                _showSuccessSnackBar('Messages refreshed');
                break;
              case 'clear':
                _clearChat();
                break;
              case 'clear_pins':
                _clearPinnedMessages();
                break;
              case 'info':
                _showChatInfo();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'contact_info',
              child: Row(
                children: [
                  Icon(Icons.person, color: textPrimary),
                  SizedBox(width: 12),
                  Text('Contact Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, color: textPrimary),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.clear_all, color: textPrimary),
                  SizedBox(width: 12),
                  Text('Clear Chat'),
                ],
              ),
            ),
            if (_pinnedMessages.isNotEmpty) ...[
              const PopupMenuItem(
                value: 'clear_pins',
                child: Row(
                  children: [
                    Icon(Icons.push_pin_outlined, color: pinColor),
                    SizedBox(width: 12),
                    Text('Clear Pinned'),
                  ],
                ),
              ),
            ],
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info, color: textPrimary),
                  SizedBox(width: 12),
                  Text('Chat Info'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _clearPinnedMessages() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Clear Pinned Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to unpin all messages?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pinColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _pinnedMessageIds.clear();
                _showPinnedMessages = false;
              });
              await _savePinnedMessages(); // ✅ Save after clearing
              _showSuccessSnackBar('All messages unpinned');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ✅ ENHANCED: Send message with proper reply format using contact names
  void _sendMessage() async {
    final text = _messageController.text.trim();
    final linkIdInt = int.tryParse(widget.chatLink.id);

    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final currentUserId =
        UserService.currentUserId ?? UserService.currentAgentId ?? 'me';
    final currentUserName =
        UserService.currentUserName ?? UserService.currentUsername ?? 'User';

    final now = DateTime.now().toLocal();
    final microTime = now.microsecondsSinceEpoch;
    final tempId = 'temp_${microTime}_${text.hashCode}';

    // ✅ ENHANCED: Create proper reply format using contact names
    String finalContent = text;
    if (_isReplying && _replyingToMessage != null) {
      final repliedToName = _getContactDisplayName(_replyingToMessage!);

      final replyPreview = _replyingToMessage!.content.length > 50
          ? '${_replyingToMessage!.content.substring(0, 50)}...'
          : _replyingToMessage!.content;

      // Format: > ContactName: ReplyContent\n\nActualMessage
      finalContent = '> $repliedToName: $replyPreview\n\n$text';
    }

    final tempMessage = NoboxMessage(
      id: tempId,
      senderId: currentUserId,
      content: finalContent,
      createdAt: now,
      linkId: linkIdInt ?? 0,
      channelId: widget.channel.id,
      roomId: 0,
      isIncoming: false,
      ack: 0,
      senderName: currentUserName,
      bodyType: 1,
    );

    setState(() {
      _messages = _mergeMessages(_messages, [tempMessage]);
      _messageController.clear();
      if (_isReplying) {
        _cancelReply();
      }
    });
    _scrollToBottomSmooth();

    try {
      final response = await ApiService.sendMessage(
        content: finalContent,
        linkId: linkIdInt!,
        channelId: widget.channel.id,
        linkIdExt: widget.chatLink.idExt,
      );

      if (response.success && response.data != null) {
        final realMessage = response.data!.copyWith(
          senderId: currentUserId,
          senderName: currentUserName,
          isIncoming: false,
        );

        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _temporaryMessages.remove(tempId);
          _messageCache.remove(tempId);
          _processedMessageIds.remove(tempId);

          _messages = _mergeMessages(_messages, [realMessage]);
        });

        print('🔥 ✅ Temp replaced with real message');
      } else {
        _markMessageAsFailed(tempMessage, microTime);
      }
    } catch (e) {
      _markMessageAsFailed(tempMessage, microTime);
      _showErrorSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _markMessageAsFailed(NoboxMessage tempMessage, int microTime) {
    final failedMsg = tempMessage.copyWith(
      id: 'failed_${microTime}',
      ack: -1,
    );

    setState(() {
      _messages.removeWhere((m) => m.id == tempMessage.id);
      _messages = _mergeMessages(_messages, [failedMsg]);
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Clear Chat',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
              'Are you sure you want to clear all messages? This action cannot be undone.'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _messages.clear();
                  _processedMessageIds.clear();
                  _temporaryMessages.clear();
                  _messageCache.clear();
                  _pinnedMessageIds.clear();
                  _lastMessageTimestamp = null;
                  _lastKnownMessageCount = 0;
                  _showPinnedMessages = false;
                });
                await _savePinnedMessages(); // ✅ Save after clearing
                _showSuccessSnackBar('Chat cleared successfully');
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Chat Information',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(
                  'Chat Name',
                  (widget.chatLink.name ?? '').isNotEmpty
                      ? (widget.chatLink.name ?? '')
                      : 'Chat ${widget.chatLink.id ?? ''}'),
              const SizedBox(height: 8),
              _buildInfoRow('Link ID', widget.chatLink.id ?? ''),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Link ID Ext',
                  (widget.chatLink.idExt ?? '').isNotEmpty
                      ? (widget.chatLink.idExt ?? '')
                      : 'Not available'),
              const SizedBox(height: 8),
              _buildInfoRow('Channel', widget.channel.name ?? ''),
              const SizedBox(height: 8),
              _buildInfoRow('Channel ID', widget.channel.id.toString()),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Messages',
                  _messages
                      .where((msg) =>
                          !msg.content.contains('"msg":"Site.Inbox.HasAsign"'))
                      .length
                      .toString()),
              const SizedBox(height: 8),
              _buildInfoRow('Pinned', _pinnedMessages.length.toString()),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Forward Available', _availableChats.length.toString()),
              const SizedBox(height: 8),
              _buildInfoRow('Cached', _messageCache.length.toString()),
              const SizedBox(height: 8),
              _buildInfoRow('Temporary', _temporaryMessages.length.toString()),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Processed', _processedMessageIds.length.toString()),
              const SizedBox(height: 8),
              _buildInfoRow('Current User',
                  '${UserService.currentUserId} (${UserService.currentUserName})'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Real-time', _isAppInForeground ? 'Active' : 'Paused'),
              const SizedBox(height: 8),
              _buildInfoRow(
                  'Last Update', _lastMessageTimestamp?.toString() ?? 'Never'),
            ],
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: primaryBlue),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: textPrimary,
              fontSize: 12,
            ),
          ),
        )
      ],
    );
  }
}