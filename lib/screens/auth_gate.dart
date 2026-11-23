import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/products.dart';
import '../services/session.dart';
import '../widgets/splash_view.dart';
import '../widgets/state_view.dart';
import 'admin_shell.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'plan_gate_screen.dart';
import 'product_hub.dart';

enum _Stage { checking, retry, loggedOut, ready }

/// Decides what the user sees: login, then the product boxes. A product the
/// plan includes opens; any other shows the plan page. Super admins go to the
/// admin area.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  _Stage _stage = _Stage.checking;
  String _error = '';
  int _sessionId = 0;

  /// The product that is open, or null on the product boxes.
  Product? _open;

  /// A product the person tapped but the plan does not include.
  Product? _locked;

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

  /// Screens opened on top of this one (chats, profile pages) must not stay
  /// visible over the login screen or the product boxes.
  void _closeOpenPages() {
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _onSessionExpired() {
    if (!mounted || _stage == _Stage.loggedOut) return;
    Session.clear();
    _closeOpenPages();
    setState(() {
      _stage = _Stage.loggedOut;
      _open = null;
      _locked = null;
      _sessionId++;
    });
  }

  /// The plan ended while the app was open: back to the boxes, now locked.
  void _onPlanRequired() {
    if (!mounted || _stage != _Stage.ready) return;
    _closeOpenPages();
    _open = null;
    _locked = null;
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
      await Session.refresh();
      _show(_Stage.ready);
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
    _closeOpenPages();
    setState(() {
      _stage = _Stage.loggedOut;
      _open = null;
      _locked = null;
      _sessionId++;
    });
  }

  void _loggedIn() {
    final user = Session.current;
    if (user == null) {
      _bootstrap();
      return;
    }
    setState(() {
      _stage = _Stage.ready;
      _open = null;
      _locked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.checking:
        return const SplashView();
      case _Stage.retry:
        return _RetryView(message: _error, onRetry: _bootstrap);
      case _Stage.loggedOut:
        return LoginScreen(
          key: ValueKey('login$_sessionId'),
          onLoggedIn: _loggedIn,
        );
      case _Stage.ready:
        if (Session.current?.isSuperAdmin ?? false) {
          return AdminShell(
            key: ValueKey('admin$_sessionId'),
            onSignedOut: _signedOut,
          );
        }
        final locked = _locked;
        if (locked != null) {
          return PlanGateScreen(
            key: ValueKey('gate$_sessionId${locked.name}'),
            product: locked,
            onBack: () => setState(() => _locked = null),
            // The plan now includes it: open the product.
            onUnlocked: () => setState(() {
              _open = locked;
              _locked = null;
            }),
            onSignedOut: _signedOut,
          );
        }
        final open = _open;
        if (open != null) {
          return HomeShell(
            key: ValueKey('home$_sessionId${open.name}'),
            product: open,
            onSignedOut: _signedOut,
            onHub: () => setState(() => _open = null),
          );
        }
        return ProductHub(
          key: ValueKey('hub$_sessionId'),
          onOpen: (p) => setState(() => _open = p),
          onLocked: (p) => setState(() => _locked = p),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: StateView.error(
              title: 'Could not open Eydia',
              text: message,
              onRetry: onRetry,
            ),
          ),
        ),
      ),
    );
  }
}
