// 🔥 PERBAIKAN UserService untuk deteksi user yang lebih akurat

import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static String? _currentUserId;
  static String? _currentUsername;
  static String? _currentUserName;
  static String? _currentAgentId;
  static const String _userIdKey = 'current_user_id';
  static const String _usernameKey = 'current_username';
  static const String _userNameKey = 'current_user_name';
  static const String _agentIdKey = 'current_agent_id';

  /// Set current user data (call this after successful login)
  static Future<void> setCurrentUser({
    required String userId,
    required String username,
    String? name,
    String? agentId, // 🔥 TAMBAHAN parameter
  }) async {
    _currentUserId = userId;
    _currentUsername = username;
    _currentUserName = name ?? username;
    _currentAgentId = agentId;

    // Persist to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
    if (name != null) {
      await prefs.setString(_userNameKey, name);
    }
    if (agentId != null) {
      await prefs.setString(_agentIdKey, agentId);
    }

    print(
        '🔥 UserService: Current user set - ID: $userId, Username: $username, Name: ${_currentUserName}, AgentId: $agentId');
  }

  /// Load user data from SharedPreferences (call this on app start)
  static Future<void> loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString(_userIdKey);
    _currentUsername = prefs.getString(_usernameKey);
    _currentUserName = prefs.getString(_userNameKey) ?? _currentUsername;
    _currentAgentId = prefs.getString(_agentIdKey);

    print(
        '🔥 UserService: Loaded user - ID: $_currentUserId, Username: $_currentUsername, Name: $_currentUserName, AgentId: $_currentAgentId');
  }

  static Future<void> clearCurrentUser() async {
    _currentUserId = null;
    _currentUsername = null;
    _currentUserName = null;
    _currentAgentId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_agentIdKey);
  }

  static String? get currentUserId => _currentUserId;
  static String? get currentUsername => _currentUsername;
  static String? get currentUserName => _currentUserName;
  static String? get currentAgentId => _currentAgentId; // 🔥 TAMBAHAN getter

  static bool isMyMessage(String senderId) {
    if (senderId.isEmpty) return false;

    print('🔥 UserService.isMyMessage: senderId="$senderId"');
    print('   currentUserId="$_currentUserId"');
    print('   currentUsername="$_currentUsername"');
    print('   currentAgentId="$_currentAgentId"');

    // 1. ✅ PRIORITAS TERTINGGI: Check exact user ID match
    if (_currentUserId != null && senderId == _currentUserId) {
      print('🔥 ✅ MATCH by exact userId');
      return true;
    }

    // 2. ✅ Check exact username match
    if (_currentUsername != null && senderId == _currentUsername) {
      print('🔥 ✅ MATCH by exact username');
      return true;
    }

    // 3. 🔥 TAMBAHAN: Check agent ID match (untuk kasus agent yang login)
    if (_currentAgentId != null && senderId == _currentAgentId) {
      print('🔥 ✅ MATCH by agentId');
      return true;
    }

    // 4. ✅ Check jika senderId mengandung user ID kita
    if (_currentUserId != null && _currentUserId!.length > 3) {
      if (senderId.contains(_currentUserId!) &&
          (senderId.startsWith('${_currentUserId}_') ||
              senderId.endsWith('_$_currentUserId') ||
              senderId == _currentUserId)) {
        print('🔥 ✅ MATCH by userId in compound ID');
        return true;
      }
    }

    // 5. 🔥 KHUSUS: Handle kasus dimana senderId adalah "me" atau format serupa
    if (senderId.toLowerCase() == 'me' || senderId == 'user') {
      print('🔥 ✅ MATCH by generic "me" identifier');
      return true;
    }

    print('🔥 ❌ NO MATCH - treating as other user');
    return false;
  }

  // 🔥 TAMBAHAN: Method untuk mendapatkan display name yang konsisten
  static String getDisplayNameForMessage({
    required String senderId,
    String? senderName,
    required bool isFromCurrentUser,
  }) {
    if (isFromCurrentUser) {
      // Untuk pesan dari user sendiri, selalu tampilkan format konsisten
      return 'Me (${_currentUserName ?? _currentUsername ?? 'User'})';
    } else {
      // Untuk pesan dari user lain, gunakan nama asli mereka
      return senderName ?? senderId;
    }
  }

  // 🔥 TAMBAHAN: Method untuk memvalidasi konsistensi user data
  static bool validateCurrentUserData() {
    final isValid = _currentUserId != null &&
        _currentUserId!.isNotEmpty &&
        _currentUsername != null &&
        _currentUsername!.isNotEmpty;

    if (!isValid) {
      print('⚠️ UserService: Invalid user data detected');
      print('   - UserId: $_currentUserId');
      print('   - Username: $_currentUsername');
      print('   - UserName: $_currentUserName');
    }

    return isValid;
  }

  /// Get user display info
  static Map<String, String?> getCurrentUserInfo() {
    return {
      'userId': _currentUserId,
      'username': _currentUsername,
      'name': _currentUserName,
      'displayName': 'Me (${_currentUserName ?? _currentUsername ?? 'User'})',
    };
  }

  /// Initialize user service (call this in main.dart or splash screen)
  static Future<void> initialize() async {
    await loadCurrentUser();
    if (isLoggedIn) {
      print('🔥 UserService initialized with user: ${getCurrentUserInfo()}');
    } else {
      print('🔥 UserService initialized - no user logged in');
    }
  }

  // 🔥 DEBUGGING: Method untuk log semua informasi user saat ini
  static void debugLogCurrentUser() {
    print('🔥 === CURRENT USER DEBUG INFO ===');
    print('🔥 User ID: $_currentUserId');
    print('🔥 Username: $_currentUsername');
    print('🔥 User Name: $_currentUserName');
    print('🔥 Is Logged In: $isLoggedIn');
    print(
        '🔥 Display Name: Me (${_currentUserName ?? _currentUsername ?? 'User'})');
    print('🔥 =================================');
  }

  static Future<void> setAgentId(String agentId) async {
    _currentAgentId = agentId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_agentIdKey, agentId);
    print('🔥 UserService: Agent ID set to: $agentId');
  }

  static bool get isLoggedIn =>
      _currentUserId != null &&
      _currentUserId!.isNotEmpty &&
      _currentUsername != null &&
      _currentUsername!.isNotEmpty;

  static void setCurrentUserFromData(Map<String, dynamic> userData) {}
}