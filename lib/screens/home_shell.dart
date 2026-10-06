import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/brand.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_top_bar.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';
import 'admin_screen.dart';
import 'admin_shell.dart';
import 'ai_media_screen.dart';
import 'ai_tools_screen.dart';
import 'billing_screen.dart';
import 'tally_screen.dart';
import 'billing_settings_screen.dart';
import 'clients_screens.dart';
import 'credits_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'whatsapp_ads_screens.dart';
import 'customers_screen.dart';
import 'expenses_screen.dart';
import 'invoicing_screen.dart';
import 'leads_screen.dart';
import 'posts_photos_screen.dart';
import 'reviews_screen.dart';
import 'social_screen.dart';
import 'team_screen.dart';

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
  bool _isAdmin = false;
  // Super admin pehle admin layout dekhta hai. "User view" se client layout khulta hai.
  bool _adminMode = true;
  bool _meLoaded = false;

  // Bottom bar ke 5 tabs (0-4). Web (5) sirf drawer se khulta hai.
  // Tabs jo ek baar khul chuke hain. Inhe hi build karte hain.
  final Set<int> _visited = {0};

  void _select(int i) {
    setState(() {
      // Drawer ka "Admin panel" shortcut admin layout par le jata hai.
      if (i == 21) {
        _adminMode = true;
        return;
      }
      _index = i;
      _visited.add(i);
    });
  }

  List<Widget Function()> get _pageBuilders => [
        () => DashboardScreen(onSignedOut: widget.onSignedOut),
        () => ReviewsScreen(onSignedOut: widget.onSignedOut),
        () => LeadsScreen(onSignedOut: widget.onSignedOut),
        () => SocialScreen(onSignedOut: widget.onSignedOut),
        () => InsightsScreen(onSignedOut: widget.onSignedOut),
        () => TeamScreen(onSignedOut: widget.onSignedOut),
        () => InvoicingScreen(onSignedOut: widget.onSignedOut),
        () => PostsPhotosScreen(onSignedOut: widget.onSignedOut),
        () => CustomersScreen(onSignedOut: widget.onSignedOut),
        () => ExpensesScreen(onSignedOut: widget.onSignedOut),
        () => AiToolsScreen(onSignedOut: widget.onSignedOut),
        () => ClientsScreen(onSignedOut: widget.onSignedOut),
        () => ServicesScreen(onSignedOut: widget.onSignedOut),
        () => BillingSettingsScreen(onSignedOut: widget.onSignedOut),
        () => ProfileScreen(onSignedOut: widget.onSignedOut),
        () => WhatsappScreen(onSignedOut: widget.onSignedOut),
        () => AdsReportsScreen(onSignedOut: widget.onSignedOut),
        () => CreditsScreen(onSignedOut: widget.onSignedOut),
        () => BillingScreen(onSignedOut: widget.onSignedOut),
        () => TallyScreen(onSignedOut: widget.onSignedOut),
        () => AiMediaScreen(onSignedOut: widget.onSignedOut),
        // Admin screen sirf SUPER_ADMIN ke liye hai, baaki users ko API call nahi jaati.
        () => _isAdmin ? AdminScreen(onSignedOut: widget.onSignedOut) : const SizedBox.shrink(),
      ];

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
    'AI Tools',
    'Clients',
    'Services',
    'Billing settings',
    'Profile',
    'WhatsApp',
    'Ads Reports',
    'Credits',
    'Plans & billing',
    'Tally export',
    'AI media',
    'Admin panel',
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
        _isAdmin = me['role'] == 'SUPER_ADMIN';
        _meLoaded = true;
      });
    } catch (_) {
      // Naam nahi aaya to header mein default text dikhega.
      if (mounted) setState(() => _meLoaded = true);
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
    if (!_meLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAdmin && _adminMode) {
      return AdminShell(
        name: _name,
        email: _email,
        onSignedOut: widget.onSignedOut,
        onUserView: () => setState(() => _adminMode = false),
      );
    }

    final initial = _name.trim().isEmpty ? 'E' : _name.trim()[0].toUpperCase();
    // Web (index 5) par bottom bar mein koi tab highlight nahi hoga, isliye 4 ko clamp karte hain.
    final bottomIndex = _index > 4 ? 4 : _index;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: surface,
        // Drawer khulne par role dobara check karte hain, taaki pehli call fail hone par bhi admin item dikhe.
        onDrawerChanged: (open) {
          if (open) _loadMe();
        },
        appBar: AppTopBar(
          title: _titles[_index],
          initial: initial,
          onAvatarTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: AppDrawer(
          name: _name,
          email: _email,
          selectedIndex: _index,
          onSelect: _select,
          onLogout: _confirmLogout,
          isAdmin: _isAdmin,
        ),
        body: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pageBuilders.length; i++)
              // Tab tab build hota hai jab user pehli baar wahan jaye. Isse startup par saari API calls nahi chalti.
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
