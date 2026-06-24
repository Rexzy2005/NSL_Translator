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

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

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
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: _index,
              onTap: (value) {
                if (_index == 0 && value != 0) {
                  context.read<TranslationProvider>().stopTranslating();
                }
                setState(() => _index = value);
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.photo_camera_outlined),
                  activeIcon: Icon(Icons.photo_camera),
                  label: 'Translate',
                ),
                BottomNavigationBarItem(
                  icon: Badge(
                    isLabelVisible: unsyncedCount > 0,
                    label: Text('$unsyncedCount'),
                    child: const Icon(Icons.history_outlined),
                  ),
                  activeIcon: Badge(
                    isLabelVisible: unsyncedCount > 0,
                    label: Text('$unsyncedCount'),
                    child: const Icon(Icons.history),
                  ),
                  label: 'History',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.video_call_outlined),
                  activeIcon: Icon(Icons.video_call),
                  label: 'Contribute',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
