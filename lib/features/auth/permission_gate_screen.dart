import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/services/hive_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/brand_logo.dart';

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
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(child: BrandLogo(revealed: true, fontSize: 48)),
                const SizedBox(height: 32),
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Camera access needed',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  'NSL Translate uses the camera to read your signs and turn '
                  'them into text and speech. Nothing is uploaded until you '
                  'sign in and choose to contribute a sample.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 32),
                const _Bullet(
                  icon: Icons.photo_camera_outlined,
                  text: 'Reads your hand and body landmarks in real time',
                ),
                const _Bullet(
                  icon: Icons.shield_outlined,
                  text: 'Stays on your device unless you submit feedback',
                ),
                const _Bullet(
                  icon: Icons.notifications_outlined,
                  text: 'Notifies you when a new model is available',
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _requesting ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _requesting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Allow and continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _requesting ? null : () => context.go('/home'),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}