import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

// Login form ke submit par email/password app ko bhejta hai. Form normal tarike se submit hota
// rehta hai (web session ke liye), ye sirf parallel mein token lene ke liye hai.
const String _captureLoginJs = r'''
(function () {
  if (window.__rfCaptureHooked) return;
  window.__rfCaptureHooked = true;
  document.addEventListener('submit', function (e) {
    var form = e.target;
    var pw = form.querySelector('input[type=password]');
    var em = form.querySelector('input[type=email], input[name=email]');
    if (!pw || !em) return;
    NativeLogin.postMessage(JSON.stringify({ email: em.value, password: pw.value }));
  }, true);
})();
''';

class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.onSignedOut, this.onLoggedIn});

  final VoidCallback onSignedOut;
  final VoidCallback? onLoggedIn;

  @override
  State<WebScreen> createState() => _WebScreenState();
}

class _WebScreenState extends State<WebScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'NativeLogin',
        onMessageReceived: (message) => _saveEmailToken(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageFinished: (url) {
            setState(() => _progress = 100);
            if (Uri.parse(url).path == '/login') {
              unawaited(_controller.runJavaScript(_captureLoginJs));
            } else {
              unawaited(_notifyIfLoggedIn());
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            if (uri.host == Uri.parse(kAppUrl).host && uri.path == '/auth/google') {
              unawaited(_googleSignIn());
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _start();
  }

  Future<void> _start() async {
    final token = await ApiService.instance.readToken();
    if (token != null) {
      await _openSession();
    } else {
      await _controller.loadRequest(Uri.parse('$kAppUrl/login'));
    }
  }

  Future<void> _openSession() async {
    try {
      final url = await AuthService.webSessionUrl();
      await _controller.loadRequest(Uri.parse(url));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _signOut();
        return;
      }
      _showError('Session load fail: $e');
    } catch (e) {
      _showError('Network error: $e');
    }
  }

  Future<void> _notifyIfLoggedIn() async {
    final onLoggedIn = widget.onLoggedIn;
    if (onLoggedIn == null) return;
    if (await ApiService.instance.readToken() != null && mounted) {
      onLoggedIn();
    }
  }

  Future<void> _saveEmailToken(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await AuthService.loginWithEmail(
        data['email'] as String,
        data['password'] as String,
      );
    } catch (_) {
      // Web login apne aap chalta hai; token na mile to chupchap skip karo.
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _signingIn = true);
    try {
      final idToken = await AuthService.googleIdToken();
      await AuthService.loginWithGoogle(idToken);
      await _openSession();
    } catch (e) {
      _showError('Google login fail: $e');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _handleBack();
        if (shouldExit && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100)
                LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                ),
              if (_signingIn)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
