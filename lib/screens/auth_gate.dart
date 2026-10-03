import 'package:flutter/material.dart';

import 'web_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _sessionId = 0;

  @override
  Widget build(BuildContext context) {
    return WebScreen(
      key: ValueKey(_sessionId),
      onSignedOut: () => setState(() => _sessionId++),
    );
  }
}
