// captcha_service.dart - Simple approach: hanya ambil token
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CaptchaService {
  static const String SITE_KEY = "6Lf0eaMrAAAAAP9eLGrSsKKj8mwH6cNETyV-AheZ";
  
  static Future<String?> showCaptchaDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => CaptchaDialog(),
    );
  }
}

class CaptchaDialog extends StatefulWidget {
  @override
  _CaptchaDialogState createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<CaptchaDialog> {
  late WebViewController controller;
  bool isLoading = true;
  bool captchaCompleted = false;

  @override
  void initState() {
    super.initState();
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            
            // ✅ Inject script untuk monitor reCAPTCHA completion
            _injectCaptchaMonitor();
          },
          // ✅ PENTING: Intercept navigation untuk prevent login
          onNavigationRequest: (NavigationRequest request) {
            print('🔥 Navigation to: ${request.url}');
            
            Uri uri = Uri.parse(request.url);
            
            // Allow staying on login page and loading assets
            if (uri.path == '/Account/Login' || 
                uri.path.contains('.js') || 
                uri.path.contains('.css') || 
                uri.path.contains('.png') || 
                uri.path.contains('.jpg') ||
                uri.path.contains('.woff') ||
                uri.path.contains('recaptcha') ||
                uri.host.contains('google') ||
                uri.host.contains('gstatic') ||
                uri.host != 'id.nobox.ai') {
              return NavigationDecision.navigate;
            }
            
            // ✅ Block navigation to Messages/Inbox (login success)
            if (uri.path == '/Messages/Inbox' || uri.path.startsWith('/Messages/')) {
              print('🔥 LOGIN SUCCESS DETECTED! Blocking navigation to: ${request.url}');
              print('🔥 Extracting reCAPTCHA token instead...');
              
              // Extract token before preventing
              _extractTokenBeforeRedirect();
              return NavigationDecision.prevent;
            }
            
            // Block any other navigation away from login
            print('🔥 Preventing navigation to: ${request.url}');
            _extractTokenBeforeRedirect();
            return NavigationDecision.prevent;
          },
        ),
      )
      ..addJavaScriptChannel(
        'CaptchaHandler',
        onMessageReceived: (JavaScriptMessage message) {
          print('🔥 Message from WebView: ${message.message}');
          
          if (message.message.startsWith('CAPTCHA_TOKEN:')) {
            String token = message.message.replaceFirst('CAPTCHA_TOKEN:', '');
            print('🔥 reCAPTCHA token extracted: $token');
            Navigator.of(context).pop(token);
          } else if (message.message == 'CAPTCHA_COMPLETED') {
            setState(() {
              captchaCompleted = true;
            });
          }
        },
      )
      ..loadRequest(Uri.parse('https://id.nobox.ai/Account/Login'));
  }

  void _extractTokenBeforeRedirect() {
    // Force extract token saat mau redirect (kemungkinan login berhasil)
    controller.runJavaScript('''
      console.log('🔥 Forced token extraction before redirect...');
      var recaptchaElements = document.querySelectorAll('[name="g-recaptcha-response"]');
      
      for (var i = 0; i < recaptchaElements.length; i++) {
        var element = recaptchaElements[i];
        if (element.value && element.value.length > 10) {
          console.log('🔥 Found token before redirect: ' + element.value);
          CaptchaHandler.postMessage('CAPTCHA_TOKEN:' + element.value);
          return;
        }
      }
      
      // Jika tidak ada token, berarti mungkin ada error lain
      console.log('🔥 No token found before redirect - might be navigation error');
    ''');
  }

  void _injectCaptchaMonitor() {
    controller.runJavaScript('''
      console.log('🔥 Injecting reCAPTCHA monitor...');
      
      // Function to check for reCAPTCHA token
      function checkRecaptchaToken() {
        var recaptchaElements = document.querySelectorAll('[name="g-recaptcha-response"]');
        
        for (var i = 0; i < recaptchaElements.length; i++) {
          var element = recaptchaElements[i];
          if (element.value && element.value.length > 10) {
            console.log('🔥 reCAPTCHA token found: ' + element.value);
            CaptchaHandler.postMessage('CAPTCHA_TOKEN:' + element.value);
            return true;
          }
        }
        return false;
      }
      
      // Monitor reCAPTCHA completion
      function monitorRecaptcha() {
        // Check every 1 second for token
        setInterval(function() {
          if (checkRecaptchaToken()) {
            return; // Stop monitoring if token found
          }
        }, 1000);
        
        // Also check on any click/change events
        document.addEventListener('click', function() {
          setTimeout(checkRecaptchaToken, 500);
        });
        
        document.addEventListener('change', function() {
          setTimeout(checkRecaptchaToken, 500);
        });
      }
      
      // Override reCAPTCHA callback if possible
      window.grecaptchaCallback = function(token) {
        console.log('🔥 reCAPTCHA callback fired: ' + token);
        CaptchaHandler.postMessage('CAPTCHA_TOKEN:' + token);
      };
      
      // Start monitoring
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', monitorRecaptcha);
      } else {
        monitorRecaptcha();
      }
      
      // ✅ PENTING: Prevent form submission
      document.addEventListener('DOMContentLoaded', function() {
        var forms = document.querySelectorAll('form');
        forms.forEach(function(form) {
          form.addEventListener('submit', function(e) {
            console.log('🔥 Form submission prevented');
            e.preventDefault();
            e.stopPropagation();
            
            // Just extract the token, don't submit
            checkRecaptchaToken();
            return false;
          });
        });
        
        // Hide submit button to prevent confusion
        var submitButtons = document.querySelectorAll('input[type="submit"], button[type="submit"]');
        submitButtons.forEach(function(btn) {
          btn.style.display = 'none';
        });
        
        // Add instruction
        var instruction = document.createElement('div');
        instruction.innerHTML = '<p style="background: #e3f2fd; padding: 15px; margin: 15px 0; border-radius: 5px; text-align: center; color: #1565c0;"><strong>Mobile App:</strong> Complete the reCAPTCHA above, then the dialog will close automatically.</p>';
        
        var recaptchaDiv = document.querySelector('.g-recaptcha');
        if (recaptchaDiv && recaptchaDiv.parentNode) {
          recaptchaDiv.parentNode.insertBefore(instruction, recaptchaDiv.nextSibling);
        }
      });
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      child: Container(
        width: double.maxFinite,
        height: 500,
        child: Column(
          children: [
            // Header with close button
            Container(
              color: Colors.blue,
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'Security Verification',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Instructions
            Container(
              color: Colors.orange[50],
              padding: EdgeInsets.all(12),
              width: double.infinity,
              child: Text(
                '✅ Complete the reCAPTCHA verification below\n⚠️ DO NOT enter credentials or click login\n🔄 Dialog will close automatically after verification',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange[800],
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: controller),
                  if (isLoading)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading verification page...'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Footer status
            Container(
              color: captchaCompleted ? Colors.green[50] : Colors.grey[100],
              padding: EdgeInsets.all(8),
              width: double.infinity,
              child: Text(
                captchaCompleted 
                  ? '✅ Verification completed!' 
                  : '🔄 Waiting for verification...',
                style: TextStyle(
                  fontSize: 12,
                  color: captchaCompleted ? Colors.green[700] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}