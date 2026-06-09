import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/model_update_service.dart';
import '../../shared/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _checking = false;

  Future<void> _checkForModelUpdate() async {
    setState(() => _checking = true);
    final modelUpdateService = context.read<ModelUpdateService>();
    final settingsProvider = context.read<SettingsProvider>();
    try {
      final available = await modelUpdateService.checkForUpdate();
      await settingsProvider.refreshLocalModelVersion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            available ? 'Model update is available.' : 'Model is up to date.',
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
              title: 'About',
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('App version'),
                  trailing: Text('1.0.0'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
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
