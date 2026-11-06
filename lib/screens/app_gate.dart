import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config_service.dart';
import '../theme/brand.dart';
import '../widgets/royal_backdrop.dart';
import '../widgets/splash_view.dart';

/// Runs before login and every time the app comes back to the foreground:
/// blocks the app while the server is in maintenance or when this version is
/// older than the minimum supported one. Nothing here can throw, so a failed
/// check never crashes the app.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  AppGateResult? _result;
  bool _checking = false;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // People who leave the app open for days still meet the gate on return.
    // Throttled so quick app switches do not hit the server every time.
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 2)) {
      return;
    }
    _check(silent: true);
  }

  /// [silent] keeps the current screen visible while checking (no spinner).
  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent && mounted) setState(() => _result = null);
    try {
      final r = await AppConfigService.check();
      _lastCheck = DateTime.now();
      if (mounted) setState(() => _result = r);
    } catch (_) {
      // check() already fails open; this is only a last guard.
      if (mounted) setState(() => _result = AppGateResult(AppGateState.ok));
    } finally {
      _checking = false;
    }
  }

  Future<void> _openStore(String url) async {
    final target = url.isNotEmpty ? url : AppConfigService.defaultUpdateUrl;
    try {
      final ok = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('cannot launch');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Play. Please update Eydia from the Play Store.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null) {
      return const SplashView();
    }
    switch (r.state) {
      case AppGateState.ok:
        return widget.child;
      case AppGateState.maintenance:
        return _Blocked(
          icon: Icons.build_circle_outlined,
          title: 'Under maintenance',
          text: r.message,
          button: 'Try again',
          onPressed: _check,
        );
      case AppGateState.updateRequired:
        return _Blocked(
          icon: Icons.system_update_rounded,
          title: 'Update required',
          text: r.latestVersion.isNotEmpty
              ? 'This version of Eydia is no longer supported. Please update to version ${r.latestVersion} to keep using the app.'
              : 'This version of Eydia is no longer supported. Please update to keep using the app.',
          button: 'Update now',
          onPressed: () => _openStore(r.updateUrl),
        );
    }
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({
    required this.icon,
    required this.title,
    required this.text,
    required this.button,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String text;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RoyalBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            royalIndigo.withValues(alpha: 0.16),
                            royalViolet.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(icon, size: 40, color: royalIndigo),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.5,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: onPressed, child: Text(button)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
