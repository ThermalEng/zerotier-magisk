import 'package:flutter/material.dart';
import '../services/zerotier_service.dart';
import '../components/status_page.dart';
import '../components/network_page.dart';
import '../components/peers_page.dart';
import '../l10n/app_localizations.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ZerotierService _zerotierService = ZerotierService();
  int currentPageIndex = 0;
  // Remove state related to specific page data/futures
  // Future<void>? _networkFuture;
  // Future<void>? _peersFuture;

  @override
  void initState() {
    super.initState();
    // No initial loading needed here anymore
  }
  
  @override
  void dispose() {
    // Release service resources
    _zerotierService.dispose();
    super.dispose();
  }

  // Remove all data loading and action methods
  /*
  Future<void> _loadStatus() async { ... }
  Future<void> _loadNetworkList() async { ... }
  Future<void> _loadPeers() async { ... }
  Future<void> _startZeroTier() async { ... }
  Future<void> _restartZeroTier() async { ... }
  Future<void> _stopZeroTier() async { ... }
  Future<void> _joinNetwork(String id) async { ... }
  Future<void> _leaveNetwork(String id) async { ... }
  */

  String _getTitle(AppLocalizations l10n) {
    switch (currentPageIndex) {
      case 0:
        return l10n.appBarTitleStatus;
      case 1:
        return l10n.appBarTitleNetworks;
      case 2:
        return l10n.appBarTitlePeers;
      default:
        return 'ZeroTier';
    }
  }

  Widget _getCurrentPage() {
    switch (currentPageIndex) {
      case 0:
        // Pass only the service
        return StatusPage(
          zerotierService: _zerotierService,
          // Remove callbacks
          // onRefreshStatus: _loadStatus,
          // startFunction: _startZeroTier,
          // restartFunction: _restartZeroTier,
          // stopFunction: _stopZeroTier,
        );
      case 1:
         // Pass only the service
        return NetworkPage(
          zerotierService: _zerotierService,
          // Remove callbacks
          // onRefreshNetworkList: _loadNetworkList,
          // onJoinNetwork: _joinNetwork,
          // onLeaveNetwork: _leaveNetwork,
        );
      case 2:
         // Pass only the service
        return PeersPage(
          zerotierService: _zerotierService,
          // Remove callbacks
          // onRefreshPeers: _loadPeers,
        );
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get AppLocalizations instance
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(_getTitle(l10n))),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: const Icon(Icons.home),
            icon: const Icon(Icons.home_outlined),
            label: l10n.navBarLabelStatus,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.router),
            icon: const Icon(Icons.router_outlined),
            label: l10n.navBarLabelNetworks,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.people_alt),
            icon: const Icon(Icons.people_alt_outlined),
            label: l10n.navBarLabelPeers,
          ),
        ],
      ),
      body: _getCurrentPage(),
    );
  }
} 