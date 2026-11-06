import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_store.dart';
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
import 'reviews_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = kPageOverview;

  // Pages open for the first time only, so startup does not fire every API call.
  final Set<int> _visited = {kPageOverview};

  @override
  void initState() {
    super.initState();
    // Best effort: the switcher list for every module. A failure just means the
    // Overview fills it later.
    LocationStore.refresh().catchError((_) {});
    ApiService.reconnected.addListener(_onReconnected);
  }

  @override
  void dispose() {
    ApiService.reconnected.removeListener(_onReconnected);
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

  DateTime? _lastBack;

  final _dashboardKey = GlobalKey<DashboardScreenState>();

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
    // Back on Overview: numbers may have moved (replies, posts) since it loaded.
    if (i == kPageOverview) _dashboardKey.currentState?.refreshIfStale();
  }

  /// Back goes to Overview from any other page; on Overview a second press
  /// within 2 seconds leaves the app. (Sheets, dialogs and the drawer close
  /// first, they are handled before this runs.)
  void _onBack() {
    if (_index != kPageOverview) {
      _select(kPageOverview);
      return;
    }
    final now = DateTime.now();
    final last = _lastBack;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  List<Widget Function()> get _pageBuilders => [
    () => DashboardScreen(key: _dashboardKey, onNavigate: _select),
    () => ReviewsScreen(onNavigate: _select),
    () => PostsPhotosScreen(onNavigate: _select),
    () => InsightsScreen(onNavigate: _select),
    () => const AiToolsScreen(),
    () => const BusinessProfileScreen(),
    () => const AutomationScreen(),
    () => const BillingScreen(),
    () => ProfileScreen(onSignedOut: widget.onSignedOut),
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
            title: _titles[_index],
            initial: initial,
            onAvatarTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          drawer: AppDrawer(
            name: name,
            email: user?.email ?? '',
            selectedIndex: _index,
            onSelect: _select,
            onLogout: _confirmLogout,
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
          bottomNavigationBar: NavigationBar(
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
