import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/connection_service.dart';
import 'services/user_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NoboxAppEnhanced());
}

class NoboxAppEnhanced extends StatelessWidget {
  const NoboxAppEnhanced({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoBox',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SplashScreenEnhanced(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreenEnhanced extends StatefulWidget {
  const SplashScreenEnhanced({Key? key}) : super(key: key);

  @override
  State<SplashScreenEnhanced> createState() => _SplashScreenEnhancedState();
}

class _SplashScreenEnhancedState extends State<SplashScreenEnhanced> {
  String _initStatus = 'Initializing...';
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _initializeEnhancedApp();
  }

  Future<void> _initializeEnhancedApp() async {
    try {
      // 1. Initialize UserService
      setState(() {
        _initStatus = 'Setting up user service...';
      });
      await UserService.initialize();
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 2. Initialize Connection Service
      setState(() {
        _initStatus = 'Checking connection...';
      });
      await ConnectionService.initialize();
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 3. Check connection status
      final isConnected = await ConnectionService.checkConnectionNow();
      setState(() {
        _isOfflineMode = !isConnected;
        _initStatus = isConnected 
          ? 'Connected to server...' 
          : 'Running in offline mode...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. Check cached login status
      setState(() {
        _initStatus = 'Checking login status...';
      });
      await _checkEnhancedLoginStatus();
      
    } catch (e) {
      print('🔥 Error initializing enhanced app: $e');
      setState(() {
        _initStatus = 'Error: $e';
      });
      
      // Continue to login screen after error
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
        );
      }
    }
  }



  Future<void> _checkEnhancedLoginStatus() async {
    try {
      // Check for cached session
      final cachedSession = await CacheService.getCachedUserSession();
      final hasCachedData = await CacheService.hasCachedData();
      final isConnected = ConnectionService.isConnected;
      
      print('🔥 📱 Enhanced login check:');
      print('🔥    Connected: $isConnected');
      print('🔥    Has cached session: ${cachedSession != null}');
      print('🔥    Has cached data: $hasCachedData');
      
      if (!mounted) return;
      
      if (cachedSession != null) {
        final token = cachedSession['token']?.toString();
        final userId = cachedSession['userId']?.toString();
        final username = cachedSession['username']?.toString();
        final name = cachedSession['name']?.toString();
        
        if (token != null && userId != null && username != null) {
          // Set user session
          await UserService.setCurrentUser(
            userId: userId,
            username: username,
            name: name,
          );
          
          if (isConnected && hasCachedData) {
            // Online dengan cached data: Test token dan sync
            setState(() {
              _initStatus = 'Validating session...';
            });
            
            ApiService.setAuthToken(token);
            final testResponse = await ApiService.testConnection();
            
            if (testResponse.success) {
              setState(() {
                _initStatus = 'Welcome back, ${name ?? username}!';
              });
              await Future.delayed(const Duration(milliseconds: 800));
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
              return;
            } else {
              // Token invalid, clear session
              print('🔥 ❌ Token invalid, clearing session');
              await _clearInvalidSession();
            }
            
          } else if (!isConnected && hasCachedData) {
            // Offline dengan cached data: Auto-login offline
            setState(() {
              _initStatus = 'Loading offline data...';
            });
            
            ApiService.setAuthToken(token);
            await Future.delayed(const Duration(milliseconds: 800));
            
            setState(() {
              _initStatus = 'Welcome back, ${name ?? username}! (Offline)';
            });
            await Future.delayed(const Duration(milliseconds: 500));
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
            return;
            
          } else {
            // Ada session tapi tidak ada cached data
            print('🔥 ⚠️ Session found but no cached data, going to login');
          }
        }
      }
      
      // No valid session or data, go to login
      setState(() {
        _initStatus = 'Redirecting to login...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
      );
      
    } catch (e) {
      print('🔥 Error checking enhanced login status: $e');
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreenEnhanced()),
        );
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage('assets/nobox2.png'),
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 24),
            const Text(
              'NoBox Chat',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            
            // Loading indicator dengan offline styling
            CircularProgressIndicator(
              color: _isOfflineMode ? Colors.orange[600] : const Color(0xFF007AFF),
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}