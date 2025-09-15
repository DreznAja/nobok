import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message_model.dart' show NoboxMessage;
import '../services/api_service.dart';
import '../utils/last_message_renderer.dart';
import 'chat_room_screen.dart';

class ArsipContactScreen extends StatefulWidget {
  final List<ChatLinkModel> chatLinks;
  final Map<String, ChannelModel> chatChannelMap;
  final Map<String, NoboxMessage> lastMessages;
  final Map<String, int> unreadCounts;
  final Function(String) onUnarchive;

  const ArsipContactScreen({
    Key? key,
    required this.chatLinks,
    required this.chatChannelMap,
    required this.lastMessages,
    required this.unreadCounts,
    required this.onUnarchive,
  }) : super(key: key);

  @override
  State<ArsipContactScreen> createState() => _ArsipContactScreenState();
}

class _ArsipContactScreenState extends State<ArsipContactScreen> {
  // ✅ INFINITY SCROLL: ScrollController untuk detect scroll position
  final ScrollController _scrollController = ScrollController();
  
  bool _isSelectionMode = false;
  Set<String> _selectedChatIds = <String>{};

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Local state untuk chat yang sudah di-unarchive
  Set<String> _unarchivedChatIds = <String>{};

  // ✅ INFINITY SCROLL: Pagination variables untuk archived chats
  bool _isLoadingMore = false;
  bool _hasMoreArchivedData = true;
  int _currentArchivedPage = 0;
  static const int _archivedPageSize = 20;
  List<ChatLinkModel> _displayedArchivedChats = [];

  // ✅ NEW: Pull-to-Refresh variables
  bool _isRefreshing = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  // Color constants
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color redMessage = Color(0xFFE53935);
  static const Color unreadBadge = Color(0xFF007AFF);
  static const Color assignedBadge = Color(0xFF81C784);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // ✅ INFINITY SCROLL: Setup scroll controller
    _setupScrollController();
    
    // ✅ INFINITY SCROLL: Initialize dengan data pertama
    _initializeArchivedChats();
  }

  // ✅ INFINITY SCROLL: Setup scroll controller untuk detect scroll ke bottom
  void _setupScrollController() {
    _scrollController.addListener(() {
      // Detect ketika user scroll mendekati bottom (80% dari total scroll)
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreArchivedChats();
      }
    });
  }

  // ✅ INFINITY SCROLL: Initialize dengan memuat halaman pertama archived chats
  void _initializeArchivedChats() {
    final initialChats = widget.chatLinks.take(_archivedPageSize).toList();
    
    setState(() {
      _displayedArchivedChats = initialChats;
      _hasMoreArchivedData = widget.chatLinks.length > _archivedPageSize;
      print('🔥 Initialized with ${_displayedArchivedChats.length} archived chats, hasMore: $_hasMoreArchivedData');
    });
  }

  // ✅ NEW: Pull-to-Refresh handler
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔄 Pull-to-Refresh: Refreshing archived chats...');
      
      // Simulate network delay untuk better UX
      await Future.delayed(const Duration(seconds: 2));
      
      // Reset pagination dan reload data
      _currentArchivedPage = 0;
      _hasMoreArchivedData = true;
      
      // Reinitialize dengan data fresh
      final refreshedChats = widget.chatLinks.take(_archivedPageSize).toList();
      
      setState(() {
        _displayedArchivedChats = refreshedChats;
        _hasMoreArchivedData = widget.chatLinks.length > _archivedPageSize;
        _unarchivedChatIds.clear(); // Reset unarchived state pada refresh
      });
      
      print('🔄 ✅ Refresh completed. Loaded ${_displayedArchivedChats.length} archived chats');
      
      _showSuccessSnackBar('Archived conversations refreshed');
      
    } catch (e) {
      print('🔄 ❌ Error during refresh: $e');
      _showErrorSnackBar('Failed to refresh: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // ✅ INFINITY SCROLL: Load more archived chats ketika scroll ke bottom
  Future<void> _loadMoreArchivedChats() async {
    // Prevent multiple simultaneous load more calls
    if (_isLoadingMore || !_hasMoreArchivedData || _isRefreshing) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      print('🔥 Loading more archived chats - Page: ${_currentArchivedPage + 1}');
      
      // Simulate loading delay untuk better UX
      await Future.delayed(const Duration(milliseconds: 500));
      
      final startIndex = (_currentArchivedPage + 1) * _archivedPageSize;
      final endIndex = startIndex + _archivedPageSize;
      
      final nextBatch = widget.chatLinks.skip(startIndex).take(_archivedPageSize).toList();
      
      if (nextBatch.isNotEmpty) {
        setState(() {
          _displayedArchivedChats.addAll(nextBatch);
          _currentArchivedPage++;
          _hasMoreArchivedData = widget.chatLinks.length > endIndex;
        });
        
        print('🔥 ✅ Loaded ${nextBatch.length} more archived chats. Total: ${_displayedArchivedChats.length}');
      } else {
        // No more data available
        setState(() {
          _hasMoreArchivedData = false;
        });
        print('🔥 No more archived chats to load');
      }
      
    } catch (e) {
      print('🔥 Error loading more archived chats: $e');
      _showErrorSnackBar('Failed to load more chats: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose(); // ✅ INFINITY SCROLL: Dispose scroll controller
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // ✅ INFINITY SCROLL: Updated filter untuk menggunakan displayed chats dengan search
  List<ChatLinkModel> get _filteredChats {
    // Filter out chats yang sudah di-unarchive dari displayed chats
    final availableChats = _displayedArchivedChats.where((chat) => 
      !_unarchivedChatIds.contains(chat.id)
    ).toList();

    if (_searchQuery.isEmpty) {
      return availableChats;
    }
    
    return availableChats.where((chat) {
      // Search by contact name
      final nameMatch = chat.name.toLowerCase().contains(_searchQuery);
      
      // Search by channel name (if available)
      final channelMatch = widget.chatChannelMap[chat.id]?.name.toLowerCase().contains(_searchQuery) ?? false;
      
      // Search by last message content
      final lastMessage = widget.lastMessages[chat.id];
      final messageMatch = lastMessage != null ? 
          LastMessageRenderer.renderLastMessage(lastMessage).toLowerCase().contains(_searchQuery) : false;
      
      return nameMatch || channelMatch || messageMatch;
    }).toList();
  }

  void _enterSelectionMode(String chatId) {
    setState(() {
      _isSelectionMode = true;
      _selectedChatIds.add(chatId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  void _unarchiveSelectedChats() {
    // Simpan chat IDs yang akan di-unarchive
    final chatsToUnarchive = Set<String>.from(_selectedChatIds);
    
    // Panggil fungsi unarchive untuk setiap chat
    for (String chatId in chatsToUnarchive) {
      widget.onUnarchive(chatId);
    }
    
    // Update local state untuk menyembunyikan chat yang sudah di-unarchive
    setState(() {
      _unarchivedChatIds.addAll(chatsToUnarchive);
    });

    _showSuccessSnackBar('${chatsToUnarchive.length} chat(s) unarchived');
    _exitSelectionMode();
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message, 
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () {
              // Implementasi undo jika diperlukan
              setState(() {
                _unarchivedChatIds.clear();
              });
            },
          ),
        ),
      );
    }
  }

  void _navigateToChatRoom(ChatLinkModel chatLink) async {
    if (_isSelectionMode) {
      // In selection mode, toggle selection instead of navigating
      setState(() {
        if (_selectedChatIds.contains(chatLink.id)) {
          _selectedChatIds.remove(chatLink.id);
          if (_selectedChatIds.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedChatIds.add(chatLink.id);
        }
      });
      return;
    }

    // Navigate to chat room normally
    final chatChannel = widget.chatChannelMap[chatLink.id];
    
    if (chatChannel == null) {
      _showErrorSnackBar('Channel not found for this chat');
      return;
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatLink: chatLink,
          channel: chatChannel,
          accounts: const [], // Empty accounts list for archived chats
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}.${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  // ✅ ENHANCED: Chat tile dengan proper last message rendering dan ikon
// ✅ ENHANCED: Chat tile dengan UKURAN YANG SAMA dengan home screen
// ✅ ENHANCED: Chat tile dengan UKURAN YANG SAMA dengan home screen
Widget _buildChatTile(ChatLinkModel chatLink) {
  final lastMessage = widget.lastMessages[chatLink.id];
  final unreadCount = widget.unreadCounts[chatLink.id] ?? 0;
  final hasUnread = unreadCount > 0;
  final chatChannel = widget.chatChannelMap[chatLink.id];
  final isSelected = _selectedChatIds.contains(chatLink.id);
  
  // ✅ CRITICAL: Render last message dengan ikon yang tepat
  final lastMessageContent = lastMessage != null 
      ? LastMessageRenderer.renderLastMessage(lastMessage)
      : "No messages yet";
  
  return Container(
    color: isSelected ? primaryBlue.withOpacity(0.1) : Colors.white,
    child: InkWell(
      onTap: () => _navigateToChatRoom(chatLink),
      onLongPress: () {
        if (!_isSelectionMode) {
          _enterSelectionMode(chatLink.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // ✅ SAMA dengan home: 14 (increased from 12)
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection checkbox in selection mode
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedChatIds.add(chatLink.id);
                    } else {
                      _selectedChatIds.remove(chatLink.id);
                      if (_selectedChatIds.isEmpty) {
                        _isSelectionMode = false;
                      }
                    }
                  });
                },
                activeColor: primaryBlue,
              ),
              const SizedBox(width: 8),
            ],
            
            // Avatar - SAMA dengan home screen
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 50, // ✅ SAMA dengan home: 50 (increased from 48)
                height: 50, // ✅ SAMA dengan home: 50 (increased from 48)
                decoration: const BoxDecoration(
                  color: Color(0xFFD3D3D3), // ✅ SAMA dengan home: D3D3D3 (changed from C4C4C4)
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  chatLink.name.toLowerCase().contains('grup') || 
                  chatLink.name.toLowerCase().contains('group') ||
                  chatLink.name.toLowerCase().contains('orang-orang')
                    ? Icons.group
                    : Icons.person,
                  color: Colors.white,
                  size: 31, // ✅ SAMA dengan home: 31 (increased from 28)
                ),
              ),
            ),
            const SizedBox(width: 13), // ✅ SAMA dengan home: 13 (increased from 12)
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Contact name
                      Expanded(
                        child: Text(
                          chatLink.name.isNotEmpty ? chatLink.name : 'Chat ${chatLink.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16.5, // ✅ SAMA dengan home: 16.5 (increased from 16)
                            color: textPrimary,
                            fontFamily: 'Poppins',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // Time
                      Text(
                        _formatTime(lastMessage?.createdAt ?? DateTime.now().subtract(Duration(minutes: chatLink.id.hashCode % 1440))),
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 12.5, // ✅ SAMA dengan home: 12.5 (increased from 12)
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5), // ✅ SAMA dengan home: 5 (increased from 4)
                  
                  // ✅ ENHANCED: Last message dengan badges di sebelah kanan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 13.5, // ✅ SAMA dengan home: 13.5 (increased from 13)
                              fontFamily: 'Poppins',
                              // PERFECT COLOR LOGIC for archived chats:
                              // - Red untuk unread messages
                              // - Gray untuk read messages
                              color: hasUnread ? redMessage : textSecondary,
                              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                            ),
                            children: _buildLastMessageSpans(lastMessageContent),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 9), // ✅ SAMA dengan home: 9 (increased from 8)
                      
                      // Badge area - hanya unread count badge yang diposisikan ke kanan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Unread count badge - diposisikan ke kanan
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 2.5), // ✅ SAMA dengan home: 8.5, 2.5
                              decoration: BoxDecoration(
                                color: unreadBadge,
                                borderRadius: BorderRadius.circular(11), // ✅ SAMA dengan home: 11
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5, // ✅ SAMA dengan home: 11.5
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  /// ✅ NEW: Build text spans untuk last message dengan ikon yang tepat di archive
  List<TextSpan> _buildLastMessageSpans(String content) {
    final List<TextSpan> spans = [];
    
    // ✅ PERFECT: Detect dan render ikon dengan warna yang tepat
    if (content.startsWith('📷')) {
      // Photo message
      spans.add(TextSpan(
        text: '📷 ',
        style: TextStyle(fontSize: 14),
      ));
      spans.add(TextSpan(
        text: 'Photo',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.green[600],
        ),
      ));
    } else if (content.startsWith('📽')) {
      // Video message
      spans.add(TextSpan(
        text: '📽 ',
        style: TextStyle(fontSize: 14),
      ));
      spans.add(TextSpan(
        text: 'Video',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.purple[600],
        ),
      ));
    } else if (content.startsWith('🔉')) {
      // Audio message
      spans.add(TextSpan(
        text: '🔉 ',
        style: TextStyle(fontSize: 14),
      ));
      spans.add(TextSpan(
        text: 'Audio',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.orange[600],
        ),
      ));
    } else if (content.startsWith('📂')) {
      // Document message
      spans.add(TextSpan(
        text: '📂 ',
        style: TextStyle(fontSize: 14),
      ));
      spans.add(TextSpan(
        text: 'Document',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.blue[600],
        ),
      ));
    } else {
      // Regular text message
      spans.add(TextSpan(text: content));
    }
    
    return spans;
  }

Widget _buildAppBar() {
  if (_isSelectionMode) {
    // Selection mode app bar with unarchive button
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
              onPressed: _exitSelectionMode,
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
            Expanded(
              child: Text(
                '${_selectedChatIds.length} selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            IconButton(
              onPressed: _selectedChatIds.isNotEmpty ? _unarchiveSelectedChats : null,
              icon: const Icon(
                Icons.unarchive,
                color: Colors.white, 
                size: 24
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  } else {
    // Normal app bar with close button yang mengembalikan result
    return Container(
      color: primaryBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                // Kembalikan informasi apakah ada chat yang di-unarchive
                Navigator.pop(context, _unarchivedChatIds.isNotEmpty);
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 8),
            const Text(
              'Archived Conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

Widget _buildSearchBar() {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Search conversation',
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.search,
              color: Colors.black,
              size: 22,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  child: Icon(
                    Icons.close,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ),
              )
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 12,
          ),
          isDense: true,
        ),
        cursorColor: Colors.black,
        cursorWidth: 1,
      ),
    ),
  );
}

  // ✅ NEW: Loading indicator di atas column contact (untuk refresh)
  Widget _buildTopLoadingIndicator() {
    if (!_isRefreshing) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Refreshing archived conversations...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ INFINITY SCROLL: Build loading indicator untuk bottom
  Widget _buildLoadingIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 2,
            ),
            SizedBox(height: 8),
            Text(
              'Loading more archived conversations...',
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ INFINITY SCROLL: Build end of list indicator
  Widget _buildEndOfListIndicator() {
    if (_hasMoreArchivedData || _isLoadingMore || _displayedArchivedChats.length < _archivedPageSize) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.archive,
              color: Colors.orange[400],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              'All archived conversations loaded',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_displayedArchivedChats.length} total archived',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _filteredChats;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Dynamic App Bar
          _buildAppBar(),
          
          // Search Bar
          _buildSearchBar(),
          
          // Results info
          if (_searchQuery.isNotEmpty)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: Text(
                '${filteredChats.length} archived chat${filteredChats.length != 1 ? 's' : ''} found for "$_searchQuery"',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          // ✅ NEW: Loading indicator di atas column contact
          _buildTopLoadingIndicator(),
          
          // ✅ ENHANCED: Chat list dengan Pull-to-Refresh dan Infinity Scroll
          Expanded(
            child: filteredChats.isEmpty && !_isLoadingMore && !_isRefreshing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Chat bubble icon dengan desain yang lebih clean
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty 
                              ? Icons.search_off
                              : Icons.chat_bubble_outline,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _searchQuery.isNotEmpty
                            ? 'No archived conversations found'
                            : 'No Archived Conversation found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                            child: Text(
                              'Clear search',
                              style: GoogleFonts.poppins(
                                color: primaryBlue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    key: _refreshIndicatorKey,
                    onRefresh: _handleRefresh,
                    color: primaryBlue,
                    backgroundColor: Colors.white,
                    strokeWidth: 2.5,
                    displacement: 40,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      physics: const AlwaysScrollableScrollPhysics(), // ✅ NEW: Enable pull-to-refresh even when list is short
                      itemCount: filteredChats.length + 
                                (_isLoadingMore ? 1 : 0) + 
                                (!_hasMoreArchivedData ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Chat tiles
                        if (index < filteredChats.length) {
                          return _buildChatTile(filteredChats[index]);
                        }
                        
                        // Loading more indicator
                        if (index == filteredChats.length && _isLoadingMore) {
                          return _buildLoadingIndicator();
                        }
                        
                        // End of list indicator
                        if (index == filteredChats.length && !_hasMoreArchivedData) {
                          return _buildEndOfListIndicator();
                        }
                        
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}