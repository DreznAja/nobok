import 'package:flutter/material.dart';
import 'package:nobox_mobile/services/api_service.dart';
import 'package:nobox_mobile/services/cache_service.dart';
import 'package:nobox_mobile/services/connection_service.dart';
import 'package:nobox_mobile/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreenEnhanced extends StatefulWidget {
  const LoginScreenEnhanced({Key? key}) : super(key: key);

  @override
  State<LoginScreenEnhanced> createState() => _LoginScreenEnhancedState();
}

class _LoginScreenEnhancedState extends State<LoginScreenEnhanced> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  // ✅ NEW: Offline login support
  bool _isOfflineMode = false;
  bool _hasOfflineCapability = false;

  @override
  void initState() {
    super.initState();
    _initializeOfflineLogin();
  }

  /// ✅ NEW: Initialize offline login capability
  Future<void> _initializeOfflineLogin() async {
    try {
      // Initialize connection service
      await ConnectionService.initialize();
      
      // Initialize UserService
      await UserService.initialize();
      
      // Check if we have offline capability
      await _checkOfflineCapability();
      
    } catch (e) {
      print('🔥 Error initializing offline login: $e');
    }
  }

  /// ✅ NEW: Check offline capability dan existing session
  Future<void> _checkOfflineCapability() async {
    try {
      // Check if we have cached user session
      final cachedSession = await CacheService.getCachedUserSession();
      final hasCachedData = await CacheService.hasCachedData();
      final isConnected = await ConnectionService.checkConnectionNow();
      
      setState(() {
        _isOfflineMode = !isConnected;
        _hasOfflineCapability = cachedSession != null && hasCachedData;
      });
      
      print('🔥 📱 Offline capability check:');
      print('🔥    Connected: $isConnected');
      print('🔥    Has cached session: ${cachedSession != null}');
      print('🔥    Has cached data: $hasCachedData');
      print('🔥    Offline capability: $_hasOfflineCapability');
      
      // ✅ CRITICAL: Auto-login jika ada session dan data cached
      if (cachedSession != null && hasCachedData) {
        final token = cachedSession['token']?.toString();
        final userId = cachedSession['userId']?.toString();
        final username = cachedSession['username']?.toString();
        final name = cachedSession['name']?.toString();
        
        if (token != null && userId != null && username != null) {
          print('🔥 🔄 Found valid cached session, attempting auto-login...');
          
          // Set user session
          await UserService.setCurrentUser(
            userId: userId,
            username: username,
            name: name,
          );
          
          if (isConnected) {
            // Online: Test token validity
            ApiService.setAuthToken(token);
            final testResponse = await ApiService.testConnection();
            
            if (testResponse.success) {
              print('🔥 ✅ Auto-login successful (online)');
              _showSuccessSnackBar('Welcome back, ${name ?? username}!');
              _navigateToHome();
              return;
            } else {
              print('🔥 ❌ Cached token invalid, clearing session');
              await _clearInvalidSession();
            }
          } else {
            // Offline: Use cached session directly
            print('🔥 📱 Auto-login with cached session (offline mode)');
            ApiService.setAuthToken(token);
            _showSuccessSnackBar('📱 Welcome back, ${name ?? username}! (Offline Mode)');
            _navigateToHome();
            return;
          }
        }
      }
      
      // ✅ NEW: Pre-fill username jika ada cached session
      if (cachedSession != null) {
        final username = cachedSession['username']?.toString();
        if (username != null && username.isNotEmpty) {
          _usernameController.text = username;
          print('🔥 📝 Pre-filled username: $username');
        }
      }
      
    } catch (e) {
      print('🔥 Error checking offline capability: $e');
    }
  }

  /// ✅ NEW: Clear invalid cached session
  Future<void> _clearInvalidSession() async {
    try {
      await CacheService.clearUserSession();
      await UserService.clearCurrentUser();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      print('🔥 🗑️ Invalid session cleared');
    } catch (e) {
      print('🔥 Error clearing invalid session: $e');
    }
  }

  /// ✅ ENHANCED: Login dengan offline support
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      
      // Check connection status
      final isConnected = await ConnectionService.checkConnectionNow();
      
      if (isConnected) {
        // ✅ ONLINE LOGIN
        print('🔥 🌐 Attempting online login...');
        
        final response = await ApiService.login(username, password);

        if (response.success && response.data != null) {
          final user = response.data!;
          final token = ApiService.authToken!;
          
          print('🔥 ✅ Online login successful');
          
          // Save user session untuk offline capability
          await CacheService.saveUserSession(
            userId: user.id,
            username: user.username,
            token: token,
            name: user.name,
          );
          
          // Save token for future sessions
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('username', username);
          
          print('🔥 💾 User session cached for offline use');
          _showSuccessSnackBar('✅ Login successful!');
          _navigateToHome();
        } else {
          _showErrorSnackBar(response.message ?? 'Login failed');
        }
        
      } else {
        // ✅ OFFLINE LOGIN ATTEMPT
        print('🔥 📱 Attempting offline login...');
        
        if (!_hasOfflineCapability) {
          _showErrorSnackBar('❌ Offline login not available. Please connect to internet for first-time login.');
          return;
        }
        
        final cachedSession = await CacheService.getCachedUserSession();
        if (cachedSession == null) {
          _showErrorSnackBar('❌ No cached credentials found. Please connect to internet.');
          return;
        }
        
        final cachedUsername = cachedSession['username']?.toString();
        
        // Verify username matches (simple offline validation)
        if (cachedUsername != username) {
          _showErrorSnackBar('❌ Username does not match cached credentials.');
          return;
        }
        
        // ✅ OFFLINE LOGIN SUCCESS
        final token = cachedSession['token']?.toString();
        final userId = cachedSession['userId']?.toString();
        final name = cachedSession['name']?.toString();
        
        if (token != null && userId != null) {
          // Set user session
          await UserService.setCurrentUser(
            userId: userId,
            username: username,
            name: name,
          );
          
          ApiService.setAuthToken(token);
          
          print('🔥 ✅ Offline login successful');
          _showSuccessSnackBar('📱 Welcome back, ${name ?? username}! (Offline Mode)');
          _navigateToHome();
        } else {
          _showErrorSnackBar('❌ Cached session data is incomplete.');
        }
      }
    } catch (e) {
      print('🔥 Login error: $e');
      _showErrorSnackBar('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo from assets
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        'assets/nobox2.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title dengan offline indicator
                  const Text(
                    'NoBox Chat',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // ✅ NEW: Subtitle dengan offline status
                  Column(
                    children: [
                      Text(
                        _isOfflineMode ? 'Sign in (Offline Mode)' : 'Sign in to your account',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (_isOfflineMode) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.red[400],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _hasOfflineCapability 
                                ? 'Cached login available' 
                                : 'No offline login available',
                              style: TextStyle(
                                fontSize: 12,
                                color: _hasOfflineCapability ? Colors.orange[700] : Colors.red[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Username field with label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isOfflineMode ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: _isOfflineMode ? const Color(0xFFBBBBBB) : const Color(0xFF999999),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: _isOfflineMode ? Colors.red[400] : const Color(0xFF666666),
                              size: 22,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Password field with label
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isOfflineMode ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                          decoration: InputDecoration(
                            hintText: _isOfflineMode && _hasOfflineCapability 
                              ? 'Password (offline login)'
                              : 'Enter your password',
                            hintStyle: TextStyle(
                              color: _isOfflineMode ? const Color(0xFFBBBBBB) : const Color(0xFF999999),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline_rounded,
                              color: _isOfflineMode ? Colors.red[400] : const Color(0xFF666666),
                              size: 22,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _isOfflineMode ? Colors.red[400] : const Color(0xFF666666),
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // ✅ NEW: Offline mode info
                  if (_isOfflineMode && !_hasOfflineCapability) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red[600], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No internet connection. First-time login requires internet access.',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (_isOfflineMode && _hasOfflineCapability) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.offline_bolt, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline mode available. You can sign in with cached credentials.',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                  
                  // Login button dengan offline styling
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || (_isOfflineMode && !_hasOfflineCapability)) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isOfflineMode && _hasOfflineCapability
                          ? Colors.orange[600]
                          : const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isOfflineMode && _hasOfflineCapability) ...[
                                  const Icon(Icons.offline_bolt, size: 18),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _isOfflineMode && _hasOfflineCapability
                                    ? 'Sign In (Offline)'
                                    : 'Sign In',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  // ✅ NEW: Connection retry button
                  if (_isOfflineMode) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          _isLoading = true;
                        });
                        
                        try {
                          final isConnected = await ConnectionService.checkConnectionNow();
                          if (isConnected) {
                            await _checkOfflineCapability();
                            _showSuccessSnackBar('✅ Connected to internet!');
                          } else {
                            _showErrorSnackBar('❌ Still no internet connection');
                          }
                        } catch (e) {
                          _showErrorSnackBar('Connection check failed: $e');
                        } finally {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 18, color: Colors.blue[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Check Connection',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    ConnectionService.dispose();
    super.dispose();
  }
}