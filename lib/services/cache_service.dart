import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import 'api_service.dart';

/// Service untuk handle persistent storage dan offline capabilities
class CacheService {
  static const String _keyPrefix = 'nobox_cache_';
  static const String _keyChatLinks = '${_keyPrefix}chat_links';
  static const String _keyChannels = '${_keyPrefix}channels';
  static const String _keyAccounts = '${_keyPrefix}accounts';
  static const String _keyContacts = '${_keyPrefix}contacts';
  static const String _keyLastMessages = '${_keyPrefix}last_messages';
  static const String _keyLastUpdate = '${_keyPrefix}last_update';
  static const String _keyUserSession = '${_keyPrefix}user_session';
  static const String _keyOfflineMode = '${_keyPrefix}offline_mode';

  /// ✅ CACHE CHAT LINKS
  static Future<void> saveChatLinks(List<ChatLinkModel> chatLinks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = chatLinks.map((link) => {
        'Id': link.id,
        'IdExt': link.idExt,
        'Name': link.name,
      }).toList();
      
      await prefs.setString(_keyChatLinks, jsonEncode(jsonList));
      await _updateLastCacheTime();
      print('🔥 💾 Cached ${chatLinks.length} chat links');
    } catch (e) {
      print('🔥 Error saving chat links to cache: $e');
    }
  }

  static Future<List<ChatLinkModel>> getCachedChatLinks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyChatLinks);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final chatLinks = jsonList.map((json) => ChatLinkModel.fromJson(json)).toList();
        print('🔥 📱 Loaded ${chatLinks.length} cached chat links');
        return chatLinks;
      }
    } catch (e) {
      print('🔥 Error loading cached chat links: $e');
    }
    return [];
  }

  /// ✅ CACHE CHANNELS
  static Future<void> saveChannels(List<ChannelModel> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = channels.map((channel) => {
        'Id': channel.id,
        'Nm': channel.name,
      }).toList();
      
      await prefs.setString(_keyChannels, jsonEncode(jsonList));
      await _updateLastCacheTime();
      print('🔥 💾 Cached ${channels.length} channels');
    } catch (e) {
      print('🔥 Error saving channels to cache: $e');
    }
  }

  static Future<List<ChannelModel>> getCachedChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyChannels);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final channels = jsonList.map((json) => ChannelModel.fromJson(json)).toList();
        print('🔥 📱 Loaded ${channels.length} cached channels');
        return channels;
      }
    } catch (e) {
      print('🔥 Error loading cached channels: $e');
    }
    return [];
  }

  /// ✅ CACHE ACCOUNTS
  static Future<void> saveAccounts(List<AccountModel> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = accounts.map((account) => {
        'Id': account.id,
        'Name': account.name,
        'Channel': account.channel,
      }).toList();
      
      await prefs.setString(_keyAccounts, jsonEncode(jsonList));
      await _updateLastCacheTime();
      print('🔥 💾 Cached ${accounts.length} accounts');
    } catch (e) {
      print('🔥 Error saving accounts to cache: $e');
    }
  }

  static Future<List<AccountModel>> getCachedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyAccounts);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final accounts = jsonList.map((json) => AccountModel.fromJson(json)).toList();
        print('🔥 📱 Loaded ${accounts.length} cached accounts');
        return accounts;
      }
    } catch (e) {
      print('🔥 Error loading cached accounts: $e');
    }
    return [];
  }

  /// ✅ CACHE CONTACTS
  static Future<void> saveContacts(List<ContactModel> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = contacts.map((contact) => {
        'Id': contact.id,
        'Name': contact.name,
      }).toList();
      
      await prefs.setString(_keyContacts, jsonEncode(jsonList));
      await _updateLastCacheTime();
      print('🔥 💾 Cached ${contacts.length} contacts');
    } catch (e) {
      print('🔥 Error saving contacts to cache: $e');
    }
  }

  static Future<List<ContactModel>> getCachedContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyContacts);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final contacts = jsonList.map((json) => ContactModel.fromJson(json)).toList();
        print('🔥 📱 Loaded ${contacts.length} cached contacts');
        return contacts;
      }
    } catch (e) {
      print('🔥 Error loading cached contacts: $e');
    }
    return [];
  }

  /// ✅ CACHE LAST MESSAGES DATA
  static Future<void> saveLastMessages(Map<String, dynamic> lastMessagesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastMessages, jsonEncode(lastMessagesData));
      await _updateLastCacheTime();
      print('🔥 💾 Cached ${lastMessagesData.length} last messages');
    } catch (e) {
      print('🔥 Error saving last messages to cache: $e');
    }
  }

  static Future<Map<String, dynamic>> getCachedLastMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyLastMessages);
      
      if (jsonString != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(jsonDecode(jsonString));
        print('🔥 📱 Loaded ${data.length} cached last messages');
        return data;
      }
    } catch (e) {
      print('🔥 Error loading cached last messages: $e');
    }
    return {};
  }

  /// ✅ USER SESSION PERSISTENCE
  static Future<void> saveUserSession({
    required String userId,
    required String username,
    required String token,
    String? name,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'userId': userId,
        'username': username,
        'token': token,
        'name': name,
        'loginTime': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_keyUserSession, jsonEncode(sessionData));
      print('🔥 💾 User session saved for: $username');
    } catch (e) {
      print('🔥 Error saving user session: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyUserSession);
      
      if (jsonString != null) {
        final sessionData = Map<String, dynamic>.from(jsonDecode(jsonString));
        print('🔥 📱 Loaded cached user session: ${sessionData['username']}');
        return sessionData;
      }
    } catch (e) {
      print('🔥 Error loading cached user session: $e');
    }
    return null;
  }

  /// ✅ OFFLINE MODE MANAGEMENT
  static Future<void> setOfflineMode(bool isOffline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOfflineMode, isOffline);
      print('🔥 📡 Offline mode set to: $isOffline');
    } catch (e) {
      print('🔥 Error setting offline mode: $e');
    }
  }

  static Future<bool> isOfflineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOfflineMode) ?? false;
    } catch (e) {
      print('🔥 Error checking offline mode: $e');
      return false;
    }
  }

  /// ✅ CACHE MANAGEMENT
  static Future<void> _updateLastCacheTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastUpdate, DateTime.now().toIso8601String());
    } catch (e) {
      print('🔥 Error updating cache time: $e');
    }
  }

  static Future<DateTime?> getLastCacheTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString(_keyLastUpdate);
      
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
    } catch (e) {
      print('🔥 Error getting last cache time: $e');
    }
    return null;
  }


  /// ✅ CHECK IF HAS CACHED DATA
  static Future<bool> hasCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasChatLinks = prefs.getString(_keyChatLinks) != null;
      final hasChannels = prefs.getString(_keyChannels) != null;
      final hasContacts = prefs.getString(_keyContacts) != null;
      
      return hasChatLinks && hasChannels && hasContacts;
    } catch (e) {
      print('🔥 Error checking cached data: $e');
      return false;
    }
  }

  /// ✅ CLEAR ALL CACHE
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = [
        _keyChatLinks,
        _keyChannels,
        _keyAccounts,
        _keyContacts,
        _keyLastMessages,
        _keyLastUpdate,
      ];
      
      for (String key in keys) {
        await prefs.remove(key);
      }
      
      print('🔥 🗑️ Cache cleared');
    } catch (e) {
      print('🔥 Error clearing cache: $e');
    }
  }

  /// ✅ CLEAR USER SESSION
  static Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserSession);
      await prefs.remove(_keyOfflineMode);
      print('🔥 🗑️ User session cleared');
    } catch (e) {
      print('🔥 Error clearing user session: $e');
    }
  }

  /// ✅ GET CACHE STATUS
  static Future<Map<String, dynamic>> getCacheStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = await getLastCacheTime();
      final hasCachedData = await CacheService.hasCachedData();
      final isOffline = await isOfflineMode();
      
      return {
        'hasCachedData': hasCachedData,
        'isOfflineMode': isOffline,
        'lastUpdate': lastUpdate?.toIso8601String(),
        'cacheAge': lastUpdate != null 
          ? DateTime.now().difference(lastUpdate).inMinutes
          : null,
        'chatLinks': prefs.getString(_keyChatLinks) != null,
        'channels': prefs.getString(_keyChannels) != null,
        'accounts': prefs.getString(_keyAccounts) != null,
        'contacts': prefs.getString(_keyContacts) != null,
        'lastMessages': prefs.getString(_keyLastMessages) != null,
      };
    } catch (e) {
      print('🔥 Error getting cache status: $e');
      return {};
    }
  }

  /// ✅ EXPORT CACHE FOR DEBUGGING
  static Future<Map<String, dynamic>> exportCacheForDebug() async {
    try {
      final chatLinks = await getCachedChatLinks();
      final channels = await getCachedChannels();
      final accounts = await getCachedAccounts();
      final contacts = await getCachedContacts();
      final lastMessages = await getCachedLastMessages();
      final cacheStatus = await getCacheStatus();
      
      return {
        'cacheStatus': cacheStatus,
        'data': {
          'chatLinks': chatLinks.length,
          'channels': channels.length,
          'accounts': accounts.length,
          'contacts': contacts.length,
          'lastMessages': lastMessages.length,
        }
      };
    } catch (e) {
      print('🔥 Error exporting cache: $e');
      return {};
    }
  }
}
