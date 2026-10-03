import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class WebScreen extends StatefulWidget {
  const WebScreen({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageFinished: (_) => setState(() => _progress = 100),
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
