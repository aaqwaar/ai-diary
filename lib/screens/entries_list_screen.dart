import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';
import 'entry_detail_screen.dart';

class EntriesListScreen extends StatelessWidget {
  EntriesListScreen({super.key});

  final FirestoreService _firestoreService = FirestoreService();

  static const moodEmojis = ['😢', '😕', '😐', '🙂', '😄'];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: _firestoreService.entriesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Chyba: ${snapshot.error}'));
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.book_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Zatiaľ žiadne zápisky',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Stlač + a vytvor svoj prvý zápisok',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Text(moodEmojis[entry.mood - 1],
                    style: const TextStyle(fontSize: 32)),
                title: Text(
                  DateFormat('d. MMMM yyyy', 'sk').format(entry.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(entry.text,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (entry.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: entry.tags
                            .map((tag) => Chip(
                                  label: Text(tag,
                                      style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
                trailing: Text(
                  DateFormat('HH:mm').format(entry.date),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EntryDetailScreen(entry: entry),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}