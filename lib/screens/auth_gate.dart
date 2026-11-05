import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import 'admin_shell.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'plan_gate_screen.dart';

enum _Stage { checking, retry, loggedOut, locked, ready }

/// Decides what the user sees: login, the plan screen (no active plan yet), or the app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _Stage _stage = _Stage.checking;
  String _error = '';
  int _sessionId = 0;

  @override
  void initState() {
    super.initState();
    ApiService.sessionExpired.addListener(_onSessionExpired);
    ApiService.planRequired.addListener(_onPlanRequired);
    _bootstrap();
  }

  @override
  void dispose() {
    ApiService.sessionExpired.removeListener(_onSessionExpired);
    ApiService.planRequired.removeListener(_onPlanRequired);
    super.dispose();
  }

  void _onSessionExpired() {
    if (!mounted || _stage == _Stage.loggedOut) return;
    Session.clear();
    setState(() {
      _stage = _Stage.loggedOut;
      _sessionId++;
    });
  }

  void _onPlanRequired() {
    if (!mounted || _stage != _Stage.ready) return;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (mounted) setState(() => _stage = _Stage.checking);
    final token = await ApiService.instance.readToken();
    if (token == null) {
      _show(_Stage.loggedOut);
      return;
    }
    try {
      final user = await Session.refresh();
      _show(user.hasPlan ? _Stage.ready : _Stage.locked);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _show(_Stage.loggedOut);
      } else {
        _error = e.message;
        _show(_Stage.retry);
      }
    } catch (e) {
      _error = friendlyException(e).message;
      _show(_Stage.retry);
    }
  }

  void _show(_Stage stage) {
    if (!mounted) return;
    setState(() => _stage = stage);
  }

  void _signedOut() {
    Session.clear();
    setState(() {
      _stage = _Stage.loggedOut;
      _sessionId++;
    });
  }

  void _loggedIn() {
    final user = Session.current;
    if (user == null) {
      _bootstrap();
      return;
    }
    setState(() => _stage = user.hasPlan ? _Stage.ready : _Stage.locked);
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.checking:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Stage.retry:
        return _RetryView(message: _error, onRetry: _bootstrap);
      case _Stage.loggedOut:
        return LoginScreen(
          key: ValueKey('login$_sessionId'),
          onLoggedIn: _loggedIn,
        );
      case _Stage.locked:
        return PlanGateScreen(
          key: ValueKey('gate$_sessionId'),
          onUnlocked: _loggedIn,
          onSignedOut: _signedOut,
        );
      case _Stage.ready:
        if (Session.current?.isSuperAdmin ?? false) {
          return AdminShell(
            key: ValueKey('admin$_sessionId'),
            onSignedOut: _signedOut,
          );
        }
        return HomeShell(
          key: ValueKey('home$_sessionId'),
          onSignedOut: _signedOut,
        );
    }
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: muted),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
