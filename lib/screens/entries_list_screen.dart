import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';
import 'entry_detail_screen.dart';

class EntriesListScreen extends StatefulWidget {
  const EntriesListScreen({super.key});

  @override
  State<EntriesListScreen> createState() => _EntriesListScreenState();
}

class _EntriesListScreenState extends State<EntriesListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int? _selectedMoodFilter; // null = všetky nálady

  static const moodEmojis = ['😢', '😕', '😐', '🙂', '😄'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Entry> _applyFilters(List<Entry> entries) {
    return entries.where((entry) {
      // Filter podľa nálady
      if (_selectedMoodFilter != null && entry.mood != _selectedMoodFilter) {
        return false;
      }

      // Filter podľa vyhľadávania (text alebo tag)
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final inText = entry.text.toLowerCase().contains(query);
        final inTags = entry.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!inText && !inTags) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Hľadať v zápiskoch...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),

        // Filter chipy podľa nálady
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Všetky'),
                  selected: _selectedMoodFilter == null,
                  onSelected: (_) {
                    setState(() => _selectedMoodFilter = null);
                  },
                  selectedColor: Colors.deepPurple.shade100,
                ),
              ),
              ...List.generate(5, (index) {
                final moodValue = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(moodEmojis[index],
                        style: const TextStyle(fontSize: 18)),
                    selected: _selectedMoodFilter == moodValue,
                    onSelected: (selected) {
                      setState(() =>
                          _selectedMoodFilter = selected ? moodValue : null);
                    },
                    selectedColor: Colors.deepPurple.shade100,
                  ),
                );
              }),
            ],
          ),
        ),

        // Zoznam zápiskov
        Expanded(
          child: StreamBuilder<List<Entry>>(
            stream: _firestoreService.entriesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Chyba: ${snapshot.error}'));
              }

              final allEntries = snapshot.data ?? [];
              final entries = _applyFilters(allEntries);

              if (allEntries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.book_outlined,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Zatiaľ žiadne zápisky',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('Stlač + a vytvor svoj prvý zápisok',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
                    ],
                  ),
                );
              }

              if (entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Žiadne výsledky',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text('Skús iné vyhľadávanie alebo filter',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500)),
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
                    margin: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                            style:
                                                const TextStyle(fontSize: 11)),
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
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
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
          ),
        ),
      ],
    );
  }
}