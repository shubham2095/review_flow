import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_store.dart';
import '../services/products.dart';
import '../services/push_service.dart';
import '../services/whatsapp_service.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/fade_indexed_stack.dart';
import '../widgets/offline_banner.dart';
import 'ai_tools_screen.dart';
import 'automation_screen.dart';
import 'billing_screen.dart';
import 'business_profile_screen.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'pages.dart';
import 'posts_photos_screen.dart';
import 'profile_screen.dart';
import 'team_screen.dart';
import 'reviews_screen.dart';
import '../models/whatsapp_models.dart';
import 'wa_destinations.dart';
import 'whatsapp_chat_screen.dart';
import 'whatsapp_inbox_screen.dart';
import 'whatsapp_shell.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.product,
    required this.onSignedOut,
    required this.onHub,
  });

  /// The product that was opened from the boxes: it decides which pages exist.
  final Product product;
  final VoidCallback onSignedOut;

  /// Back to the product boxes.
  final VoidCallback onHub;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  /// The page this product starts on.
  int get _start =>
      widget.product == Product.whatsapp ? kPageWhatsApp : kPageOverview;

  late int _index = _start;

  // Pages open for the first time only, so startup does not fire every API call.
  late final Set<int> _visited = {_start};

  @override
  void initState() {
    super.initState();
    // Best effort: the switcher list for every module. A failure just means the
    // Overview fills it later.
    LocationStore.refresh().catchError((_) {});
    ApiService.reconnected.addListener(_onReconnected);
    PushService.target.addListener(_onPush);
    _waCurrent.addListener(_onWaPlace);
    // A notification that opened this product: go to its page.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPush());
  }

  @override
  void dispose() {
    ApiService.reconnected.removeListener(_onReconnected);
    PushService.target.removeListener(_onPush);
    _waCurrent
      ..removeListener(_onWaPlace)
      ..dispose();
    _waUnread.dispose();
    super.dispose();
  }

  /// The connection came back after saved data was shown: say so, and bring the
  /// Overview up to date. Other pages refresh when pulled down.
  void _onReconnected() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text("You're back online. Pull down to refresh a page."),
        ),
      );
    _dashboardKey.currentState?.reload();
  }

  /// A tapped notification: go to the page it is about.
  Future<void> _onPush() async {
    final t = PushService.target.value;
    if (t == null || !mounted) return;
    // About the other product: go back to the boxes, which open it.
    final mine = widget.product == Product.gbp ? t.isReview : !t.isReview;
    if (!mine) {
      widget.onHub();
      return;
    }
    PushService.target.value = null;
    if (t.isReview) {
      _select(kPageReviews);
      return;
    }
    _select(kPageWhatsApp);
    final nav = Navigator.of(context);
    if (t.isChat) {
      WaConversation? c;
      try {
        c = await WhatsAppService.findConversation(t.conversationId!);
      } catch (_) {}
      if (!mounted) return;
      nav.push<void>(
        MaterialPageRoute(
          builder: (_) => c == null
              ? const WhatsAppInboxScreen()
              : WhatsAppChatScreen(conversation: c),
        ),
      );
    } else if (t.isLeadHandoff) {
      nav.push<void>(
        MaterialPageRoute(builder: (_) => const WhatsAppInboxScreen()),
      );
    }
  }

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _whatsAppKey = GlobalKey<WhatsAppShellState>();

  /// Where the person is inside WhatsApp, and the unread count: the drawer
  /// highlights the place and the top bar names it.
  final _waCurrent = ValueNotifier<WaDestination>(WaDestination.home);
  final _waUnread = ValueNotifier<int>(0);

  void _onWaPlace() {
    if (mounted) setState(() {});
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
    // Back on Overview: numbers may have moved (replies, posts) since it loaded.
    if (i == kPageOverview) _dashboardKey.currentState?.refreshIfStale();
  }

  /// Back goes to the product's first page from any other page, and from there
  /// to the product boxes. (Sheets, dialogs and the drawer close first, they are
  /// handled before this runs.)
  void _onBack() {
    // In WhatsApp, Back first goes from another tab (Inbox) to its Home tab.
    if (_index == kPageWhatsApp &&
        (_whatsAppKey.currentState?.goBackWithinShell() ?? false)) {
      return;
    }
    if (_index != _start) {
      _select(_start);
      return;
    }
    widget.onHub();
  }

  List<Widget Function()> get _pageBuilders => [
    () => DashboardScreen(key: _dashboardKey, onNavigate: _select),
    () => ReviewsScreen(onNavigate: _select),
    () => PostsPhotosScreen(onNavigate: _select),
    () => InsightsScreen(onNavigate: _select),
    () => AiToolsScreen(onNavigate: _select),
    () => const BusinessProfileScreen(),
    () => const AutomationScreen(),
    () => const BillingScreen(),
    () => ProfileScreen(onSignedOut: widget.onSignedOut),
    () => WhatsAppShell(
      key: _whatsAppKey,
      current: _waCurrent,
      unread: _waUnread,
    ),
    () => const TeamScreen(),
  ];

  static const _titles = [
    'Overview',
    'Reviews',
    'Posts & Photos',
    'Insights',
    'AI Tools',
    'Business profile',
    'Automation',
    'Plans & billing',
    'My Profile',
    'WhatsApp',
    'Team',
  ];

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your session will end on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.logout();
    if (mounted) widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.current;
    final name = user?.name ?? '';
    final initial = name.trim().isEmpty ? 'E' : name.trim()[0].toUpperCase();
    // Pages after the first five live in the drawer only; the bottom bar keeps the last tab.
    final bottomIndex = _index > kPageAiTools ? kPageAiTools : _index;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBack();
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: surface,
          appBar: AppTopBar(
            title: _index == kPageWhatsApp
                ? _waCurrent.value.title
                : _titles[_index],
            initial: initial,
            onAvatarTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          drawer: AppDrawer(
            name: name,
            email: user?.email ?? '',
            selectedIndex: _index,
            onSelect: _select,
            onLogout: _confirmLogout,
            product: widget.product,
            onHub: widget.onHub,
            waCurrent: _waCurrent,
            waUnread: _waUnread,
            onWhatsApp: (d) {
              // The shell exists once WhatsApp has been shown; right after
              // switching to it, wait one frame for it to be built.
              final state = _whatsAppKey.currentState;
              if (state != null) {
                state.open(d);
              } else {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _whatsAppKey.currentState?.open(d),
                );
              }
            },
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: FadeIndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < _pageBuilders.length; i++)
                      _visited.contains(i)
                          ? _pageBuilders[i]()
                          : const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: widget.product != Product.gbp
              ? null
              : NavigationBar(
            selectedIndex: bottomIndex,
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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.rate_review_outlined),
                selectedIcon: Icon(Icons.rate_review),
                label: 'Reviews',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: 'Posts',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Insights',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'AI Tools',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
