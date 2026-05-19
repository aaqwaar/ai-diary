import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';

class EntryDetailScreen extends StatelessWidget {
  final Entry entry;

  const EntryDetailScreen({super.key, required this.entry});

  static const moodEmojis = ['😢', '😕', '😐', '🙂', '😄'];
  static const moodLabels = ['Veľmi zle', 'Zle', 'Neutrálne', 'Dobre', 'Skvelo'];

  Future<void> _deleteEntry(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vymazať zápisok?'),
        content: const Text('Táto akcia sa nedá vrátiť.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );

    if (confirmed == true && entry.id != null) {
      try {
        await FirestoreService().deleteEntry(entry.id!);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zápisok vymazaný'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Chyba: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zápisok'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteEntry(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(moodEmojis[entry.mood - 1],
                        style: const TextStyle(fontSize: 48)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, d. MMMM yyyy', 'sk')
                                .format(entry.date),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nálada: ${moodLabels[entry.mood - 1]}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          Text(
                            DateFormat('HH:mm').format(entry.date),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  entry.text,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.label_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Tagy (AI)',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: entry.tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  backgroundColor: Colors.deepPurple.shade50,
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}