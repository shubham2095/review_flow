import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/session.dart';
import '../theme/brand.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_top_bar.dart';
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

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  List<Widget Function()> get _pageBuilders => [
        () => DashboardScreen(onNavigate: _select),
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
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pageBuilders.length; i++)
              _visited.contains(i) ? _pageBuilders[i]() : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: bottomIndex,
          onDestinationSelected: _select,
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
    );
  }
}
