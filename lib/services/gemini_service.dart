import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/entry_model.dart';

class GeminiService {
  static const String _baseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Hlavná metóda na volanie Gemini API
 Future<String> _generateContent(String prompt, {int maxTokens = 1000}) async {
  if (_apiKey.isEmpty) {
    print('❌ GEMINI_API_KEY nie je nastavený v .env');
    throw Exception('GEMINI_API_KEY nie je nastavený v .env');
  }

  final url = Uri.parse('$_baseUrl?key=$_apiKey');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': maxTokens,
        // Vypnutie "thinking" módu - inak Gemini 2.5 minie tokeny na premýšľanie
        // a odpoveď príde useknutá
        'thinkingConfig': {
          'thinkingBudget': 0,
        },
      }
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
        'Gemini API chyba: ${response.statusCode} - ${response.body}');
  }

  final data = jsonDecode(response.body);
  final text =
      data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
  return text.trim();
}

  // FEATURE 1: Auto-tagovanie zápisku
  Future<List<String>> generateTags(String entryText) async {
    final prompt = '''
Analyzuj nasledovný zápisok z denníka a vyextrahuj 2-3 hlavné témy/tagy.
Tagy musia byť v slovenčine, jednoslovné alebo dvojslovné, malými písmenami.
Príklady tagov: "práca", "rodina", "stres", "šport", "voľný čas", "vzťahy", "škola".

Zápisok:
"$entryText"

Odpoveď VRÁŤ LEN ako JSON pole stringov, bez ďalšieho textu. Príklad: ["práca", "stres"]
''';

    try {
      final response = await _generateContent(prompt, maxTokens: 400);

      print('✅ AI odpoveď na tagy: $response');

      // Vyčisti odpoveď od markdown ak nejakého
      final cleaned = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> tags = jsonDecode(cleaned);
      final tagsList = tags.map((e) => e.toString()).toList();
      print('🏷️ Vygenerované tagy: $tagsList');
      return tagsList;
    } catch (e) {
      print('❌ Chyba pri generovaní tagov: $e');
      return [];
    }
  }

  // FEATURE 2: AI reflexná otázka na základe posledných zápiskov
  Future<String> generateDailyQuestion(List<Entry> recentEntries) async {
  if (recentEntries.isEmpty) {
    return 'Ako sa dnes cítiš a čo ťa zaujalo?';
  }

  final context = recentEntries
      .take(5)
      .map((e) =>
          'Dátum: ${e.date.day}.${e.date.month}, Nálada: ${e.mood}/5, Text: "${e.text}"')
      .join('\n');

  final prompt = '''
Si empatický AI asistent v aplikácii denníka. Na základe posledných zápiskov užívateľa
vygeneruj JEDNU veľmi krátku, osobnú reflexnú otázku v slovenčine.

PRÍSNE PRAVIDLÁ:
- Maximálne 15 slov
- Maximálne 1 veta
- Žiadne úvody, žiadne vysvetlenia
- Len samotná otázka, nič iné

Posledné zápisky:
$context

Otázka:
''';

  try {
    var question = await _generateContent(prompt, maxTokens: 300);

    // Bezpečnostná hranica: ak by AI predsa vrátil dlhší text, oreže
    if (question.length > 300) {
      final firstSentence = question.split(RegExp(r'[.?!]')).first;
      question = '$firstSentence?';
    }

    return question;
  } catch (e) {
  print('❌ Chyba pri generovaní dennej otázky: $e');
  if (e.toString().contains('429')) {
    return '⏳ AI limit dosiahnutý. Skús refresh o minútu.';
  }
  return 'Čo by ti dnes spravilo radosť?';
}
}

  // FEATURE 3: Chat s denníkom - užívateľ sa pýta, AI odpovedá
  Future<String> chatWithDiary(
      String userQuestion, List<Entry> allEntries) async {
    if (allEntries.isEmpty) {
      return 'Zatiaľ nemáš žiadne zápisky, takže ti nemôžem nič o nich povedať. Napíš svoj prvý zápisok! 📝';
    }

    final context = allEntries
        .take(20)
        .map((e) =>
            'Dátum: ${e.date.day}.${e.date.month}.${e.date.year}, Nálada: ${e.mood}/5, Zápisok: "${e.text}"')
        .join('\n');

    final prompt = '''
Si empatický AI asistent, ktorý pomáha užívateľovi reflektovať jeho denníkové zápisky.
Odpovedaj v slovenčine, prirodzene a osobne. Ak otázka súvisí s konkrétnym dátumom,
spomeň ho. Buď stručný (max 3-4 vety).

Zápisky užívateľa:
$context

Otázka užívateľa: "$userQuestion"

Tvoja odpoveď:
''';

    try {
      return await _generateContent(prompt, maxTokens: 1000);
    } catch (e) {
  print('❌ Chyba pri chate s denníkom: $e');
  if (e.toString().contains('429')) {
    return '⏳ AI poslala priveľa správ. Počkaj minútku a skús znova. 🙏';
  }
  return 'Prepáč, momentálne neviem odpovedať. Skús to znova. 🙏';
}
  }
  // FEATURE 4: Týždenná self-reflexia
Future<String> generateWeeklySummary(List<Entry> entries) async {
  // Filtruj zápisky z posledných 7 dní
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  final weekEntries = entries.where((e) => e.date.isAfter(weekAgo)).toList();

  if (weekEntries.isEmpty) {
    return 'Tento týždeň zatiaľ nemáš žiadne zápisky. Začni dnes písať a o týždeň sa vrátim s reflexiou! 📝';
  }

  final context = weekEntries
      .map((e) =>
          'Dátum: ${e.date.day}.${e.date.month}, Nálada: ${e.mood}/5, Text: "${e.text}"')
      .join('\n');

  final avgMood =
      weekEntries.map((e) => e.mood).reduce((a, b) => a + b) / weekEntries.length;

  final prompt = '''
Si empatický AI asistent. Užívateľ chce reflexiu svojho posledného týždňa
na základe zápiskov v denníku. Napíš mu osobné, hutné zhrnutie v slovenčine.

ŠTRUKTÚRA odpovede (presne v tomto formáte, použij emoji):

📊 PREHĽAD TÝŽDŇA
[2-3 vety o tom, aký bol týždeň celkovo - dominantné nálady, energia, dianie]

🎯 HLAVNÉ TÉMY
[3-4 odrážky s témami, ktoré sa najviac opakovali. Format: "• téma - krátky popis"]

💡 POZOROVANIA
[2-3 vety s tým, čo si AI všimol - vzorce, trendy, niečo zaujímavé]

🌱 ODPORÚČANIE NA ĎALŠÍ TÝŽDEŇ
[1-2 konkrétne odporúčania, na čo by sa mal zamerať]

Zápisky z týždňa ($weekEntries.length zápiskov, priemerná nálada: ${avgMood.toStringAsFixed(1)}/5):
$context

Píš osobne ("ty/ti"), nie všeobecne. Žiadne úvody typu "Tu je reflexia:".
''';

  try {
    return await _generateContent(prompt, maxTokens: 2000);
  } catch (e) {
  print('❌ Chyba pri generovaní týždennej reflexie: $e');
  if (e.toString().contains('429')) {
    return '⏳ AI limit dosiahnutý (free tier: max 15 requestov/min). Skús to o minútu znova. 🙏';
  }
  return 'Prepáč, momentálne neviem vygenerovať reflexiu. Skús to znova. 🙏';
}
}
}