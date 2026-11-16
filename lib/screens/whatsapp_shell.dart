import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/whatsapp_service.dart';
import '../theme/brand.dart';
import '../widgets/fade_indexed_stack.dart';
import '../widgets/wa_tab_scope.dart';
import 'whatsapp_contacts_screen.dart';
import 'whatsapp_inbox_screen.dart';
import 'whatsapp_screen.dart';

/// The WhatsApp area with a bottom bar: Home, Inbox (with the unread count) and
/// Contacts. More tabs are added one at a time; until then everything else is
/// reached from the tiles on Home, exactly as before.
class WhatsAppShell extends StatefulWidget {
  const WhatsAppShell({super.key});

  @override
  State<WhatsAppShell> createState() => WhatsAppShellState();
}

class WhatsAppShellState extends State<WhatsAppShell>
    with WidgetsBindingObserver {
  static const _homeTab = 0;
  static const _inboxTab = 1;
  static const _contactsTab = 2;
  static const _tabCount = 3;

  int _index = _homeTab;

  // Tabs open for the first time only, so opening WhatsApp does not fire every call.
  final Set<int> _visited = {_homeTab};

  int _unread = 0;
  DateTime? _lastUnreadAt;
  bool _fetchingUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshUnread(force: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from another app (or from reading a notification): the count may
  /// have moved.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshUnread();
  }

  /// Called by the home shell on Back. Returns true when the shell used it
  /// (it went from another tab to Home), false when Back should leave WhatsApp.
  bool goBackWithinShell() {
    if (_index == _homeTab) return false;
    _select(_homeTab);
    return true;
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
    _refreshUnread();
  }

  /// The unread count comes from the existing overview call (no new API). It is
  /// refreshed when the shell opens, on a tab switch, on coming back to the app
  /// and when a chat is closed, at most once every 15 seconds unless [force].
  /// It is never polled, so a hidden tab costs nothing.
  Future<void> _refreshUnread({bool force = false}) async {
    if (_fetchingUnread) return;
    final last = _lastUnreadAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _fetchingUnread = true;
    try {
      final overview = await WhatsAppService.overview();
      if (!mounted) return;
      _lastUnreadAt = DateTime.now();
      final unread = overview.conversations.unread;
      if (unread != _unread) setState(() => _unread = unread);
    } catch (_) {
      // No access or no connection: the badge just stays as it was.
    } finally {
      _fetchingUnread = false;
    }
  }

  Widget _tab(int i) {
    switch (i) {
      case _inboxTab:
        return WhatsAppInboxScreen(
          embedded: true,
          onUnreadMayHaveChanged: () => _refreshUnread(force: true),
        );
      case _contactsTab:
        return const WhatsAppContactsScreen(embedded: true);
      default:
        return WhatsAppScreen(onOpenInbox: () => _select(_inboxTab));
    }
  }

  @override
  Widget build(BuildContext context) {
    // With the keyboard open the bar would float above it and eat space.
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    final inboxLabel = _unread > 0 ? 'Inbox, $_unread unread' : 'Inbox';

    return Scaffold(
      backgroundColor: surface,
      body: FadeIndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _tabCount; i++)
            _visited.contains(i)
                ? WaTabScope(active: _index == i, child: _tab(i))
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                _select(i);
              },
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shadowColor: royalNavy.withValues(alpha: 0.25),
              indicatorColor: brand.withValues(alpha: 0.14),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              height: 68,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                  tooltip: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text(_unread > 99 ? '99+' : '$_unread'),
                    child: const Icon(Icons.forum_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: _unread > 0,
                    label: Text(_unread > 99 ? '99+' : '$_unread'),
                    child: const Icon(Icons.forum_rounded),
                  ),
                  label: 'Inbox',
                  tooltip: inboxLabel,
                ),
                const NavigationDestination(
                  icon: Icon(Icons.contacts_outlined),
                  selectedIcon: Icon(Icons.contacts_rounded),
                  label: 'Contacts',
                  tooltip: 'Contacts',
                ),
              ],
            ),
    );
  }
}
