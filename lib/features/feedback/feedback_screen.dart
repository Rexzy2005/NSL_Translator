import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/feedback_entry.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sqlite_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const String _intro =
      "Help improve NSL Translate by labeling signs the app didn't recognize.";
  final TextEditingController _controller = TextEditingController();
  StreamSubscription<bool>? _connectivitySubscription;
  String? _selected;
  List<FeedbackEntry> _pending = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _connectivitySubscription = context
          .read<ConnectivityService>()
          .connectionStream
          .listen((online) async {
        if (!online || !mounted) return;
        final before = _pending.length;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await _load();
        final synced = before - _pending.length;
        if (synced > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Synced $synced items')),
          );
        }
      });
    });
  }

  Future<void> _load() async {
    final pending = await context.read<SqliteService>().getUnsynced();
    if (mounted) setState(() => _pending = pending);
  }

  Future<void> _submit() async {
    final label = (_controller.text.trim().isNotEmpty
            ? _controller.text.trim()
            : _selected)
        ?.trim();
    if (label == null || label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter or select a sign label.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<SqliteService>().insertFeedback(
            FeedbackEntry(
              signLabel: label,
              videoPath: 'pending_video',
              submittedAt: DateTime.now(),
              synced: false,
            ),
          );
      _controller.clear();
      _selected = null;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback saved for sync.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Feedback',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(_intro),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'What sign were you performing?',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Select known sign'),
              items: AppConstants.nslVocabulary
                  .map((label) =>
                      DropdownMenuItem(value: label, child: Text(label)))
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
            const SizedBox(height: 24),
            Chip(label: Text('${_pending.length} submissions pending sync')),
            const SizedBox(height: 8),
            if (_pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.flag_outlined, size: 48),
                    SizedBox(height: 12),
                    Text('No pending feedback.'),
                  ],
                ),
              )
            else
              ..._pending.map(
                (entry) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(entry.signLabel),
                    subtitle: Text(entry.submittedAt.toLocal().toString()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
