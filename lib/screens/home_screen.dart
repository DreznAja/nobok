import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nobox_mobile/screens/new_conversation_dialog.dart';
import 'package:nobox_mobile/services/cache_service.dart';
import 'package:nobox_mobile/services/connection_service.dart';
import 'package:nobox_mobile/widget/filter_chip_widget.dart';
import 'package:nobox_mobile/widget/filter_conversation_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/message_model.dart' show NoboxMessage;
import '../models/filter_model.dart';
import '../services/api_service.dart';
import '../services/filter_service.dart';
import '../services/user_service.dart';
import '../services/message_service.dart';
import '../utils/last_message_renderer.dart';
import 'chat_room_screen.dart';
import 'login_screen.dart';
import 'arsip_contact_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  List<ChatLinkModel> _chatLinks = [];
  List<ChannelModel> _channels = [];
  List<AccountModel> _accounts = [];
  List<ContactModel> _contacts = [];

  // ✅ ENHANCED: Last message tracking with proper data structure + offline support
  Map<String, LastMessageData> _lastMessagesData = {};
  Map<String, ChannelModel> _chatChannelMap = {};

  ChannelModel? _selectedChannel;

  bool _isLoading = false;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;
  bool _isRefreshing = false;

  // ✅ NEW: Offline mode variables
  bool _isOfflineMode = false;
  bool _isServerAvailable = true;
  StreamSubscription<bool>? _connectionSubscription;
  DateTime? _lastSuccessfulUpdate;

  bool _isSearchMode = false;
  FocusNode _searchFocusNode = FocusNode();

  // Infinity scroll variables
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  static const int _pageSize = 9;

  // ✅ ENHANCED: Real-time system with offline support
  Timer? _masterRealTimeTimer;
  bool _isRealTimeActive = true;
  DateTime? _lastGlobalUpdate;
  StreamController<Map<String, LastMessageData>>? _lastMessageStreamController;

  late AnimationController _fadeController;
  late AnimationController _slideController;

  String _debugInfo = '';

  // Filter state
  int _selectedFilterIndex = 0;
  final List<String> _filterTabs = [
    'All',
    'Unassigned',
    'Assigned',
    'Resolved'
  ];
  ConversationFilter _currentFilter = ConversationFilter();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isInitializing = false;
  DateTime? _lastRefresh;

  Set<String> _loadedChats = <String>{};
  Map<String, DateTime> _lastLoadTime = <String, DateTime>{};

  // User management
  Set<String> _pinnedChatIds = <String>{};
  bool _isSelectionMode = false;
  Set<String> _selectedChatIds = <String>{};
  String? _currentUserId;
  Set<String> _archivedChatIds = <String>{};

  // Color Palette
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color redMessage = Color(0xFFE53935);
  static const Color unreadBadge = Color(0xFF007AFF);
  static const Color assignedBadge = Color(0xFF81C784);
  static const Color offlineColor = Color(0xFFFF6B6B);
  static const Color onlineColor = Color(0xFF4ECDC4);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchController.addListener(_onSearchChanged);

    _setupScrollController();

    _getCurrentUserId();
    _initializeEnhancedApp(); // ✅ ENHANCED: Changed from _initializeData()
    _loadSavedFilter();
    _fadeController.forward();

    // ✅ ENHANCED: Initialize enhanced real-time system with offline support
    _initializeEnhancedRealTimeSystem();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreChats();
      }
    });
  }

  /// ✅ NEW: Enhanced app initialization dengan offline support
  Future<void> _initializeEnhancedApp() async {
    try {
      // Initialize connection service
      await ConnectionService.initialize();

      // Listen to connection changes
      _connectionSubscription =
          ConnectionService.connectionStream.listen((isConnected) {
        if (mounted) {
          setState(() {
            _isServerAvailable = isConnected;
            _isOfflineMode = !isConnected;
          });

          if (isConnected && _isOfflineMode) {
            // Back online - sync data
            print('🔥 📡 Back online - syncing data');
            _syncDataFromServer();
          } else if (!isConnected) {
            // Gone offline - use cached data
            print('🔥 📡 Gone offline - using cached data');
            _loadDataFromCacheOnly();
          }
        }
      });

      // Check initial connection and load data accordingly
      final isConnected = await ConnectionService.checkConnectionNow();

      if (mounted) {
        setState(() {
          _isServerAvailable = isConnected;
          _isOfflineMode = !isConnected;
        });
      }

      if (isConnected) {
        await _loadDataFromServer();
      } else {
        await _loadDataFromCacheOnly();
      }
    } catch (e) {
      print('🔥 Error initializing enhanced app: $e');
      // Fallback to cached data
      await _loadDataFromCacheOnly();
    }
  }

  /// ✅ NEW: Load data dari server dan cache ke local storage
  Future<void> _loadDataFromServer() async {
    try {
      print('🔥 🌐 Loading data from server...');

      if (mounted) {
        setState(() {
          _isLoading = true;
          _debugInfo = 'Loading from server...';
        });
      }

      // Load dari server dengan caching
      await _loadChannelsFromServer();
      await _loadAccountsFromServer();
      await _loadContactsFromServer();
      await _loadAllChatLinksFromServer();

      // Update last successful update time
      _lastSuccessfulUpdate = DateTime.now();

      print('🔥 ✅ Server data loaded and cached successfully');
    } catch (e) {
      print('🔥 Error loading from server, falling back to cache: $e');
      await _loadDataFromCacheOnly();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ✅ NEW: Load data dari cache saja (offline mode)
  Future<void> _loadDataFromCacheOnly() async {
    try {
      print('🔥 📱 Loading data from cache only...');

      if (mounted) {
        setState(() {
          _isLoading = true;
          _debugInfo = 'Loading from cache...';
          _isOfflineMode = true;
        });
      }

      final channels = await CacheService.getCachedChannels();
      final accounts = await CacheService.getCachedAccounts();
      final contacts = await CacheService.getCachedContacts();
      final chatLinks = await CacheService.getCachedChatLinks();
      final cachedLastMessages = await CacheService.getCachedLastMessages();

      if (mounted) {
        setState(() {
          _channels = channels;
          _accounts = accounts;
          _contacts = contacts;
          _chatLinks = chatLinks;

          if (_channels.isNotEmpty && _selectedChannel == null) {
            _selectedChannel = _channels.first;
          }

          // Setup chat channel map
          _chatChannelMap.clear();
          for (final chatLink in _chatLinks) {
            final matchingChannel = _channels.firstWhere(
              (channel) => channel.id == 1, // Default to channel 1
              orElse: () => _channels.isNotEmpty
                  ? _channels.first
                  : ChannelModel(id: 1, name: 'Default'),
            );
            _chatChannelMap[chatLink.id] = matchingChannel;
          }

          // Convert cached last messages to proper format
          _lastMessagesData.clear();
          cachedLastMessages.forEach((chatId, data) {
            if (data is Map<String, dynamic>) {
              _lastMessagesData[chatId] = LastMessageData(
                message: null, // We don't cache full message objects
                preview: data['preview']?.toString() ?? 'No messages yet',
                isFromCurrentUser: data['isFromCurrentUser'] == true,
                unreadCount: data['unreadCount'] ?? 0,
                timestamp: data['timestamp'] != null
                    ? DateTime.tryParse(data['timestamp'])
                    : null,
              );
            }
          });

          _debugInfo = 'Loaded from cache: ${_chatLinks.length} chats';
        });
      }

      final cacheStatus = await CacheService.getCacheStatus();
      print('🔥 📱 Cache data loaded:');
      print('🔥    Channels: ${channels.length}');
      print('🔥    Accounts: ${accounts.length}');
      print('🔥    Contacts: ${contacts.length}');
      print('🔥    Chat Links: ${chatLinks.length}');
      print('🔥    Last Messages: ${cachedLastMessages.length}');
      print('🔥    Cache Age: ${cacheStatus['cacheAge']} minutes');

      if (_chatLinks.isEmpty) {
        if (mounted) {
          setState(() {
            _debugInfo =
                'No cached data available. Please connect to internet.';
          });
        }
      }
    } catch (e) {
      print('🔥 Error loading from cache: $e');
      if (mounted) {
        setState(() {
          _debugInfo = 'Error loading cached data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ✅ NEW: Sync data from server when back online
  Future<void> _syncDataFromServer() async {
    try {
      print('🔥 🔄 Syncing data from server...');

      // Load fresh data from server
      await _loadDataFromServer();

      if (mounted) {
        _showSuccessSnackBar('✅ Data synced successfully!');
      }
    } catch (e) {
      print('🔥 Error syncing from server: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to sync data from server');
      }
    }
  }

  /// ✅ ENHANCED: Load channels dengan caching
  Future<void> _loadChannelsFromServer() async {
    try {
      print('🔥 Loading channels from server...');

      final response = await ApiService.getChannels();

      if (response.success && response.data != null) {
        final channels = response.data!;

        // Cache channels
        await CacheService.saveChannels(channels);

        if (mounted) {
          setState(() {
            _channels = channels;
            if (_channels.isNotEmpty && _selectedChannel == null) {
              _selectedChannel = _channels.first;
            }
            _debugInfo = '${_channels.length} channels loaded & cached';
          });
        }

        print('🔥 ✅ ${channels.length} channels loaded and cached');
      } else {
        print('🔥 Failed to load channels from server');

        // Fallback to cached data
        final cachedChannels = await CacheService.getCachedChannels();
        if (mounted) {
          setState(() {
            _channels = cachedChannels;
            if (_channels.isNotEmpty && _selectedChannel == null) {
              _selectedChannel = _channels.first;
            }
            _debugInfo = '${cachedChannels.length} channels from cache';
          });
        }
      }
    } catch (e) {
      print('🔥 Error loading channels: $e');

      // Fallback to cached data
      final cachedChannels = await CacheService.getCachedChannels();
      if (mounted) {
        setState(() {
          _channels = cachedChannels;
          if (_channels.isNotEmpty && _selectedChannel == null) {
            _selectedChannel = _channels.first;
          }
          _debugInfo = 'Channel error, using cache: ${cachedChannels.length}';
        });
      }
    }
  }

  /// ✅ ENHANCED: Load accounts dengan caching
  Future<void> _loadAccountsFromServer() async {
    if (_selectedChannel == null) return;

    try {
      print('🔥 Loading accounts from server...');

      final response =
          await ApiService.getAccounts(channelId: _selectedChannel?.id);

      if (response.success && response.data != null) {
        final accounts = response.data!;

        // Cache accounts
        await CacheService.saveAccounts(accounts);

        if (mounted) {
          setState(() {
            _accounts = accounts;
            _debugInfo = '${_accounts.length} accounts loaded & cached';
          });
        }

        print('🔥 ✅ ${accounts.length} accounts loaded and cached');
      } else {
        // Fallback to cached data
        final cachedAccounts = await CacheService.getCachedAccounts();
        if (mounted) {
          setState(() {
            _accounts = cachedAccounts;
            _debugInfo = '${cachedAccounts.length} accounts from cache';
          });
        }
      }
    } catch (e) {
      print('🔥 Error loading accounts: $e');

      // Fallback to cached data
      final cachedAccounts = await CacheService.getCachedAccounts();
      if (mounted) {
        setState(() {
          _accounts = cachedAccounts;
          _debugInfo = 'Account error, using cache: ${cachedAccounts.length}';
        });
      }
    }
  }

  /// ✅ ENHANCED: Load contacts dengan caching
  Future<void> _loadContactsFromServer() async {
    try {
      print('🔥 Loading contacts from server...');

      final response = await ApiService.getContactList();

      if (response.success && response.data != null) {
        final contacts = response.data!;

        // Cache contacts
        await CacheService.saveContacts(contacts);

        if (mounted) {
          setState(() {
            _contacts = contacts;
            _debugInfo = '${_contacts.length} contacts loaded & cached';
          });
        }

        print('🔥 ✅ ${contacts.length} contacts loaded and cached');
      } else {
        // Fallback to cached data
        final cachedContacts = await CacheService.getCachedContacts();
        if (mounted) {
          setState(() {
            _contacts = cachedContacts;
            _debugInfo = '${cachedContacts.length} contacts from cache';
          });
        }
      }
    } catch (e) {
      print('🔥 Error loading contacts: $e');

      // Fallback to cached data
      final cachedContacts = await CacheService.getCachedContacts();
      if (mounted) {
        setState(() {
          _contacts = cachedContacts;
          _debugInfo = 'Contact error, using cache: ${cachedContacts.length}';
        });
      }
    }
  }

  /// ✅ ENHANCED: Load chat links dengan caching
  Future<void> _loadAllChatLinksFromServer() async {
    if (_channels.isEmpty) return;

    try {
      print('🔥 Loading chat links from server...');

      if (mounted) {
        setState(() {
          _isLoadingChats = true;
          _debugInfo = 'Loading chat links from server...';
        });
      }

      List<ChatLinkModel> allChatLinks = [];
      Map<String, ChannelModel> tempChatChannelMap = {};

      for (final channel in _channels) {
        try {
          final response = await ApiService.getChatLinks(
            channelId: channel.id,
            take: _pageSize,
            skip: 0,
          );

          if (response.success && response.data != null) {
            final chatLinks = response.data!;

            for (final chatLink in chatLinks) {
              tempChatChannelMap[chatLink.id] = channel;  
            }

            allChatLinks.addAll(chatLinks);
            print(
                '🔥 Loaded ${chatLinks.length} chat links from channel ${channel.name}');
          }
        } catch (e) {
          print('🔥 Error loading chat links from channel ${channel.id}: $e');
        }
      }

      // Cache chat links
      await CacheService.saveChatLinks(allChatLinks);

      if (mounted) {
        setState(() {
          _chatLinks = allChatLinks;
          _chatChannelMap = tempChatChannelMap;
          _debugInfo = '${_chatLinks.length} chats loaded & cached from server';
          _hasMoreData = allChatLinks.length >= _pageSize;
        });
      }

      // Load last messages with caching
      await _loadLastMessagesWithCaching();

      print('🔥 ✅ ${allChatLinks.length} chat links loaded and cached');
    } catch (e) {
      print('🔥 Error loading chat links from server: $e');

      // Fallback to cached data
      final cachedChatLinks = await CacheService.getCachedChatLinks();
      if (mounted) {
        setState(() {
          _chatLinks = cachedChatLinks;

          // Setup channel mapping for cached data
          _chatChannelMap.clear();
          for (final chatLink in _chatLinks) {
            final matchingChannel = _channels.firstWhere(
              (channel) => channel.id == 1, // Default assumption
              orElse: () => _channels.isNotEmpty
                  ? _channels.first
                  : ChannelModel(id: 1, name: 'Default'),
            );
            _chatChannelMap[chatLink.id] = matchingChannel;
          }

          _debugInfo = 'Chat error, using cache: ${cachedChatLinks.length}';
        });
      }

      // Try to load cached last messages
      final cachedLastMessages = await CacheService.getCachedLastMessages();
      if (mounted && cachedLastMessages.isNotEmpty) {
        setState(() {
          _lastMessagesData.clear();
          cachedLastMessages.forEach((chatId, data) {
            if (data is Map<String, dynamic>) {
              _lastMessagesData[chatId] = LastMessageData(
                message: null,
                preview: data['preview']?.toString() ?? 'No messages yet',
                isFromCurrentUser: data['isFromCurrentUser'] == true,
                unreadCount: data['unreadCount'] ?? 0,
                timestamp: data['timestamp'] != null
                    ? DateTime.tryParse(data['timestamp'])
                    : null,
              );
            }
          });
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChats = false;
        });
      }
    }
  }

  /// ✅ ENHANCED: Load last messages dengan caching
  Future<void> _loadLastMessagesWithCaching() async {
    if (_chatLinks.isEmpty) return;

    try {
      print('🔥 Loading last messages with caching...');

      if (mounted) {
        setState(() {
          _isLoadingMessages = true;
          _debugInfo = 'Loading last messages...';
        });
      }

      Map<String, LastMessageData> newLastMessagesData = {};

      if (_isOfflineMode) {
        // Use cached last messages only
        final cachedLastMessages = await CacheService.getCachedLastMessages();
        cachedLastMessages.forEach((chatId, data) {
          if (data is Map<String, dynamic>) {
            newLastMessagesData[chatId] = LastMessageData(
              message: null,
              preview: data['preview']?.toString() ?? 'No messages yet',
              isFromCurrentUser: data['isFromCurrentUser'] == true,
              unreadCount: data['unreadCount'] ?? 0,
              timestamp: data['timestamp'] != null
                  ? DateTime.tryParse(data['timestamp'])
                  : null,
            );
          }
        });
      } else {
        // Load from server and cache
        newLastMessagesData = await MessageService.getBatchLastMessages(
            _chatLinks, _chatChannelMap);

        // Cache last messages in a serializable format
        final cacheData = <String, dynamic>{};
        newLastMessagesData.forEach((chatId, lastMessageData) {
          cacheData[chatId] = {
            'preview': lastMessageData.preview,
            'isFromCurrentUser': lastMessageData.isFromCurrentUser,
            'unreadCount': lastMessageData.unreadCount,
            'timestamp': lastMessageData.timestamp?.toIso8601String(),
          };
        });

        await CacheService.saveLastMessages(cacheData);
      }

      if (mounted) {
        setState(() {
          _lastMessagesData = newLastMessagesData;
          _debugInfo = 'Last messages loaded: ${newLastMessagesData.length}';
        });
      }

      print(
          '🔥 ✅ Last messages loaded and cached: ${newLastMessagesData.length}');
    } catch (e) {
      print('🔥 Error loading last messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  Future<void> _loadMoreChats() async {
    if (_isLoadingMore || !_hasMoreData || _isLoading || _isOfflineMode) {
      return; // Don't load more in offline mode
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      print('🔥 Loading more chats - Page: ${_currentPage + 1}');

      List<ChatLinkModel> moreChatLinks = [];
      Map<String, ChannelModel> moreChatChannelMap = {};

      for (final channel in _channels) {
        try {
          final response = await ApiService.getChatLinks(
            channelId: channel.id,
            take: _pageSize,
            skip: (_currentPage + 1) * _pageSize,
          );

          if (response.success && response.data != null) {
            final chatLinks = response.data!;
            print(
                '🔥 Loaded ${chatLinks.length} more chat links from channel ${channel.name}');

            for (final chatLink in chatLinks) {
              moreChatChannelMap[chatLink.id] = channel;
            }

            moreChatLinks.addAll(chatLinks);
          }
        } catch (e) {
          print(
              '🔥 Error loading more chat links from channel ${channel.id}: $e');
        }
      }

      if (moreChatLinks.isNotEmpty) {
        // Update local state
        setState(() {
          _chatLinks.addAll(moreChatLinks);
          _chatChannelMap.addAll(moreChatChannelMap);
          _currentPage++;
        });

        // Update cache
        await CacheService.saveChatLinks(_chatLinks);

        // ✅ ENHANCED: Load last messages untuk chats baru
        await _loadLastMessagesForNewChats(moreChatLinks);

        print('🔥 ✅ Successfully loaded ${moreChatLinks.length} more chats');
      } else {
        setState(() {
          _hasMoreData = false;
        });
        print('🔥 No more chats to load');
      }
    } catch (e) {
      print('🔥 Error loading more chats: $e');
      if (!_isOfflineMode) {
        _showErrorSnackBar('Failed to load more chats: $e');
      }
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// ✅ ENHANCED: Load last messages untuk chats baru dengan caching
  Future<void> _loadLastMessagesForNewChats(
      List<ChatLinkModel> newChats) async {
    try {
      print('🔥 Loading last messages for ${newChats.length} new chats');

      if (_isOfflineMode) {
        // In offline mode, set default data
        for (final chat in newChats) {
          _lastMessagesData[chat.id] = LastMessageData(
            message: null,
            preview: "No messages yet",
            isFromCurrentUser: false,
            unreadCount: 0,
          );
        }
        return;
      }

    final newLastMessagesData = await MessageService.getBatchLastMessages(
    _chatLinks, _chatChannelMap);

      if (mounted && newLastMessagesData.isNotEmpty) {
        setState(() {
          _lastMessagesData.addAll(newLastMessagesData);
        });

        // Update cache
        final currentCacheData = await CacheService.getCachedLastMessages();
        newLastMessagesData.forEach((chatId, lastMessageData) {
          currentCacheData[chatId] = {
            'preview': lastMessageData.preview,
            'isFromCurrentUser': lastMessageData.isFromCurrentUser,
            'unreadCount': lastMessageData.unreadCount,
            'timestamp': lastMessageData.timestamp?.toIso8601String(),
          };
        });
        await CacheService.saveLastMessages(currentCacheData);
      }
    } catch (e) {
      print('🔥 Error loading last messages for new chats: $e');
    }
  }

  /// ✅ NEW: Safe message preview with JSON fallback
String _getSafeMessagePreview(String content) {
  if (content.isEmpty) return "No messages yet";
  
  // Handle JSON content
  if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
    try {
      final jsonData = json.decode(content);
      if (jsonData is Map<String, dynamic>) {
        if (jsonData['msg'] != null) {
          final msg = jsonData['msg'].toString();
          if (msg.contains('Site.Inbox.UnmuteBot')) return "🔊 Bot unmuted";
          if (msg.contains('Site.Inbox.HasAsign')) return "👤 Assigned";
          if (msg.contains('Site.Inbox.MuteBot')) return "🔇 Bot muted";
          if (msg.contains('Site.Inbox')) return "⚙️ System message";
          return msg;
        }
        return 'Message';
      }
    } catch (e) {
      // If JSON parsing fails, return truncated content
      return content.length > 50 ? '${content.substring(0, 50)}...' : content;
    }
  }
  
  return content;
}

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _clearMessageCache();

    // ✅ ENHANCED: Enhanced cleanup dengan connection service
    _masterRealTimeTimer?.cancel();
    _lastMessageStreamController?.close();
    _connectionSubscription?.cancel();
    ConnectionService.dispose();
    super.dispose();
  }

  // ✅ ENHANCED: Real-time system dengan offline support
  void _initializeEnhancedRealTimeSystem() {
    print(
        '🔥 === INITIALIZING ENHANCED REAL-TIME SYSTEM WITH OFFLINE SUPPORT ===');

    // Create stream for last message updates
    _lastMessageStreamController =
        StreamController<Map<String, LastMessageData>>.broadcast();

    // Listen to stream for real-time UI updates
    _lastMessageStreamController?.stream.listen((updateBatch) {
      if (mounted && updateBatch.isNotEmpty) {
        print(
            '🔥 ⚡ Processing enhanced real-time batch: ${updateBatch.length} updates');

        setState(() {
          _lastMessagesData.addAll(updateBatch);
          _lastGlobalUpdate = DateTime.now();
        });

        // Update cache in background
        _updateCacheInBackground(updateBatch);

        print('🔥 ✅ Enhanced real-time UI updated successfully');
      }
    });

    _startEnhancedRealTimeMonitoring();
  }

  void _startEnhancedRealTimeMonitoring() {
    _masterRealTimeTimer?.cancel();

    _masterRealTimeTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted ||
          !_isRealTimeActive ||
          _isLoading ||
          _isLoadingChats ||
          _chatLinks.isEmpty) {
        return;
      }

      // Skip real-time updates in offline mode
      if (_isOfflineMode) {
        return;
      }

      await _performEnhancedRealTimeSync();
    });

    print('🔥 ✅ Enhanced real-time monitoring started with offline support');
  }

  /// ✅ ENHANCED: Real-time sync dengan offline awareness
  Future<void> _performEnhancedRealTimeSync() async {
    try {
      // Skip if offline
      if (_isOfflineMode) return;

      print('🔥 ⚡ === ENHANCED REAL-TIME SYNC START ===');

      const batchSize = 8;
      Map<String, LastMessageData> globalUpdateBatch = {};
      int actualUpdatesFound = 0;

      for (int i = 0; i < _chatLinks.length; i += batchSize) {
        final batch = _chatLinks.skip(i).take(batchSize).toList();

        final batchFutures =
            batch.map((chatLink) => _checkChatForLastMessageUpdate(chatLink));
        final batchResults = await Future.wait(batchFutures);

        for (int j = 0; j < batchResults.length; j++) {
          final update = batchResults[j];
          if (update != null) {
            globalUpdateBatch[batch[j].id] = update;
            actualUpdatesFound++;
          }
        }

        if (i + batchSize < _chatLinks.length) {
          await Future.delayed(const Duration(milliseconds: 30));
        }
      }

      print('🔥 ⚡ Enhanced sync complete: $actualUpdatesFound updates found');

      if (globalUpdateBatch.isNotEmpty &&
          _lastMessageStreamController != null) {
        _lastMessageStreamController!.add(globalUpdateBatch);
      }
    } catch (e) {
      print('🔥 ❌ Enhanced real-time sync error: $e');

      // If sync fails due to network, switch to offline mode
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        setState(() {
          _isOfflineMode = true;
          _isServerAvailable = false;
        });
      }
    }
  }

  /// ✅ ENHANCED: Update cache in background
  Future<void> _updateCacheInBackground(
      Map<String, LastMessageData> updates) async {
    try {
      final currentCacheData = await CacheService.getCachedLastMessages();

      updates.forEach((chatId, lastMessageData) {
        currentCacheData[chatId] = {
          'preview': lastMessageData.preview,
          'isFromCurrentUser': lastMessageData.isFromCurrentUser,
          'unreadCount': lastMessageData.unreadCount,
          'timestamp': lastMessageData.timestamp?.toIso8601String(),
        };
      });

      await CacheService.saveLastMessages(currentCacheData);
      print('🔥 💾 Cache updated with ${updates.length} real-time updates');
    } catch (e) {
      print('🔥 Error updating cache: $e');
    }
  }

  // ✅ ENHANCED: Check individual chat dengan timeout untuk offline handling
  Future<LastMessageData?> _checkChatForLastMessageUpdate(
      ChatLinkModel chatLink) async {
    try {
      final chatChannel = _chatChannelMap[chatLink.id];
      if (chatChannel == null) return null;

      final currentLastData = _lastMessagesData[chatLink.id];

      // Get last message with timeout
      final newLastMessageData = await MessageService.getLastMessageForChat(
        chatLink.id,
        chatChannel.id,
        chatLink.idExt.isNotEmpty ? chatLink.idExt : null,
      ).timeout(const Duration(seconds: 8));

      if (newLastMessageData == null) return null;

      // Check if there's an update
      bool hasUpdate = false;

      if (currentLastData == null) {
        hasUpdate = true;
      } else if (newLastMessageData.message != null &&
          currentLastData.message != null) {
        if (newLastMessageData.timestamp != null &&
            currentLastData.timestamp != null) {
          hasUpdate =
              newLastMessageData.timestamp!.isAfter(currentLastData.timestamp!);
        } else {
          hasUpdate =
              newLastMessageData.message!.id != currentLastData.message!.id;
        }
      } else if (newLastMessageData.message != null &&
          currentLastData.message == null) {
        hasUpdate = true;
      }

      if (hasUpdate) {
        print('🔥 ⚡ LAST MESSAGE UPDATE DETECTED in ${chatLink.name}:');
        print('🔥    New: "${newLastMessageData.preview}"');
        print('🔥    Unread: ${newLastMessageData.unreadCount}');
        return newLastMessageData;
      }

      return null;
    } on TimeoutException catch (e) {
      print('🔥 Timeout checking chat ${chatLink.name}: $e');
      return null;
    } catch (e) {
      print('🔥 Error checking chat ${chatLink.name} for updates: $e');
      return null;
    }
  }

  Future<void> _loadSavedFilter() async {
    try {
      final filter = await FilterService.loadFilter();
      setState(() {
        _currentFilter = filter;
      });
    } catch (e) {
      print('🔥 Error loading saved filter: $e');
    }
  }

  Future<void> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ??
        prefs.getString('username') ??
        'default_user';
    await _loadPinnedChats();
    await _loadArchivedChats();
  }

  Future<void> _loadPinnedChats() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final pinnedChats =
        prefs.getStringList('pinned_chats_$_currentUserId') ?? [];
    setState(() {
      _pinnedChatIds = pinnedChats.toSet();
    });
  }

  Future<void> _savePinnedChats() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'pinned_chats_$_currentUserId', _pinnedChatIds.toList());
  }

  Future<void> _loadArchivedChats() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final archivedChats =
        prefs.getStringList('archived_chats_$_currentUserId') ?? [];
    setState(() {
      _archivedChatIds = archivedChats.toSet();
    });
  }

  Future<void> _saveArchivedChats() async {
    if (_currentUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'archived_chats_$_currentUserId', _archivedChatIds.toList());
  }

  Future<void> _togglePin(String chatId) async {
    setState(() {
      if (_pinnedChatIds.contains(chatId)) {
        _pinnedChatIds.remove(chatId);
      } else {
        _pinnedChatIds.add(chatId);
      }
    });
    await _savePinnedChats();
  }

  Future<void> _archiveChat(String chatId) async {
    setState(() {
      _archivedChatIds.add(chatId);
    });
    await _saveArchivedChats();
    _showSuccessSnackBar('Chat archived');
  }

  Future<void> _unarchiveChat(String chatId) async {
    setState(() {
      _archivedChatIds.remove(chatId);
    });
    await _saveArchivedChats();
    _showSuccessSnackBar('Chat unarchived');
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

  Future<void> _togglePinForSelectedChats() async {
    bool allPinned =
        _selectedChatIds.every((chatId) => _pinnedChatIds.contains(chatId));

    if (allPinned) {
      for (String chatId in _selectedChatIds) {
        _pinnedChatIds.remove(chatId);
      }
      _showSuccessSnackBar('${_selectedChatIds.length} chat(s) unpinned');
    } else {
      for (String chatId in _selectedChatIds) {
        _pinnedChatIds.add(chatId);
      }
      _showSuccessSnackBar('${_selectedChatIds.length} chat(s) pinned');
    }

    await _savePinnedChats();
    _exitSelectionMode();
  }

  Future<void> _archiveSelectedChats() async {
    for (String chatId in _selectedChatIds) {
      _archivedChatIds.add(chatId);
    }
    await _saveArchivedChats();
    _showSuccessSnackBar('${_selectedChatIds.length} chat(s) archived');
    _exitSelectionMode();
  }

  bool get _areAllSelectedChatsPinned {
    if (_selectedChatIds.isEmpty) return false;
    return _selectedChatIds.every((chatId) => _pinnedChatIds.contains(chatId));
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  // ✅ ENHANCED: Pull-to-refresh dengan offline support
  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('🔥 === PULL-TO-REFRESH TRIGGERED ===');

      // Check connection first
      final isConnected = await ConnectionService.checkConnectionNow();

      if (isConnected) {
        print('🔥 Online - refreshing from server...');

        // Pause real-time updates during refresh
        final wasRealTimeActive = _isRealTimeActive;
        _isRealTimeActive = false;

        // Reset pagination
        _currentPage = 0;
        _hasMoreData = true;

        // Clear existing data
        _chatLinks.clear();
        _lastMessagesData.clear();
        _chatChannelMap.clear();

        // Reload all data from server
        await _loadDataFromServer();

        // Resume real-time updates
        _isRealTimeActive = wasRealTimeActive;
        if (_isRealTimeActive) {
          _startEnhancedRealTimeMonitoring();
        }

        if (mounted) {
          setState(() {
            _isOfflineMode = false;
            _isServerAvailable = true;
          });
        }

        print('🔥 ✅ Server refresh completed');
        _showSuccessSnackBar('✅ Data refreshed from server!');
      } else {
        print('🔥 Offline - refreshing from cache...');

        // Load from cache only
        await _loadDataFromCacheOnly();

        if (mounted) {
          setState(() {
            _isOfflineMode = true;
            _isServerAvailable = false;
          });
        }

        print('🔥 ✅ Cache refresh completed');
        _showSuccessSnackBar('📱 Data refreshed from cache (offline mode)');
      }
    } catch (e) {
      print('🔥 ❌ Pull-to-refresh error: $e');
      _showErrorSnackBar('Failed to refresh: $e');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  /// ✅ ENHANCED: Filtered chats dengan proper last message data
  List<ChatLinkModel> get _filteredChats {
    List<ChatLinkModel> filtered = _chatLinks;

    // Apply comprehensive filtering
    final unreadCounts = Map<String, int>.fromEntries(_lastMessagesData.entries
        .map((e) => MapEntry(e.key, e.value.unreadCount)));

    filtered = FilterService.applyFilter(
      filtered,
      _currentFilter,
      unreadCounts,
      _chatChannelMap,
      _contacts,
      archivedChatIds: _archivedChatIds,
    );

    // Apply search query filtering
    if (_searchQuery.isNotEmpty) {
      final lastMessageContent = Map<String, String>.fromEntries(
          _lastMessagesData.entries
              .map((e) => MapEntry(e.key, e.value.preview)));

      filtered = filtered.where((chat) {
        return FilterService.matchesSearchQuery(
            chat, _searchQuery, lastMessageContent);
      }).toList();
    }

    // Apply tab filtering
    switch (_selectedFilterIndex) {
      case 1: // Unassigned
        filtered = filtered.where((chat) {
          final lastData = _lastMessagesData[chat.id];
          return lastData != null && lastData.unreadCount > 0;
        }).toList();
        break;
      case 2: // Assigned
        filtered = filtered.where((chat) {
          final lastData = _lastMessagesData[chat.id];
          return lastData == null || lastData.unreadCount == 0;
        }).toList();
        break;
      case 3: // Resolved
        break;
      default: // All
        break;
    }

    // Sort with proper last message time
    filtered.sort((a, b) {
      final aPinned = _pinnedChatIds.contains(a.id);
      final bPinned = _pinnedChatIds.contains(b.id);

      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;

      final aTime = _lastMessagesData[a.id]?.timestamp ?? DateTime(1970);
      final bTime = _lastMessagesData[b.id]?.timestamp ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  Future<void> _initializeData() async {
    // ✅ ENHANCED: Redirect to enhanced app initialization
    await _initializeEnhancedApp();
  }

  void _clearMessageCache() {
    _loadedChats.clear();
    _lastLoadTime.clear();
    _lastMessagesData.clear();
    _masterRealTimeTimer?.cancel();
  }

  void _showFilterDialog() async {
    final result = await showDialog<ConversationFilter>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return FilterConversationDialog(
          currentFilter: _currentFilter,
          channels: _channels,
          accounts: _accounts,
          contacts: _contacts,
          chatLinks: _chatLinks,
          onApplyFilter: (ConversationFilter newFilter) {
            setState(() {
              _currentFilter = newFilter;
            });
            FilterService.saveFilter(newFilter);
          },
        );
      },
    );
  }

  void _clearAllFilters() async {
    setState(() {
      _currentFilter = ConversationFilter();
    });
    await FilterService.clearFilter();
    _showSuccessSnackBar('All filters cleared');
  }

  /// ✅ ENHANCED: Logout dengan cache management
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    final allKeys = prefs
        .getKeys()
        .where((k) =>
            k.startsWith('pinned_chats_') || k.startsWith('archived_chats_'))
        .toList();
    final backup = {for (var k in allKeys) k: prefs.getStringList(k)};

    // Clear auth data but keep cache
    await prefs.remove('auth_token');
    await prefs.remove('username');

    // Clear user session from cache service
    await CacheService.clearUserSession();

    // Restore chat-related data
    for (var entry in backup.entries) {
      await prefs.setStringList(entry.key, entry.value ?? []);
    }

    ApiService.logout();

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
        (route) => false,
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: primaryBlue,
          duration: const Duration(seconds: 2),
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
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _navigateToArchive() async {
    final archivedChats =
        _chatLinks.where((chat) => _archivedChatIds.contains(chat.id)).toList();
    final archivedLastMessages = Map<String, NoboxMessage>.fromEntries(
        _lastMessagesData.entries
            .where((e) => e.value.message != null)
            .map((e) => MapEntry(e.key, e.value.message!)));
    final archivedUnreadCounts = Map<String, int>.fromEntries(_lastMessagesData
        .entries
        .map((e) => MapEntry(e.key, e.value.unreadCount)));

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArsipContactScreen(
          chatLinks: archivedChats,
          chatChannelMap: _chatChannelMap,
          lastMessages: archivedLastMessages,
          unreadCounts: archivedUnreadCounts,
          onUnarchive: _unarchiveChat,
        ),
      ),
    );

    if (result == true) {
      setState(() {});
    }
  }

  /// ✅ ENHANCED: Show new conversation dialog (works offline untuk create manual conversation)
  void _showNewConversationDialog() async {
    if (_isOfflineMode) {
      _showErrorSnackBar('❌ New conversations require internet connection');
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return NewConversationDialog(
          channels: _channels,
          accounts: _accounts,
          contacts: _contacts,
          onConversationCreated: _handleNewConversation,
        );
      },
    );
  }

  /// ✅ ENHANCED: Handle new conversation creation dengan cache update
  void _handleNewConversation(Map<String, dynamic> conversationData) async {
    print('🔥 New conversation created: $conversationData');

    try {
      _showSuccessSnackBar('✅ New conversation created successfully!');

      if (!_isOfflineMode) {
        // Refresh data in background for server sync
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _initializeData();
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to update conversation list: $e');
    }
  }

  /// ✅ ENHANCED: Navigation dengan offline awareness
  void _navigateToChatRoom(ChatLinkModel chatLink) async {
    if (_isSelectionMode) {
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

    // Mark chat as read when entering
    if (mounted) {
      setState(() {
        final lastData = _lastMessagesData[chatLink.id];
        if (lastData != null) {
          _lastMessagesData[chatLink.id] = LastMessageData(
            message: lastData.message,
            preview: lastData.preview,
            isFromCurrentUser: lastData.isFromCurrentUser,
            unreadCount: 0,
            timestamp: lastData.timestamp,
          );
        }
      });

      if (!_isOfflineMode) {
        _showSuccessSnackBar('Chat assigned and marked as read');
      } else {
        _showSuccessSnackBar('📱 Chat opened (offline mode)');
      }
    }

    final chatChannel = _chatChannelMap[chatLink.id] ?? _selectedChannel;

    if (chatChannel == null) {
      _showErrorSnackBar('Channel not found for this chat');
      return;
    }

    print('🔥 ⚡ Pausing enhanced real-time system for chat navigation');
    _isRealTimeActive = false;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatLink: chatLink,
          channel: chatChannel,
          accounts: _accounts,
        ),
      ),
    );

    print('🔥 ⚡ Resuming enhanced real-time system after chat navigation');
    _isRealTimeActive = true;

    if (result != null && !_isOfflineMode) {
      print('🔥 ⚡ Force refresh after returning from chat...');
      final updatedData = await MessageService.getLastMessageForChat(
        chatLink.id,
        chatChannel.id,
        chatLink.idExt.isNotEmpty ? chatLink.idExt : null,
      );

      if (updatedData != null && _lastMessageStreamController != null) {
        _lastMessageStreamController!.add({chatLink.id: updatedData});
      }
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final messageTime = dateTime;
    final difference = now.difference(messageTime);

    if (difference.inDays == 0 &&
        now.day == messageTime.day &&
        now.month == messageTime.month &&
        now.year == messageTime.year) {
      return '${messageTime.hour.toString().padLeft(2, '0')}.${messageTime.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate =
        DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate.isAtSameMomentAs(yesterday) ||
        (difference.inHours >= 24 && difference.inHours < 48)) {
      return 'Yesterday';
    }

    if (difference.inDays >= 2 || difference.inHours >= 48) {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }

    return '${messageTime.hour.toString().padLeft(2, '0')}.${messageTime.minute.toString().padLeft(2, '0')}';
  }

  // ✅ ENHANCED: Chat tile dengan offline indicators dan PERFECT last message display
  Widget _buildChatTile(ChatLinkModel chatLink) {
    final lastData = _lastMessagesData[chatLink.id];
    final hasUnread = (lastData?.unreadCount ?? 0) > 0;
    final chatChannel = _chatChannelMap[chatLink.id];
    final isPinned = _pinnedChatIds.contains(chatLink.id);
    final isSelected = _selectedChatIds.contains(chatLink.id);

    // Get last message content dengan ikon yang tepat
    final lastMessageContent = lastData?.preview ?? "No messages yet";
    final lastMessageTime = lastData?.timestamp ??
        DateTime.now()
            .subtract(Duration(minutes: (chatLink.id.hashCode % 1440).abs()));
    final isAgentLast = lastData?.isFromCurrentUser ?? false;
    final unreadCount = lastData?.unreadCount ?? 0;

    // Real-time update indicator (only show when online)
    final hasRecentUpdate = !_isOfflineMode &&
        _lastGlobalUpdate != null &&
        lastData?.timestamp != null &&
        DateTime.now().difference(_lastGlobalUpdate!).inSeconds < 5;

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
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14), // Slightly increased from 12
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

              // Avatar with offline indicator - Slightly larger
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Stack(
                  children: [
                    Container(
                      width: 50, // Increased from 48 to 50
                      height: 50, // Increased from 48 to 50
                      decoration: BoxDecoration(
                        color: _isOfflineMode
                            ? Colors.grey[400]
                            : const Color(0xFFD3D3D3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        chatLink.name.toLowerCase().contains('grup') ||
                                chatLink.name.toLowerCase().contains('group') ||
                                chatLink.name
                                    .toLowerCase()
                                    .contains('orang-orang')
                            ? Icons.group
                            : Icons.person,
                        color: Colors.white,
                        size: 31, // Increased from 28 to 31
                      ),
                    ),
                    // Offline indicator
                    if (_isOfflineMode)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 13), // Increased from 12 to 13

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and time row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Contact name with offline styling
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chatLink.name.isNotEmpty
                                      ? chatLink.name
                                      : 'Chat ${chatLink.id}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16.5, // Increased from 16 to 16.5
                                    color: _isOfflineMode
                                        ? Colors.grey[600]
                                        : textPrimary,
                                    fontFamily: 'Poppins',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Offline badge untuk individual chat (hanya jika offline)
                              if (_isOfflineMode) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.red[300]!, width: 0.5),
                                  ),
                                  child: Text(
                                    'OFFLINE',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Time, pin icon, and real-time indicators
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Time
                            Text(
                              _formatTime(lastMessageTime),
                              style: TextStyle(
                                color: _isOfflineMode
                                    ? Colors.grey[400]
                                    : textSecondary,
                                fontSize: 12.5, // Increased from 12 to 12.5
                                fontFamily: 'Poppins',
                              ),
                            ),
                            // Pin icon
                            if (isPinned) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.push_pin,
                                size: 17, // Increased from 16 to 17
                                color: _isOfflineMode
                                    ? Colors.grey[400]
                                    : primaryBlue,
                              ),
                            ],
                            // Real-time update indicator (only when online)
                            if (hasRecentUpdate) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 9, // Increased from 8 to 9
                                height: 9, // Increased from 8 to 9
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5), // Increased from 4 to 5

                    // Last message dengan ikon yang SEMPURNA dan offline styling
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13.5, // Increased from 13 to 13.5
                                fontFamily: 'Poppins',
                                // PERFECT COLOR LOGIC with offline awareness:
                                color: _isOfflineMode
                                    ? Colors.grey[500]
                                    : (hasUnread && !isAgentLast)
                                        ? redMessage // Red untuk unread contact messages
                                        : textSecondary, // Gray untuk agent messages atau read messages
                                fontWeight: (hasUnread &&
                                        !isAgentLast &&
                                        !_isOfflineMode)
                                    ? FontWeight
                                        .w500 // Bold untuk unread contact messages
                                    : FontWeight.normal,
                              ),
                              children:
                                  _buildLastMessageSpans(lastMessageContent),
                            ),
                          ),
                        ),

                        const SizedBox(width: 9), // Increased from 8 to 9

                        // Badge area - unread count atau assigned badge dengan offline styling
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tampilkan unread count ATAU assigned badge di posisi yang sama
                            if (hasUnread && !_isOfflineMode)
                              // Jika ada unread dan online, tampilkan unread count badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.5,
                                    vertical:
                                        2.5), // Slightly increased padding
                                decoration: BoxDecoration(
                                  color: unreadBadge,
                                  borderRadius: BorderRadius.circular(
                                      11), // Increased from 10 to 11
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5, // Increased from 11 to 11.5
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              )
                            else
                              // Jika tidak ada unread atau offline, tampilkan assigned/cached badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9.5,
                                    vertical: 3), // Slightly reduced padding
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: _isOfflineMode
                                          ? Colors.grey[400]!
                                          : primaryBlue,
                                      width: 1.5),
                                  borderRadius: BorderRadius.circular(
                                      6), // Reduced from 12 to 6
                                ),
                                child: Text(
                                  _isOfflineMode ? 'CACHED' : 'Assigned',
                                  style: TextStyle(
                                    color: _isOfflineMode
                                        ? Colors.grey[600]
                                        : primaryBlue,
                                    fontSize: 9, // Reduced from 9.5 to 9
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

/// ✅ ENHANCED: Build text spans untuk last message dengan ikon yang tepat dan offline awareness
List<TextSpan> _buildLastMessageSpans(String content) {
  final List<TextSpan> spans = [];
  final Color iconColor = _isOfflineMode ? Colors.grey[500]! : Colors.grey[700]!;

  final String displayContent = _getSafeMessagePreview(content);

  // ✅ PERFECT: Detect dan render ikon dengan warna yang tepat
  final lowerContent = displayContent.toLowerCase();
  
  if (lowerContent.contains('image') || lowerContent.contains('photo') || lowerContent.contains('gambar') || lowerContent.contains('foto')) {
    // Photo message
    spans.add(TextSpan(
      text: '📷 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Photo',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.green[600],
      ),
    ));
  } else if (lowerContent.contains('video') || lowerContent.contains('vidio')) {
    // Video message
    spans.add(TextSpan(
      text: '📽 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Video',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.purple[600],
      ),
    ));
  } else if (lowerContent.contains('audio') || lowerContent.contains('suara') || lowerContent.contains('voice')) {
    // Audio message
    spans.add(TextSpan(
      text: '🔉 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Audio',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.orange[600],
      ),
    ));
  } else if (lowerContent.contains('document') || lowerContent.contains('dokumen') || lowerContent.contains('file')) {
    // Document message
    spans.add(TextSpan(
      text: '📂 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Document',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.blue[600],
      ),
    ));
  } else if (lowerContent.contains('location') || lowerContent.contains('lokasi')) {
    // Location message
    spans.add(TextSpan(
      text: '📍 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Location',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.red[600],
      ),
    ));
  } else if (lowerContent.contains('sticker')) {
    // Sticker message
    spans.add(TextSpan(
      text: '🎭 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Sticker',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.pink[600],
      ),
    ));
  } else if (displayContent.startsWith('{') && displayContent.endsWith('}')) {
    // Fallback untuk JSON yang tidak terdeteksi sebagai JSON sebelumnya
    spans.add(TextSpan(
      text: '📄 ',
      style: TextStyle(fontSize: 14),
    ));
    spans.add(TextSpan(
      text: 'Message',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: _isOfflineMode ? Colors.grey[500] : Colors.grey[700],
      ),
    ));
  } else {
    // Regular text message - potong jika terlalu panjang
    final displayText = displayContent.length > 80 
      ? '${displayContent.substring(0, 80)}...' 
      : displayContent;
    spans.add(TextSpan(text: displayText));
  }

  return spans;
}

/// ✅ NEW: Check if content is JSON
bool _isJsonContent(String content) {
  final trimmed = content.trim();
  return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
         (trimmed.startsWith('[') && trimmed.endsWith(']'));
}

/// ✅ NEW: Extract text from JSON content
String _extractTextFromJson(String jsonContent) {
  try {
    final jsonData = json.decode(jsonContent);
    
    // Check for common message fields in JSON
    if (jsonData is Map<String, dynamic>) {
      // Try to extract text from various possible fields
      if (jsonData['text'] != null) {
        return jsonData['text'].toString();
      } else if (jsonData['message'] != null) {
        return jsonData['message'].toString();
      } else if (jsonData['content'] != null) {
        return jsonData['content'].toString();
      } else if (jsonData['body'] != null) {
        return jsonData['body'].toString();
      } else if (jsonData['msg'] != null) {
        return jsonData['msg'].toString();
      } else if (jsonData['Message'] != null) {
        return jsonData['Message'].toString();
      } else if (jsonData['Content'] != null) {
        return jsonData['Content'].toString();
      }
      
      // Check for specific system messages
      if (jsonData['msg'] != null && jsonData['msg'].toString().contains('Site.Inbox')) {
        return _parseSystemMessage(jsonData['msg'].toString());
      }
    }
    
    // If no specific fields found, return a generic message
    return 'Message';
  } catch (e) {
    // If JSON parsing fails, return truncated content
    return jsonContent.length > 50 
      ? '${jsonContent.substring(0, 50)}...' 
      : jsonContent;
  }
}

/// ✅ NEW: Parse system messages
String _parseSystemMessage(String systemMsg) {
  if (systemMsg.contains('Site.Inbox.UnmuteBot')) {
    return 'Bot unmuted';
  } else if (systemMsg.contains('Site.Inbox.HasAsign')) {
    return 'Conversation assigned';
  } else if (systemMsg.contains('Site.Inbox.MuteBot')) {
    return 'Bot muted';
  } else if (systemMsg.contains('Site.Inbox')) {
    return 'System message';
  }
  return systemMsg;
}

  int _getTotalUnassignedCount() {
    if (_isOfflineMode) return 0; // Don't show unread count in offline mode

    return _chatLinks.where((chat) {
      if (_archivedChatIds.contains(chat.id)) return false;
      final lastData = _lastMessagesData[chat.id];
      return lastData != null && lastData.unreadCount > 0;
    }).length;
  }

  int _getArchivedCount() {
    return _archivedChatIds.length;
  }

  /// ✅ ENHANCED: App bar dengan offline indicators
  Widget _buildAppBar() {
    if (_isSelectionMode) {
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
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white, size: 24),
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
                onPressed: _selectedChatIds.isNotEmpty
                    ? _togglePinForSelectedChats
                    : null,
                icon: Icon(
                    _areAllSelectedChatsPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    color: Colors.white,
                    size: 24),
              ),
              IconButton(
                onPressed:
                    _selectedChatIds.isNotEmpty ? _archiveSelectedChats : null,
                icon: const Icon(Icons.archive, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      );
    } else if (_isSearchMode) {
      // Search mode UI
      return Container(
        color: primaryBlue,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        child: SizedBox(
          height: 60,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Search conversation or contact',
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                  fontStyle: FontStyle.normal,
                ),
                border: InputBorder.none,
                isDense: true,
                prefixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearchMode = false;
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.black, size: 24),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(Icons.clear, color: Colors.grey),
                      )
                    : null,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontFamily: 'Poppins',
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
    } else {
      // Normal mode UI dengan offline indicators
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
              const SizedBox(width: 12),
              Image.asset(
                'assets/nobox.png',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),

              // Title dengan offline indicator
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NoBoxChat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (_isOfflineMode) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white.withOpacity(0.8),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Offline Mode',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Compact icon group dengan offline status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Connection status indicator
                  // Column(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     Container(
                  //       width: 8,
                  //       height: 8,
                  //       decoration: BoxDecoration(
                  //         color: _isOfflineMode
                  //             ? Colors.red
                  //             : _isRealTimeActive
                  //                 ? Colors.green
                  //                 : Colors.orange,
                  //         shape: BoxShape.circle,
                  //       ),
                  //     ),
                  //     const SizedBox(height: 2),
                  //     Text(
                  //       _isOfflineMode
                  //           ? 'OFFLINE'
                  //           : _isRealTimeActive
                  //               ? 'LIVE'
                  //               : 'PAUSED',
                  //       style: TextStyle(
                  //         color: Colors.white.withOpacity(0.8),
                  //         fontSize: 8,
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //   ],
                  // ),

                  // Search icon
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isSearchMode = true;
                      });
                    },
                    icon:
                        const Icon(Icons.search, color: Colors.white, size: 27),
                    padding: EdgeInsets.all(8),
                  ),

                  // Filter icon
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: _showFilterDialog,
                        icon: const Icon(Icons.filter_alt,
                            color: Colors.white, size: 27),
                        padding: EdgeInsets.all(8),
                      ),
                      if (_currentFilter.hasActiveFilters)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _currentFilter.activeFilterCount > 9
                                    ? '9+'
                                    : _currentFilter.activeFilterCount
                                        .toString(),
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // More menu dengan offline options
              PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_vert, color: Colors.white, size: 27),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) async {
                  switch (value) {
                    case 'refresh':
                      _initializeData();
                      break;
                    case 'sync':
                      if (!_isOfflineMode) {
                        await _syncDataFromServer();
                      } else {
                        _showErrorSnackBar(
                            '❌ Sync requires internet connection');
                      }
                      break;
                    case 'realtime':
                      if (!_isOfflineMode) {
                        setState(() {
                          _isRealTimeActive = !_isRealTimeActive;
                        });
                        if (_isRealTimeActive) {
                          _startEnhancedRealTimeMonitoring();
                          _showSuccessSnackBar('✅ Real-time updates enabled');
                        } else {
                          _masterRealTimeTimer?.cancel();
                          _showSuccessSnackBar('⏸️ Real-time updates paused');
                        }
                      } else {
                        _showErrorSnackBar(
                            '❌ Real-time updates require internet connection');
                      }
                      break;
                    case 'cache_info':
                      _showCacheInfoDialog();
                      break;
                    case 'clear_cache':
                      _showClearCacheDialog();
                      break;
                    case 'logout':
                      _logout();
                      break;
                  }
                },
                itemBuilder: (context) => [
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
                  if (!_isOfflineMode)
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, color: textPrimary),
                          SizedBox(width: 12),
                          Text('Sync Now'),
                        ],
                      ),
                    ),
                  if (!_isOfflineMode)
                    PopupMenuItem(
                      value: 'realtime',
                      child: Row(
                        children: [
                          Icon(
                              _isRealTimeActive
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: textPrimary),
                          const SizedBox(width: 12),
                          Text(_isRealTimeActive
                              ? 'Pause Real-time'
                              : 'Resume Real-time'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'cache_info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: textPrimary),
                        SizedBox(width: 12),
                        Text('Cache Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_cache',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, color: Colors.orange),
                        SizedBox(width: 12),
                        Text('Clear Cache',
                            style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                padding: EdgeInsets.all(8),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    }
  }

  /// ✅ NEW: Show cache info dialog
  void _showCacheInfoDialog() async {
    final cacheStatus = await CacheService.getCacheStatus();
    final lastCacheTime = await CacheService.getLastCacheTime();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Status: ${_isOfflineMode ? 'Offline Mode' : 'Online'}'),
              const SizedBox(height: 8),
              Text('Server Available: ${_isServerAvailable ? 'Yes' : 'No'}'),
              const SizedBox(height: 8),
              Text(
                  'Has Cached Data: ${cacheStatus['hasCachedData'] ? 'Yes' : 'No'}'),
              const SizedBox(height: 8),
              if (lastCacheTime != null) ...[
                Text('Last Update: ${_formatTime(lastCacheTime)}'),
                const SizedBox(height: 8),
                Text('Cache Age: ${cacheStatus['cacheAge']} minutes'),
                const SizedBox(height: 8),
              ],
              const Divider(),
              const Text('Cached Data:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('• Chat Links: ${cacheStatus['chatLinks'] ? 'Yes' : 'No'}'),
              Text('• Channels: ${cacheStatus['channels'] ? 'Yes' : 'No'}'),
              Text('• Accounts: ${cacheStatus['accounts'] ? 'Yes' : 'No'}'),
              Text('• Contacts: ${cacheStatus['contacts'] ? 'Yes' : 'No'}'),
              Text(
                  '• Last Messages: ${cacheStatus['lastMessages'] ? 'Yes' : 'No'}'),
              const SizedBox(height: 8),
              const Divider(),
              Text('Total Chats: ${_chatLinks.length}'),
              Text('Total Channels: ${_channels.length}'),
              Text('Total Contacts: ${_contacts.length}'),
              if (_lastSuccessfulUpdate != null) ...[
                const SizedBox(height: 8),
                Text('Last Server Sync: ${_formatTime(_lastSuccessfulUpdate)}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Show clear cache confirmation dialog
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This will clear all cached data. You will need to reconnect to the internet to reload data.\n\nAre you sure you want to continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                await CacheService.clearCache();

                setState(() {
                  _chatLinks.clear();
                  _channels.clear();
                  _accounts.clear();
                  _contacts.clear();
                  _lastMessagesData.clear();
                  _debugInfo = 'Cache cleared';
                });

                _showSuccessSnackBar('✅ Cache cleared successfully');

                // Try to reload from server if online
                if (!_isOfflineMode) {
                  _initializeData();
                }
              } catch (e) {
                _showErrorSnackBar('Failed to clear cache: $e');
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// ✅ NEW: Build offline banner seperti di gambar
  Widget _buildOfflineBanner() {
    if (!_isOfflineMode) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFFFEBEE), // Light red background
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            color: Colors.red[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "You're offline. Showing cached data.",
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Try to reconnect and sync
              final isConnected = await ConnectionService.checkConnectionNow();
              if (isConnected) {
                _syncDataFromServer();
              } else {
                _showErrorSnackBar(
                    'Still offline. Check your internet connection.');
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveSection() {
    final archivedCount = _getArchivedCount();

    if (archivedCount == 0) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          InkWell(
            onTap: _navigateToArchive,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon archive sejajar dengan avatar profil tanpa container lebar
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
                    child: Icon(
                      Icons.archive_outlined,
                      color: _isOfflineMode ? Colors.grey[400] : primaryBlue,
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Archived Conversation',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _isOfflineMode
                                ? Colors.grey[600]
                                : Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$archivedCount conversation${archivedCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _isOfflineMode ? Colors.grey[400] : Colors.grey,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.keyboard_arrow_right,
                    color: _isOfflineMode ? Colors.grey[400] : Colors.grey,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoadingMore) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                  _isOfflineMode ? Colors.grey : primaryBlue),
              strokeWidth: 2,
            ),
            const SizedBox(height: 8),
            Text(
              _isOfflineMode
                  ? 'Loading from cache...'
                  : 'Loading more conversations...',
              style: TextStyle(
                fontSize: 12,
                color: _isOfflineMode ? Colors.grey[400] : textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndOfListIndicator() {
    if (_hasMoreData || _isLoadingMore || _filteredChats.length < _pageSize) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              color: _isOfflineMode ? Colors.grey[400] : Colors.green[400],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              _isOfflineMode
                  ? 'All cached conversations loaded'
                  : 'All conversations loaded',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _isOfflineMode ? Colors.grey[400] : textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_chatLinks.length} total conversations',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _isOfflineMode ? Colors.grey[400] : textSecondary,
              ),
            ),
            if (_isOfflineMode) ...[
              const SizedBox(height: 4),
              Text(
                '(Offline Mode)',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.red[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredChats = _filteredChats;
    final totalUnassignedCount = _getTotalUnassignedCount();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildAppBar(),

          // Filter chip widget
          FilterChipWidget(
            filter: _currentFilter,
            onTap: _showFilterDialog,
            onClear: _clearAllFilters,
          ),

          // ✅ NEW: Offline banner sesuai gambar (ditambahkan di sini)
          _buildOfflineBanner(),

          // Filter tabs dengan offline indicators
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                for (int i = 0; i < _filterTabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilterIndex = i;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 36,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Text yang selalu tampil penuh dengan ukuran yang fleksibel
                                Flexible(
                                  child: Text(
                                    _filterTabs[i],
                                    style: TextStyle(
                                      // ✅ ENHANCED: Color dengan offline awareness
                                      color: _isOfflineMode
                                          ? Colors.grey[500]
                                          : textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // Badge untuk Unassigned dengan offline awareness
                                if (i == 1 && totalUnassignedCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    constraints: BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _isOfflineMode
                                          ? Colors.grey[400]
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      totalUnassignedCount > 99
                                          ? '99+'
                                          : totalUnassignedCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Underline indicator dengan offline styling
                          Container(
                            height: 3,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _selectedFilterIndex == i
                                  ? (_isOfflineMode
                                      ? Colors.grey[400]
                                      : primaryBlue)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ✅ ENHANCED: RefreshIndicator dengan offline support
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              _isOfflineMode ? Colors.grey : primaryBlue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isOfflineMode
                              ? 'Loading from cache...'
                              : 'Loading data...',
                          style: TextStyle(
                            color: _isOfflineMode
                                ? Colors.grey[600]
                                : textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : filteredChats.isEmpty && _getArchivedCount() == 0
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isOfflineMode
                                  ? Icons.wifi_off
                                  : Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isOfflineMode
                                  ? 'No cached data available'
                                  : _searchQuery.isNotEmpty
                                      ? 'No chats found for "$_searchQuery"'
                                      : _currentFilter.hasActiveFilters
                                          ? 'No conversations match the current filters'
                                          : 'No conversations found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (_isOfflineMode) ...[
                              Text(
                                'Connect to internet and refresh to load data',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else if (_currentFilter.hasActiveFilters) ...[
                              TextButton(
                                onPressed: _clearAllFilters,
                                child: Text(
                                  'Clear all filters',
                                  style: GoogleFonts.poppins(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _initializeData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isOfflineMode
                                    ? Colors.grey[400]
                                    : primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                _isOfflineMode ? 'Refresh Cache' : 'Refresh',
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        // ✅ ENHANCED: Pull-to-refresh dengan offline support
                        onRefresh: _onRefresh,
                        color: _isOfflineMode ? Colors.grey : primaryBlue,
                        backgroundColor: Colors.white,
                        strokeWidth: 2.5,
                        displacement: 40,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: EdgeInsets.zero,
                          physics:
                              const AlwaysScrollableScrollPhysics(), // ✅ CRITICAL: Enable pull-to-refresh even when list is short
                          itemCount: (_getArchivedCount() > 0 ? 1 : 0) +
                              filteredChats.length +
                              (_isLoadingMore ? 1 : 0) +
                              (!_hasMoreData ? 1 : 0),
                          // Separator dengan offline styling
                          separatorBuilder: (context, index) {
                            // Hanya menampilkan separator untuk archive section, bukan untuk chat tiles
                            if (index == 0 && _getArchivedCount() > 0) {
                              return const SizedBox
                                  .shrink(); // Tidak ada separator setelah archive
                            }
                            // Semua chat tiles tidak memiliki separator
                            return const SizedBox.shrink();
                          },
                          itemBuilder: (context, index) {
                            // ✅ ENHANCED: Archive section dengan offline styling
                            if (index == 0 && _getArchivedCount() > 0) {
                              return _buildArchiveSection();
                            }

                            final chatIndex =
                                _getArchivedCount() > 0 ? index - 1 : index;

                            // ✅ ENHANCED: Chat tiles dengan offline indicators
                            if (chatIndex >= 0 &&
                                chatIndex < filteredChats.length) {
                              return _buildChatTile(filteredChats[chatIndex]);
                            }

                            // Loading more indicator dengan offline styling
                            if (chatIndex == filteredChats.length &&
                                _isLoadingMore) {
                              return _buildLoadingIndicator();
                            }

                            // End of list indicator dengan offline styling
                            if (chatIndex == filteredChats.length &&
                                !_hasMoreData) {
                              return _buildEndOfListIndicator();
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 20, right: 10),
        child: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            onPressed: _showNewConversationDialog,
            backgroundColor: _isOfflineMode ? Colors.grey[400] : primaryBlue,
            foregroundColor: Colors.white,
            elevation: _isOfflineMode ? 2 : 6,
            child: const Icon(
              Icons.add,
              size: 30,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
