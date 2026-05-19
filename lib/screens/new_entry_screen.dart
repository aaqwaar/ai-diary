import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../widgets/mood_selector.dart';

class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key});

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  final _textController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _geminiService = GeminiService();
  int _selectedMood = 3;
  bool _isSaving = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
  final text = _textController.text.trim();
  if (text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Napíš niečo do zápisku 📝'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  setState(() => _isSaving = true);

  bool tagsFailed = false;
  List<String> tags = [];

  try {
    // 1. Skús vygenerovať AI tagy
    try {
      tags = await _geminiService.generateTags(text);
      if (tags.isEmpty) {
        tagsFailed = true;
      }
    } catch (_) {
      tagsFailed = true;
    }

    // 2. Vytvor zápisok (s tagmi alebo bez nich)
    final entry = Entry(
      userId: FirebaseAuth.instance.currentUser!.uid,
      text: text,
      mood: _selectedMood,
      date: DateTime.now(),
      tags: tags,
    );

    await _firestoreService.createEntry(entry);

    if (!mounted) return;

    // 3. Zobraz jasnú správu podľa toho, čo sa stalo
    if (tags.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zápisok uložený s AI tagmi: ${tags.join(", ")} ✨'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (tagsFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'Zápisok uložený, ale AI tagy sa nepodarilo vygenerovať (limit/výpadok). Skús to neskôr.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zápisok uložený ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chyba pri ukladaní: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nový zápisok'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: MoodSelector(
                  selectedMood: _selectedMood,
                  onMoodSelected: (mood) =>
                      setState(() => _selectedMood = mood),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText:
                          'Aký bol tvoj deň? Napíš čo ťa zaujalo, potešilo, alebo trápilo...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveEntry,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'AI analyzuje a ukladá...' : 'Uložiť zápisok'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}