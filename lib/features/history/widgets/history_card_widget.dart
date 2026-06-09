import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/translation_entry.dart';
import '../../../shared/theme/app_theme.dart';

class HistoryCardWidget extends StatelessWidget {
  const HistoryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final TranslationEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.signLabel,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    entry.syncedToCloud
                        ? Icons.cloud_done_outlined
                        : Icons.schedule_outlined,
                    color: entry.syncedToCloud
                        ? AppTheme.primary
                        : AppTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: entry.confidence,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${(entry.confidence * 100).round()}% confidence'),
                  const Spacer(),
                  Text(_format(entry.timestamp)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(DateTime timestamp) {
    final now = DateTime.now();
    final local = timestamp.toLocal();
    final isToday = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    if (isToday) return 'Today, ${DateFormat.Hm().format(local)}';
    if (isYesterday) return 'Yesterday';
    return DateFormat.MMMd().format(local);
  }
}
