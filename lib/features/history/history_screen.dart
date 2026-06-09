import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/translation_entry.dart';
import '../../core/providers/translation_provider.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/sync_service.dart';
import 'widgets/history_card_widget.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TranslationEntry> _items = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    _items = context.read<HiveService>().getAllTranslations();
  }

  Future<void> _refresh() async {
    final syncService = context.read<SyncService>();
    await syncService.syncTranslations();
    if (mounted) setState(_load);
  }

  Future<void> _delete(TranslationEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete translation?'),
        content: Text('Remove ${entry.signLabel} from history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      setState(_load);
      return;
    }
    if (!mounted) return;
    final hiveService = context.read<HiveService>();
    await hiveService.deleteTranslation(entry.id);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.history_outlined, size: 56),
                    SizedBox(height: 16),
                    Center(child: Text('No translations yet. Start signing.')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${_items.length} translations',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      );
                    }
                    final entry = _items[index - 1];
                    return Dismissible(
                      key: ValueKey(entry.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        await _delete(entry);
                        return false;
                      },
                      child: HistoryCardWidget(
                        entry: entry,
                        onTap: () => context
                            .read<TranslationProvider>()
                            .speak(entry.signLabel),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
