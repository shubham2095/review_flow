import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_top_bar.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'customers_screen.dart';
import 'expenses_screen.dart';
import 'invoicing_screen.dart';
import 'leads_screen.dart';
import 'posts_photos_screen.dart';
import 'reviews_screen.dart';
import 'social_screen.dart';
import 'team_screen.dart';
import 'web_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  String _name = '';
  String _email = '';

  // Bottom bar ke 5 tabs (0-4). Web (5) sirf drawer se khulta hai.
  static const _titles = [
    'Dashboard',
    'Reviews',
    'Leads',
    'Social',
    'Insights',
    'Team',
    'Invoices',
    'Posts & Photos',
    'Customers',
    'Expenses',
    'Web',
  ];

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final me = await ApiService.instance.get('/me');
      if (!mounted) return;
      setState(() {
        _name = (me['name'] ?? '').toString();
        _email = (me['email'] ?? '').toString();
      });
    } catch (_) {
      // Naam nahi aaya to header mein default text dikhega.
    }
  }

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
    final initial = _name.trim().isEmpty ? 'E' : _name.trim()[0].toUpperCase();
    // Web (index 5) par bottom bar mein koi tab highlight nahi hoga, isliye 4 ko clamp karte hain.
    final bottomIndex = _index > 4 ? 4 : _index;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: brand,
        statusBarIconBrightness: Brightness.light,
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
          name: _name,
          email: _email,
          selectedIndex: _index,
          onSelect: (i) => setState(() => _index = i),
          onLogout: _confirmLogout,
        ),
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onSignedOut: widget.onSignedOut),
            ReviewsScreen(onSignedOut: widget.onSignedOut),
            LeadsScreen(onSignedOut: widget.onSignedOut),
            SocialScreen(onSignedOut: widget.onSignedOut),
            InsightsScreen(onSignedOut: widget.onSignedOut),
            TeamScreen(onSignedOut: widget.onSignedOut),
            InvoicingScreen(onSignedOut: widget.onSignedOut),
            PostsPhotosScreen(onSignedOut: widget.onSignedOut),
            CustomersScreen(onSignedOut: widget.onSignedOut),
            ExpensesScreen(onSignedOut: widget.onSignedOut),
            WebScreen(onSignedOut: widget.onSignedOut),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: bottomIndex,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review),
              label: 'Reviews',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Leads',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Social',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}
