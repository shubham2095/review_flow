import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_config_service.dart';
import '../theme/brand.dart';

/// Runs before login: blocks the app while the server is in maintenance or when
/// this version is older than the minimum supported one.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  AppGateResult? _result;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _result = null);
    final r = await AppConfigService.check();
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
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
          text:
              'This version of Eydia is no longer supported. Please update to keep using the app.',
          button: 'Update now',
          onPressed: () {
            final url = r.updateUrl;
            if (url.isNotEmpty) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: royalIndigo.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
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
                FilledButton(onPressed: onPressed, child: Text(button)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
