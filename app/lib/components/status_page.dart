import 'package:flutter/material.dart';
import '../services/zerotier_service.dart';
import '../l10n/app_localizations.dart';

class StatusPage extends StatefulWidget {
  final ZerotierService zerotierService;

  const StatusPage({
    super.key, 
    required this.zerotierService,
  });

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  bool _isLoading = false;
  ZerotierStatus? _statusInfo;
  bool _isModuleInstalled = true;

  @override
  void initState() {
    super.initState();
    
    // 获取缓存的状态信息，如果有则直接使用
    final cachedStatus = widget.zerotierService.statusInfo;
    if (cachedStatus != null) {
      _statusInfo = cachedStatus;
      _isModuleInstalled = true;
    }
    
    // 然后异步更新状态
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    if (!mounted) return;
    
    // 检查是否有缓存的状态
    final cachedStatus = widget.zerotierService.statusInfo;
    final bool hasCache = cachedStatus != null;
    
    // 如果没有缓存或者当前状态为空，才显示加载中
    if (!hasCache || _statusInfo == null) {
      setState(() => _isLoading = true);
    }

    try {
      final status = await widget.zerotierService.loadStatus();
      if (mounted) {
        setState(() {
          _statusInfo = status;
          _isModuleInstalled = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load status: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performServiceAction(String command) async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);
    
    final l10n = AppLocalizations.of(context)!;
    String actionVerb = command;
    if (command == 'start') actionVerb = 'Starting';
    if (command == 'stop') actionVerb = 'Stopping';
    if (command == 'restart') actionVerb = 'Restarting';
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$actionVerb ZeroTier...'), duration: const Duration(seconds: 1)),
      );
      
      final success = await widget.zerotierService.zerotierCommand(command);
      
      if (!success && mounted) {
        setState(() {
          _isModuleInstalled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.moduleNotRunning),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$command failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        await _fetchStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cachedStatus = widget.zerotierService.statusInfo;
    final bool runningStatus = (_statusInfo != null && _statusInfo!.online) || 
                               (cachedStatus != null && cachedStatus.online && _statusInfo == null);
    final statusColor = runningStatus ? Colors.green.shade400 : Colors.red.shade400;
    final l10n = AppLocalizations.of(context)!;
    
    return RefreshIndicator(
      onRefresh: _fetchStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Column(
                children: [
                  _buildStatusIcon(runningStatus),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusText(context, runningStatus, theme, l10n),
                      IconButton(
                        icon: Icon(Icons.refresh, color: theme.colorScheme.secondary),
                        onPressed: _isLoading ? null : _fetchStatus,
                        tooltip: l10n.refreshStatusTooltip,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            _ActionButtons(
              l10n: l10n,
              startFunction: () => _performServiceAction('start'),
              restartFunction: () => _performServiceAction('restart'),
              stopFunction: () => _performServiceAction('stop'),
              isServiceRunning: runningStatus,
              isModuleInstalled: _isModuleInstalled,
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: CircularProgressIndicator(),
              ))
            else if (_statusInfo != null && runningStatus)
              _buildStatusInfo(context, _statusInfo!)
            else if (cachedStatus != null && cachedStatus.online)
              _buildStatusInfo(context, cachedStatus)
            else
               Center(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       _buildErrorText(context, theme, l10n),
                     ],
                   ),
                 )
              )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(bool runningStatus) {
    IconData iconData;
    Color iconColor;
    
    if (!_isModuleInstalled) {
      iconData = Icons.error;
      iconColor = Colors.orange.shade700;
    } else if (runningStatus) {
      iconData = Icons.play_circle_fill;
      iconColor = Colors.green.shade400;
    } else {
      iconData = Icons.stop_circle;
      iconColor = Colors.red.shade400;
    }
    
    return Icon(
      iconData,
      color: iconColor,
      size: 64,
    );
  }
  
  Widget _buildStatusText(BuildContext context, bool runningStatus, ThemeData theme, AppLocalizations l10n) {
    String statusText;
    Color textColor;
    
    if (!_isModuleInstalled) {
      statusText = l10n.moduleNotRunning;
      textColor = Colors.orange.shade700;
    } else if (runningStatus) {
      statusText = l10n.statusRunning;
      textColor = Colors.green.shade400;
    } else {
      statusText = l10n.statusStopped;
      textColor = Colors.red.shade400;
    }
    
    if (_isLoading) {
      textColor = textColor.withOpacity(0.5);
    }
    
    return Text(
      statusText,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.bold
      ),
    );
  }

  Widget _buildErrorText(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    String errorText;
    Color textColor;
    
    if (!_isModuleInstalled) {
      errorText = l10n.moduleNotRunning;
      textColor = Colors.orange.shade700;
    } else {
      errorText = l10n.statusStopped;
      textColor = theme.colorScheme.error;
    }
    
    return Text(
      errorText, 
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusInfo(BuildContext context, ZerotierStatus status) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statusDetailsTitle,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
          ),
          const Divider(height: 20, thickness: 1),
          _buildInfoTile(context, Icons.lan_outlined, l10n.nodeAddressLabel, status.address),
          _buildInfoTile(context, Icons.info_outline, l10n.softwareVersionLabel, status.version),
          _buildInfoTile(context, status.online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, l10n.onlineStatusLabel, status.online ? l10n.onlineStatusOnline : l10n.onlineStatusOffline),
          _buildInfoTile(context, Icons.settings_ethernet, l10n.primaryPortLabel, status.primaryPort.toString()),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.list_alt, color: theme.colorScheme.secondary),
            title: Text(l10n.listeningAddressesLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
          Container(
            height: 100,
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: status.listeningOn.isEmpty
              ? Center(child: Text(l10n.noListeningAddresses, style: theme.textTheme.bodySmall))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: status.listeningOn.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        status.listeningOn[index],
                        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoTile(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.secondary),
      title: Text(label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
      subtitle: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final AppLocalizations l10n;
  final Function()? startFunction;
  final Function()? restartFunction;
  final Function()? stopFunction;
  final bool isServiceRunning;
  final bool isModuleInstalled;

  const _ActionButtons({
    required this.l10n,
    required this.startFunction,
    required this.restartFunction,
    required this.stopFunction,
    required this.isServiceRunning,
    required this.isModuleInstalled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: <Widget>[
          Center(
            child: SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: isServiceRunning || !isModuleInstalled ? null : startFunction,
                label: Text(l10n.startButton),
                icon: const Icon(Icons.play_arrow),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: isServiceRunning && isModuleInstalled ? restartFunction : null,
                label: Text(l10n.restartButton),
                icon: const Icon(Icons.restart_alt),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 180,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 12)
                ),
                onPressed: isServiceRunning && isModuleInstalled ? stopFunction : null,
                label: Text(l10n.stopButton),
                icon: const Icon(Icons.stop),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 