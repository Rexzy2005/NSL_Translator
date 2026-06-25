import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/models/translation_entry.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/services/hive_service.dart';
import '../../features/contribute/contribute_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/translation/translation_screen.dart';
import '../theme/app_theme.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _items = <_NavItem>[
    _NavItem(
      label: 'Translate',
      icon: Icons.photo_camera_outlined,
      activeIcon: Icons.photo_camera,
    ),
    _NavItem(
      label: 'History',
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
    ),
    _NavItem(
      label: 'Contribute',
      icon: Icons.video_call_outlined,
      activeIcon: Icons.video_call,
    ),
    _NavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hive = context.read<HiveService>();
    final pages = [
      TranslationScreen(isActive: _index == 0),
      const HistoryScreen(),
      const ContributeScreen(),
      const SettingsScreen(),
    ];
    return ValueListenableBuilder<Box<TranslationEntry>>(
      valueListenable: hive.translations.listenable(),
      builder: (context, box, _) {
        final unsyncedCount =
            box.values.where((entry) => !entry.syncedToCloud).length;
        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: IndexedStack(index: _index, children: pages),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: _AnimatedBottomBar(
              index: _index,
              items: _items,
              unsyncedCount: unsyncedCount,
              onTap: (value) {
                if (_index == 0 && value != 0) {
                  context.read<TranslationProvider>().stopTranslating();
                }
                setState(() => _index = value);
              },
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _AnimatedBottomBar extends StatelessWidget {
  const _AnimatedBottomBar({
    required this.index,
    required this.items,
    required this.unsyncedCount,
    required this.onTap,
  });

  final int index;
  final List<_NavItem> items;
  final int unsyncedCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final slot = width / items.length;
    final pillWidth = slot - 24;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            // Animated pill behind the active icon
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: 12 + (slot - pillWidth) / 2 + index * slot,
              top: 6,
              child: Container(
                width: pillWidth,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      active: i == index,
                      badge: i == 1 && unsyncedCount > 0 ? unsyncedCount : 0,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        active ? AppTheme.primary : AppTheme.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: badge > 0
                  ? Badge(
                      key: ValueKey('badge-$badge'),
                      label: Text('$badge'),
                      backgroundColor: AppTheme.primary,
                      child: Icon(
                        active ? item.activeIcon : item.icon,
                        key: ValueKey(active),
                        color: color,
                      ),
                    )
                  : Icon(
                      active ? item.activeIcon : item.icon,
                      key: ValueKey(active),
                      color: color,
                    ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}