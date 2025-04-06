import 'package:flutter/material.dart';
import '../services/zerotier_service.dart';
import '../l10n/app_localizations.dart'; // Import localizations
import '../models/peer_info.dart'; // Import the model

// class PeersPage extends StatelessWidget { // Convert to StatefulWidget
class PeersPage extends StatefulWidget {
  final ZerotierService zerotierService;
  // Remove callback parameter
  // final Future<void> Function()? onRefreshPeers;

  const PeersPage({
    super.key,
    required this.zerotierService,
    // Remove callback parameter from constructor
    // this.onRefreshPeers,
  });

  @override
  // State<PeersPage> createState() => _PeersPageState(); // Add createState
  State<PeersPage> createState() => _PeersPageState();
}

// Add State class
class _PeersPageState extends State<PeersPage> {
  bool _isLoading = false;
  // Use the PeerInfo model for the list
  List<PeerInfo> _peers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPeers(); // Call fetch method on init
  }

  // Helper to manage loading state
  void _setLoading(bool loading) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      if (loading) {
        _error = null; // Clear error when starting load
      }
    });
  }

  // Placeholder method to fetch peers
  Future<void> _fetchPeers() async {
    _setLoading(true);
    
    try {
      // 调用服务方法并获取返回值
      final peers = await widget.zerotierService.loadPeers();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          if (peers == null) {
            // ZeroTier服务不可用
            _error = l10n.serviceNotRunning;
            _peers = [];
          } else {
            _peers = List.from(peers);
            _error = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // 存储原始错误信息，不使用 l10n
        final rawError = e.toString();
        setState(() {
          // 在 setState 内部构建错误显示文本
          _error = rawError; // 存储原始错误，显示时再格式化
          _peers = [];
        });
        
        // 在确认 mounted 后使用 l10n 和 context
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.loadPeersErrorText(rawError)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  // Helper to build list item display
  Widget _buildPeerTile(PeerInfo peer, AppLocalizations l10n) {
    IconData roleIcon = peer.isPlanet ? Icons.cloud_outlined : Icons.computer_outlined;
    Color roleColor = peer.isPlanet ? Colors.blueGrey : Theme.of(context).colorScheme.secondary;

    // 设置tunneled状态显示
    final tunnelIcon = peer.tunneled ? Icons.settings_ethernet : Icons.wifi;
    final tunnelColor = peer.tunneled ? Colors.orange.shade700 : Colors.green.shade600;
    final tunnelText = peer.tunneled ? l10n.peerTunneled : l10n.peerDirect;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Icon(roleIcon, size: 20, color: roleColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                peer.address, 
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 对于非PLANET节点显示版本
            if (!peer.isPlanet && peer.version != null) ...[
              const SizedBox(width: 8),
              Text(
                peer.version!,
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.normal
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                 Chip(
                   avatar: Icon(roleIcon, size: 14, color: roleColor),
                   label: Text(peer.role, style: TextStyle(fontSize: 12, color: roleColor)),
                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                   visualDensity: VisualDensity.compact,
                   backgroundColor: roleColor.withOpacity(0.1),
                   side: BorderSide.none,
                 ),
                 const SizedBox(width: 8),
                 // 添加tunneled状态显示
                 Chip(
                   avatar: Icon(tunnelIcon, size: 14, color: tunnelColor),
                   label: Text(tunnelText, style: TextStyle(fontSize: 12, color: tunnelColor)),
                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                   visualDensity: VisualDensity.compact,
                   backgroundColor: tunnelColor.withOpacity(0.1),
                   side: BorderSide.none,
                 ),
                 const SizedBox(width: 8),
                 if (peer.latency != null) ...[
                   Icon(Icons.timer_outlined, size: 14, color: Colors.orange.shade700),
                   const SizedBox(width: 4),
                    Text('${peer.latency} ms', style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                 ],
              ],
            ),
             if (peer.preferredPath != null) ...[
                const SizedBox(height: 4),
                Text(
                  peer.preferredPath!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).disabledColor, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
             ]
          ],
        ),
        dense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    Widget bodyContent;

    if (_isLoading && _peers.isEmpty) {
      bodyContent = const Center(child: CircularProgressIndicator.adaptive());
    } else if (_error != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.loadPeersErrorText(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: Text(l10n.refreshButtonLabel),
                 onPressed: _isLoading ? null : _fetchPeers,
              )
            ],
          ),
        )
      );
    } else if (!_isLoading && _peers.isEmpty) {
       // Show "No peers found" centered, allowing pull-to-refresh
       bodyContent = LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.noPeersFound, // Uses existing l10n key
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).disabledColor
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
    } else {
      // Display the list using ListView.builder
      bodyContent = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollable even when few items
        itemCount: _peers.length,
        itemBuilder: (context, index) {
           return _buildPeerTile(_peers[index], l10n);
        },
      );
    }

    // Wrap the main content with RefreshIndicator
    return RefreshIndicator(
       onRefresh: _fetchPeers,
       child: bodyContent,
    );
  }
} 