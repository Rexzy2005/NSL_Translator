import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/model_update_service.dart';
import '../../core/services/sqlite_service.dart';
import '../../core/services/sync_service.dart';
import '../../shared/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checking = false;
  bool _syncing = false;
  bool _clearingHistory = false;
  bool _clearingContributions = false;

  Future<void> _checkForModelUpdate() async {
    setState(() => _checking = true);
    final modelUpdateService = context.read<ModelUpdateService>();
    final settingsProvider = context.read<SettingsProvider>();
    try {
      final available = await modelUpdateService.checkForUpdate();
      await settingsProvider.refreshLocalModelVersion();
      if (!mounted) return;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model is up to date.')),
        );
        return;
      }
      final shouldDownload = await _confirm(
        title: 'Model update available',
        message:
            'A newer trained model is available. Download and apply it now? '
            'The app will need to restart for the new model to load.',
        confirmLabel: 'Download',
      );
      if (!shouldDownload || !mounted) return;
      await modelUpdateService.downloadAndStageModel();
      if (!mounted) return;
      final shouldApply = await _confirm(
        title: 'Apply model update',
        message:
            'The new model is downloaded. Apply it now? '
            'The app must restart for the new model to take effect.',
        confirmLabel: 'Apply & restart',
      );
      if (!shouldApply || !mounted) return;
      await modelUpdateService.applyUpdate();
      await settingsProvider.refreshLocalModelVersion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Model applied. Please restart NSL Translate to use it.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _signOut() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signOut();
    if (mounted) context.go('/welcome');
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final synced = await context.read<SyncService>().performFullSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $synced pending item(s).')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm(
      title: 'Clear translation history?',
      message: 'This removes all saved local translation sessions.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearingHistory = true);
    try {
      await context.read<HiveService>().clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Translation history cleared.')),
      );
    } finally {
      if (mounted) setState(() => _clearingHistory = false);
    }
  }

  Future<void> _clearContributions() async {
    final confirmed = await _confirm(
      title: 'Clear pending contributions?',
      message:
          'This removes locally queued videos that have not been uploaded.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearingContributions = true);
    try {
      await context.read<SqliteService>().deleteAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pending contributions cleared.')),
      );
    } finally {
      if (mounted) setState(() => _clearingContributions = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Continue',
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final user = auth.currentUser;
    final metadata = user?.userMetadata ?? <String, dynamic>{};
    final displayName = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        'Guest User';
    final email = user?.email ?? 'Offline guest session';
    final avatarUrl =
        metadata['avatar_url'] as String? ?? metadata['picture'] as String?;
    final initials = displayName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Settings',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primary,
                      backgroundImage:
                          avatarUrl == null ? null : NetworkImage(avatarUrl),
                      child: avatarUrl == null
                          ? Text(
                              initials.isEmpty ? 'GU' : initials,
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.isAuthenticated ? displayName : 'Guest User',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(email),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: auth.isAuthenticated || auth.isGuest
                          ? _signOut
                          : () => context.go('/welcome'),
                      child: Text(
                        auth.isAuthenticated || auth.isGuest
                            ? 'Sign out'
                            : 'Sign in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Recognition settings',
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Confidence threshold')),
                    Text('${(settings.confidenceThreshold * 100).round()}%'),
                  ],
                ),
                Slider(
                  value: settings.confidenceThreshold,
                  min: 0.5,
                  max: 0.95,
                  divisions: 9,
                  label: '${(settings.confidenceThreshold * 100).round()}%',
                  onChanged: settings.setConfidenceThreshold,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Speech settings',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Text-to-speech'),
                  subtitle: const Text('Speak confident translations aloud.'),
                  value: settings.ttsEnabled,
                  onChanged: settings.setTtsEnabled,
                ),
                Row(
                  children: [
                    const Expanded(child: Text('TTS rate')),
                    Text(settings.ttsRate.toStringAsFixed(1)),
                  ],
                ),
                Slider(
                  value: settings.ttsRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  onChanged: settings.setTtsRate,
                ),
                DropdownButtonFormField<String>(
                  initialValue: settings.ttsLanguage,
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: const ['en-NG', 'en-US', 'en-GB']
                      .map(
                        (language) => DropdownMenuItem(
                          value: language,
                          child: Text(language),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) settings.setTtsLanguage(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Data and sync',
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Sync pending data'),
                  subtitle:
                      const Text('Upload translation history and sign videos.'),
                  trailing: _syncing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _syncing ? null : _syncNow,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history_toggle_off_outlined),
                  title: const Text('Clear local history'),
                  subtitle: const Text('Remove saved translation sessions.'),
                  trailing: _clearingHistory
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  onTap: _clearingHistory ? null : _clearHistory,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.video_file_outlined),
                  title: const Text('Clear pending contributions'),
                  subtitle: const Text('Remove videos waiting on this device.'),
                  trailing: _clearingContributions
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  onTap: _clearingContributions ? null : _clearContributions,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Model and app',
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text('App version'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: const Text('Model version'),
                  trailing: Text(settings.localModelVersion),
                ),
                ElevatedButton.icon(
                  onPressed: _checking ? null : _checkForModelUpdate,
                  icon: _checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_outlined),
                  label: const Text('Check for model update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
