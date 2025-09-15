import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/connection_service.dart';
import '../services/user_service.dart';
import '../services/filter_service.dart';
import '../services/message_service.dart';
import '../models/filter_model.dart';
import '../models/message_model.dart';
import '../utils/last_message_renderer.dart';
import '../widget/filter_chip_widget.dart';
import '../widget/filter_conversation_dialog.dart';
import 'chat_room_screen.dart';
import 'arsip_contact_screen.dart';
import 'new_conversation_dialog.dart';
import 'login_screen.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Data state
  List<ChatLinkModel> _chatLinks = [];
  List<ChannelModel> _channels = [];
  List<AccountModel> _accounts = [];
  List<ContactModel> _contacts = [];
  Map<String, ChannelModel> _chatChannelMap = {};
  Map<String, LastMessageData> _lastMessages = {};
  Map<String, int> _unreadCounts = {};
  
  // UI state
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  String _selectedTab = 'all';
  String _searchQuery = '';
  ConversationFilter _currentFilter = ConversationFilter();
  Set<String> _archivedChatIds = <String>{};
  
  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  // Pagination
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // Real-time updates
  Timer? _realTimeTimer;
  StreamSubscription? _connectionSubscription;
  bool _isOfflineMode = false;
  
  // Colors
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color redMessage = Color(0xFFE53935);
  static const Color unreadBadge = Color(0xFF007AFF);
  static const Color assignedBadge = Color(0xFF81C784);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupScrollController();
    _setupSearchController();
    _setupConnectionListener();
    _initializeData();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _realTimeTimer?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
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

  void _setupConnectionListener() {
    _connectionSubscription = ConnectionService.connectionStream.listen((isConnected) {
      setState(() {
        _isOfflineMode = !isConnected;
      });
      
      if (isConnected && _isOfflineMode) {
        _refreshData();
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load saved filter
      _currentFilter = await FilterService.loadFilter();
      
      // Check connection status
      final isConnected = await ConnectionService.checkConnectionNow();
      setState(() {
        _isOfflineMode = !isConnected;
      });

      if (isConnected) {
        // Online: Load fresh data
        await _loadFreshData();
      } else {
        // Offline: Load cached data
        await _loadCachedData();
      }

    } catch (e) {
      print('🔥 Error initializing data: $e');
      _showErrorSnackBar('Failed to load data: $e');
      
      // Fallback to cached data
      await _loadCachedData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFreshData() async {
    try {
      print('🔥 Loading fresh data from server...');
      
      // Load all data in parallel
      final futures = await Future.wait([
        ApiService.getChatLinks(take: _pageSize, skip: 0),
        ApiService.getChannels(),
        ApiService.getAccounts(),
        ApiService.getContacts(),
      ]);

      final chatLinksResponse = futures[0] as ApiResponse<List<ChatLinkModel>>;
      final channelsResponse = futures[1] as ApiResponse<List<ChannelModel>>;
      final accountsResponse = futures[2] as ApiResponse<List<AccountModel>>;
      final contactsResponse = futures[3] as ApiResponse<List<ContactModel>>;

      if (chatLinksResponse.success && chatLinksResponse.data != null) {
        _chatLinks = chatLinksResponse.data!;
        _hasMoreData = _chatLinks.length >= _pageSize;
        _currentPage = 0;
        
        // Cache the data
        await CacheService.saveChatLinks(_chatLinks);
      }

      if (channelsResponse.success && channelsResponse.data != null) {
        _channels = channelsResponse.data!;
        await CacheService.saveChannels(_channels);
      }

      if (accountsResponse.success && accountsResponse.data != null) {
        _accounts = accountsResponse.data!;
        await CacheService.saveAccounts(_accounts);
      }

      if (contactsResponse.success && contactsResponse.data != null) {
        _contacts = contactsResponse.data!;
        await CacheService.saveContacts(_contacts);
      }

      // Build channel map
      _buildChannelMap();
      
      // Load last messages
      await _loadLastMessages();
      
      print('🔥 ✅ Fresh data loaded successfully');
      
    } catch (e) {
      print('🔥 Error loading fresh data: $e');
      throw e;
    }
  }

  Future<void> _loadCachedData() async {
    try {
      print('🔥 📱 Loading cached data...');
      
      _chatLinks = await CacheService.getCachedChatLinks();
      _channels = await CacheService.getCachedChannels();
      _accounts = await CacheService.getCachedAccounts();
      _contacts = await CacheService.getCachedContacts();
      
      _buildChannelMap();
      
      // Load cached last messages
      final cachedLastMessages = await CacheService.getCachedLastMessages();
      _processLastMessagesData(cachedLastMessages);
      
      print('🔥 📱 ✅ Cached data loaded: ${_chatLinks.length} chats');
      
    } catch (e) {
      print('🔥 Error loading cached data: $e');
    }
  }

  void _buildChannelMap() {
    _chatChannelMap.clear();
    for (final chatLink in _chatLinks) {
      final channel = _channels.firstWhere(
        (ch) => ch.id.toString() == chatLink.id,
        orElse: () => ChannelModel(id: 0, name: 'Unknown'),
      );
      _chatChannelMap[chatLink.id] = channel;
    }
  }

  Future<void> _loadLastMessages() async {
    try {
      print('🔥 Loading last messages for ${_chatLinks.length} chats...');
      
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
      
      // Cache the last messages data
      final cacheData = lastMessagesData.map(
        (key, value) => MapEntry(key, {
          'preview': value.preview,
          'isFromCurrentUser': value.isFromCurrentUser,
          'unreadCount': value.unreadCount,
          'timestamp': value.timestamp?.toIso8601String(),
        }),
      );
      await CacheService.saveLastMessages(cacheData);
      
      print('🔥 ✅ Last messages loaded successfully');
      
    } catch (e) {
      print('🔥 Error loading last messages: $e');
    }
  }

  void _processLastMessagesData(Map<String, dynamic> cachedData) {
    final Map<String, LastMessageData> processedData = {};
    final Map<String, int> unreadCounts = {};
    
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
      unreadCounts[entry.key] = data['unreadCount'] ?? 0;
    }
    
    setState(() {
      _lastMessages = processedData;
      _unreadCounts = unreadCounts;
    });
  }

  Future<void> _loadMoreChats() async {
    if (_isLoadingMore || !_hasMoreData || _isRefreshing) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getChatLinks(
        take: _pageSize,
        skip: nextPage * _pageSize,
      );

      if (response.success && response.data != null) {
        final newChats = response.data!;
        
        setState(() {
          _chatLinks.addAll(newChats);
          _currentPage = nextPage;
          _hasMoreData = newChats.length >= _pageSize;
        });
        
        _buildChannelMap();
        await _loadLastMessages();
      }
    } catch (e) {
      print('🔥 Error loading more chats: $e');
      _showErrorSnackBar('Failed to load more chats');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      _currentPage = 0;
      _hasMoreData = true;
      
      if (ConnectionService.isConnected) {
        await _loadFreshData();
      } else {
        await _loadCachedData();
      }
      
      _showSuccessSnackBar('Data refreshed successfully');
    } catch (e) {
      print('🔥 Error refreshing data: $e');
      _showErrorSnackBar('Failed to refresh data');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _startRealTimeUpdates() {
    _realTimeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (ConnectionService.isConnected && !_isRefreshing) {
        _loadLastMessages();
      }
    });
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

    // Apply tab filter
    switch (_selectedTab) {
      case 'unassigned':
        filtered = filtered.where((chat) => (_unreadCounts[chat.id] ?? 0) > 0).toList();
        break;
      case 'assigned':
        filtered = filtered.where((chat) => (_unreadCounts[chat.id] ?? 0) == 0).toList();
        break;
      case 'resolved':
        // All chats are considered resolved for now
        break;
      case 'all':
      default:
        // No additional filtering
        break;
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((chat) {
        final nameMatch = chat.name.toLowerCase().contains(_searchQuery);
        final channelMatch = _chatChannelMap[chat.id]?.name.toLowerCase().contains(_searchQuery) ?? false;
        final lastMessageData = _lastMessages[chat.id];
        final messageMatch = lastMessageData?.preview.toLowerCase().contains(_searchQuery) ?? false;
        
        return nameMatch || channelMatch || messageMatch;
      }).toList();
    }

    return filtered;
  }

  void _onTabChanged(int index) {
    final tabs = ['all', 'unassigned', 'assigned', 'resolved'];
    setState(() {
      _selectedTab = tabs[index];
    });
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => FilterConversationDialog(
        currentFilter: _currentFilter,
        channels: _channels,
        accounts: _accounts,
        contacts: _contacts,
        chatLinks: _chatLinks,
        onApplyFilter: _onFilterChanged,
      ),
    );
  }

  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => NewConversationDialog(
        channels: _channels,
        accounts: _accounts,
        contacts: _contacts,
        onConversationCreated: (data) {
          _refreshData();
        },
      ),
    );
  }

  Future<void> _navigateToArchivedChats() async {
    try {
      // Load archived chats
      final response = await ApiService.getArchivedChatLinks();
      
      if (response.success && response.data != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArsipContactScreen(
              chatLinks: response.data!,
              chatChannelMap: _chatChannelMap,
              lastMessages: _lastMessages.map(
                (key, value) => MapEntry(key, value.message!),
              ),
              unreadCounts: _unreadCounts,
              onUnarchive: (chatId) {
                setState(() {
                  _archivedChatIds.remove(chatId);
                });
              },
            ),
          ),
        );
        
        // Refresh if any chats were unarchived
        if (result == true) {
          _refreshData();
        }
      }
    } catch (e) {
      print('🔥 Error loading archived chats: $e');
      _showErrorSnackBar('Failed to load archived chats');
    }
  }

  void _navigateToChatRoom(ChatLinkModel chatLink) async {
    final chatChannel = _chatChannelMap[chatLink.id];
    
    if (chatChannel == null) {
      _showErrorSnackBar('Channel not found for this chat');
      return;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatLink: chatLink,
          channel: chatChannel,
          accounts: _accounts.where((acc) => acc.channel == chatChannel.id).toList(),
        ),
      ),
    );
    
    // Refresh if needed
    if (result != null && result['refresh_needed'] == true) {
      _refreshData();
    }
  }

  void _logout() async {
    try {
      await UserService.clearCurrentUser();
      await CacheService.clearCache();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
        (route) => false,
      );
    } catch (e) {
      print('🔥 Error during logout: $e');
      _showErrorSnackBar('Logout failed: $e');
    }
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
                        
                        // Badges
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status badge
                            if (hasUnread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: assignedBadge,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Assigned',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            
                            if (hasUnread) const SizedBox(height: 4),
                            
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
      spans.add(TextSpan(text: content));
    }
    
    return spans;
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
            const SizedBox(width: 16),
            Text(
              'NoBox Chat',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              onPressed: _showFilterDialog,
              icon: Stack(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.white, size: 24),
                  if (_currentFilter.hasActiveFilters)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: _showNewConversationDialog,
              icon: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
              onSelected: (value) {
                switch (value) {
                  case 'archived':
                    _navigateToArchivedChats();
                    break;
                  case 'refresh':
                    _refreshData();
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'archived',
                  child: Row(
                    children: [
                      const Icon(Icons.archive, size: 20),
                      const SizedBox(width: 12),
                      const Text('Archived Chats'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 20),
                      const SizedBox(width: 12),
                      const Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 20, color: Colors.red),
                      const SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
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

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        onTap: _onTabChanged,
        labelColor: primaryBlue,
        unselectedLabelColor: textSecondary,
        indicatorColor: primaryBlue,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Unassigned'),
          Tab(text: 'Assigned'),
          Tab(text: 'Resolved'),
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
          
          // Filter Chip
          FilterChipWidget(
            filter: _currentFilter,
            onTap: _showFilterDialog,
            onClear: _clearFilter,
          ),
          
          // Tab Bar
          _buildTabBar(),
          
          // Chat List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                    ),
                  )
                : filteredChats.isEmpty
                    ? Center(
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
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: primaryBlue,
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: filteredChats.length + (_isLoadingMore ? 1 : 0),
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
    );
  }
}