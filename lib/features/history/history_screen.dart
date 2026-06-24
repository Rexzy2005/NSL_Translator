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
    final sessions = <String, List<TranslationEntry>>{};
    for (final entry in _items) {
      sessions.putIfAbsent(entry.sessionId, () => []).add(entry);
    }
    final sessionEntries = sessions.entries.toList()
      ..sort(
          (a, b) => b.value.first.timestamp.compareTo(a.value.first.timestamp));

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
                  itemCount: sessionEntries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          '${sessionEntries.length} sessions',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      );
                    }
                    final session = sessionEntries[index - 1];
                    final latest = session.value.first;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        initiallyExpanded: index == 1,
                        leading: const Icon(Icons.view_timeline_outlined),
                        title: Text(
                          _sessionTitle(latest.timestamp),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${session.value.length} translations'),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        children: session.value.map((entry) {
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
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _sessionTitle(DateTime timestamp) {
    final local = timestamp.toLocal();
    return 'Session ${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
