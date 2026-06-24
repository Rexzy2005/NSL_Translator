import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/services/hive_service.dart';
import '../../shared/theme/app_theme.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen> {
  bool _requesting = false;

  Future<void> _continue() async {
    final hiveService = context.read<HiveService>();
    setState(() => _requesting = true);
    await [Permission.camera, Permission.notification].request();
    await hiveService.saveStringSetting('permissions_done', 'true');
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.verified_user_outlined,
                  color: AppTheme.primary, size: 72),
              const SizedBox(height: 24),
              Text(
                'Enable app permissions',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                'NSL Translate needs camera access for recognition and notification permission for sync and model update alerts.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _requesting ? null : _continue,
                child: _requesting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Allow and continue'),
              ),
              TextButton(
                onPressed: _requesting ? null : () => context.go('/home'),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
