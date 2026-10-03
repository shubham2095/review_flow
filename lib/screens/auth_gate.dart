import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'home_shell.dart';
import 'web_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _hasToken = false;
  int _sessionId = 0;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final token = await ApiService.instance.readToken();
    if (!mounted) return;
    setState(() {
      _hasToken = token != null;
      _checking = false;
    });
  }

  void _signedOut() {
    setState(() {
      _hasToken = false;
      _sessionId++;
    });
  }

  void _loggedIn() {
    setState(() => _hasToken = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_hasToken) {
      return HomeShell(
        key: ValueKey('home$_sessionId'),
        onSignedOut: _signedOut,
      );
    }

    return WebScreen(
      key: ValueKey('login$_sessionId'),
      onSignedOut: _signedOut,
      onLoggedIn: _loggedIn,
    );
  }
}
