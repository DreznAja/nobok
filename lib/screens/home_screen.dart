import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connection_service.dart';
import '../services/filter_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../models/filter_model.dart';
import '../models/message_model.dart';
import '../utils/last_message_renderer.dart';
import '../widget/filter_chip_widget.dart';
import '../widget/filter_conversation_dialog.dart';
import '../screens/new_conversation_dialog.dart';
import '../screens/chat_room_screen.dart';
import '../screens/arsip_contact_screen.dart';
import '../screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Controllers and Focus Nodes
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  
  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  
  // State Variables
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  bool _isOfflineMode = false;
  String _searchQuery = '';
  String _selectedTab = 'all';
  
  // Data Collections
  List<ChatLinkModel> _chatLinks = [];
  List<ChannelModel> _channels = [];
  List<AccountModel> _accounts = [];
  List<ContactModel> _contacts = [];
  Map<String, ChannelModel> _chatChannelMap = {};
  Map<String, LastMessageData> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  Set<String> _archivedChatIds = <String>{};
  
  // Filter State
  ConversationFilter _currentFilter = ConversationFilter();
  
  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color unreadBadge = Color(0xFF007AFF);
  static const Color assignedBadge = Color(0xFF81C784);
  static const Color redMessage = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _setupScrollController();
    _setupSearchController();
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    ConnectionService.dispose();
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
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreChats();
      }
    });
  }

  void _setupSearchController() {
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _initializeData() async {
    try {
      await _checkConnectionStatus();
      await _loadInitialData();
    } catch (e) {
      _showErrorSnackBar('Failed to initialize: $e');
    }
  }

  Future<void> _checkConnectionStatus() async {
    final isConnected = await ConnectionService.checkConnectionNow();
    setState(() {
      _isOfflineMode = !isConnected;
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isOfflineMode) {
        await _loadCachedData();
      } else {
        await _loadFreshData();
      }
    } catch (e) {
      if (_isOfflineMode) {
        await _loadCachedData();
      } else {
        _showErrorSnackBar('Failed to load data: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFreshData() async {
    // Load channels first
    final channelsResponse = await ApiService.getChannels();
    if (channelsResponse.success && channelsResponse.data != null) {
      _channels = channelsResponse.data!;
      await CacheService.saveChannels(_channels);
    }

    // Load accounts
    final accountsResponse = await ApiService.getAccounts();
    if (accountsResponse.success && accountsResponse.data != null) {
      _accounts = accountsResponse.data!;
      await CacheService.saveAccounts(_accounts);
    }

    // Load contacts
    final contactsResponse = await ApiService.getContacts();
    if (contactsResponse.success && contactsResponse.data != null) {
      _contacts = contactsResponse.data!;
      await CacheService.saveContacts(_contacts);
    }

    // Load chat links
    await _loadChatLinks();
    
    // Load last messages
    await _loadLastMessages();
  }

  Future<void> _loadCachedData() async {
    _channels = await CacheService.getCachedChannels();
    _accounts = await CacheService.getCachedAccounts();
    _contacts = await CacheService.getCachedContacts();
    _chatLinks = await CacheService.getCachedChatLinks();
    
    final cachedLastMessages = await CacheService.getCachedLastMessages();
    _processLastMessagesData(cachedLastMessages);
  }

  Future<void> _loadChatLinks() async {
    final response = await ApiService.getChatLinks(
      take: _pageSize,
      skip: _currentPage * _pageSize,
    );

    if (response.success && response.data != null) {
      final newChatLinks = response.data!;
      
      setState(() {
        if (_currentPage == 0) {
          _chatLinks = newChatLinks;
        } else {
          _chatLinks.addAll(newChatLinks);
        }
        _hasMoreData = newChatLinks.length == _pageSize;
      });

      // Build channel map
      _buildChatChannelMap();
      
      // Cache the data
      await CacheService.saveChatLinks(_chatLinks);
    }
  }

  Future<void> _loadLastMessages() async {
    final lastMessagesData = await MessageService.getBatchLastMessages(
      _chatLinks,
      _chatChannelMap,
    );
    
    setState(() {
      _lastMessages = lastMessagesData;
      _unreadCounts = lastMessagesData.map(
        (key, value) => MapEntry(key, value.unreadCount),
      );
    });

    // Cache last messages data
    final cacheData = <String, dynamic>{};
    for (final entry in lastMessagesData.entries) {
      cacheData[entry.key] = {
        'preview': entry.value.preview,
        'isFromCurrentUser': entry.value.isFromCurrentUser,
        'unreadCount': entry.value.unreadCount,
        'timestamp': entry.value.timestamp?.toIso8601String(),
      };
    }
    await CacheService.saveLastMessages(cacheData);
  }

  void _processLastMessagesData(Map<String, dynamic> cachedData) {
    final Map<String, LastMessageData> processedData = {};
    
    for (final entry in cachedData.entries) {
      final data = entry.value as Map<String, dynamic>;
      processedData[entry.key] = LastMessageData(
        message: null,
        preview: data['preview'] ?? 'No messages yet',
        isFromCurrentUser: data['isFromCurrentUser'] ?? false,
        unreadCount: data['unreadCount'] ?? 0,
        timestamp: data['timestamp'] != null 
          ? DateTime.tryParse(data['timestamp'])
          : null,
      );
    }
    
    setState(() {
      _lastMessages = processedData;
      _unreadCounts = processedData.map(
        (key, value) => MapEntry(key, value.unreadCount),
      );
    });
  }

  void _buildChatChannelMap() {
    _chatChannelMap.clear();
    for (final chatLink in _chatLinks) {
      // Find matching channel for this chat link
      final matchingChannel = _channels.firstWhere(
        (channel) => channel.id.toString() == chatLink.id,
        orElse: () => ChannelModel(id: 0, name: 'Unknown'),
      );
      _chatChannelMap[chatLink.id] = matchingChannel;
    }
  }

  Future<void> _loadMoreChats() async {
    if (_isLoadingMore || !_hasMoreData || _isRefreshing) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      await _loadChatLinks();
      await _loadLastMessages();
    } catch (e) {
      _showErrorSnackBar('Failed to load more chats: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _checkConnectionStatus();
      _currentPage = 0;
      _hasMoreData = true;
      
      if (!_isOfflineMode) {
        await _loadFreshData();
      } else {
        await _loadCachedData();
      }
      
      _showSuccessSnackBar(_isOfflineMode 
        ? 'Loaded cached data (offline mode)'
        : 'Data refreshed successfully');
        
    } catch (e) {
      _showErrorSnackBar('Failed to refresh: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  List<ChatLinkModel> get _filteredChats {
    List<ChatLinkModel> filtered = FilterService.applyFilter(
      _chatLinks,
      _currentFilter,
      _unreadCounts,
      _chatChannelMap,
      _contacts,
      archivedChatIds: _archivedChatIds,
    );

    if (_searchQuery.isNotEmpty) {
      final lastMessageContent = _lastMessages.map(
        (key, value) => MapEntry(key, value.preview),
      );
      
      filtered = filtered.where((chat) => 
        FilterService.matchesSearchQuery(chat, _searchQuery, lastMessageContent)
      ).toList();
    }

    return filtered;
  }

  void _onFilterChanged(ConversationFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
    FilterService.saveFilter(filter);
  }

  void _clearFilter() {
    setState(() {
      _currentFilter = ConversationFilter();
    });
    FilterService.clearFilter();
  }

  Future<void> _navigateToNewConversation() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => NewConversationDialog(
        channels: _channels,
        accounts: _accounts,
        contacts: _contacts,
        onConversationCreated: (data) {
          Navigator.of(context).pop(data);
        },
      ),
    );

    if (result != null && result['refresh_needed'] == true) {
      await _handleRefresh();
    }
  }

  Future<void> _navigateToArchivedChats() async {
    final archivedChats = _chatLinks.where((chat) => 
      _archivedChatIds.contains(chat.id)
    ).toList();

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ArsipContactScreen(
          chatLinks: archivedChats,
          chatChannelMap: _chatChannelMap,
          lastMessages: _lastMessages,
          unreadCounts: _unreadCounts,
          onUnarchive: (chatId) {
            setState(() {
              _archivedChatIds.remove(chatId);
            });
          },
        ),
      ),
    );

    if (result == true) {
      await _handleRefresh();
    }
  }

  Future<void> _navigateToChatRoom(ChatLinkModel chatLink) async {
    final channel = _chatChannelMap[chatLink.id];
    if (channel == null) {
      _showErrorSnackBar('Channel not found for this chat');
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatLink: chatLink,
          channel: channel,
          accounts: _accounts,
        ),
      ),
    );

    if (result != null && result['refresh_needed'] == true) {
      await _handleRefresh();
    }
  }

  Future<void> _logout() async {
    try {
      await UserService.clearCurrentUser();
      await CacheService.clearUserSession();
      ApiService.clearAuthToken();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
          (route) => false,
        );
      }
    } catch (e) {
      _showErrorSnackBar('Logout failed: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
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
              const SizedBox(width: 12),
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

  Widget _buildAppBar() {
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
            const SizedBox(width: 16),
            Text(
              'NoBox Chat',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_isOfflineMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              onPressed: () => _showAppMenu(),
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _showAppMenu() {
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
              leading: const Icon(Icons.archive, color: primaryBlue),
              title: Text(
                'Archived Conversations',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _navigateToArchivedChats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: primaryBlue),
              title: Text(
                'Refresh Data',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleRefresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 12),
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

  Widget _buildTabBar() {
    final tabs = [
      {'key': 'all', 'label': 'All'},
      {'key': 'unassigned', 'label': 'Unassigned'},
      {'key': 'assigned', 'label': 'Assigned'},
      {'key': 'resolved', 'label': 'Resolved'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedTab == tab['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = tab['key']!;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tab['label']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : textSecondary,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChatTile(ChatLinkModel chatLink) {
    final lastMessageData = _lastMessages[chatLink.id];
    final unreadCount = _unreadCounts[chatLink.id] ?? 0;
    final hasUnread = unreadCount > 0;
    final chatChannel = _chatChannelMap[chatLink.id];
    
    final lastMessageContent = lastMessageData?.preview ?? "No messages yet";
    
    return Container(
      color: Colors.white,
      child: InkWell(
        onTap: () => _navigateToChatRoom(chatLink),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD3D3D3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    chatLink.name.toLowerCase().contains('grup') || 
                    chatLink.name.toLowerCase().contains('group') ||
                    chatLink.name.toLowerCase().contains('orang-orang')
                      ? Icons.group
                      : Icons.person,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              
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
                              fontSize: 16.5,
                              color: textPrimary,
                              fontFamily: 'Poppins',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Time
                        Text(
                          _formatTime(lastMessageData?.timestamp ?? DateTime.now().subtract(Duration(minutes: chatLink.id.hashCode % 1440))),
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    
                    // Last message and badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13.5,
                                fontFamily: 'Poppins',
                                color: hasUnread ? redMessage : textSecondary,
                                fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                              ),
                              children: _buildLastMessageSpans(lastMessageContent),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 9),
                        
                        // Badge area
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Unread count badge
                            if (hasUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: unreadBadge,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
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

  List<TextSpan> _buildLastMessageSpans(String content) {
    final List<TextSpan> spans = [];
    
    if (content.startsWith('📷')) {
      spans.add(const TextSpan(
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
      spans.add(const TextSpan(
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
      spans.add(const TextSpan(
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
      spans.add(const TextSpan(
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
      spans.add(TextSpan(text: content));
    }
    
    return spans;
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _navigateToNewConversation,
      backgroundColor: primaryBlue,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              ? 'No conversations found'
              : 'No conversations yet',
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
    );
  }

  Widget _buildLoadingIndicator() {
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
    final filteredChats = _filteredChats;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // App Bar
          _buildAppBar(),
          
          // Search Bar
          _buildSearchBar(),
          
          // Tab Bar
          _buildTabBar(),
          
          // Filter Chip
          FilterChipWidget(
            filter: _currentFilter,
            onTap: () async {
              final result = await showDialog<ConversationFilter>(
                context: context,
                builder: (context) => FilterConversationDialog(
                  currentFilter: _currentFilter,
                  channels: _channels,
                  accounts: _accounts,
                  contacts: _contacts,
                  chatLinks: _chatLinks,
                  onApplyFilter: (filter) {
                    Navigator.of(context).pop(filter);
                  },
                ),
              );
              
              if (result != null) {
                _onFilterChanged(result);
              }
            },
            onClear: _clearFilter,
          ),
          
          // Chat List
          Expanded(
            child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                )
              : filteredChats.isEmpty
                  ? _buildEmptyState()
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredChats.length + 1,
                        itemBuilder: (context, index) {
                          if (index < filteredChats.length) {
                            return _buildChatTile(filteredChats[index]);
                          } else {
                            return _buildLoadingIndicator();
                          }
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}