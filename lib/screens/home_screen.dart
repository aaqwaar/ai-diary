import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import 'new_entry_screen.dart';
import 'entries_list_screen.dart';
import 'chat_screen.dart';
import 'weekly_summary_screen.dart';
import '../main.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const _HomeTab(),
    const EntriesListScreen(),
    const StatsScreen(),
  ];

  final List<String> _titles = ['Domov', 'Zápisky', 'Štatistiky'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
  // Toggle tmavá/svetlá téma
  ValueListenableBuilder<ThemeMode>(
    valueListenable: themeNotifier,
    builder: (context, mode, _) {
      return IconButton(
        icon: Icon(mode == ThemeMode.dark
            ? Icons.light_mode
            : Icons.dark_mode),
        tooltip: mode == ThemeMode.dark ? 'Svetlý režim' : 'Tmavý režim',
        onPressed: () {
          themeNotifier.value = mode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        },
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.logout),
    onPressed: () async => await AuthService().signOut(),
  ),
],
      ),
      body: _tabs[_currentIndex],
      floatingActionButton: _currentIndex != 2
          ? FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewEntryScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Domov'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book),
              label: 'Zápisky'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Štatistiky'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _firestoreService = FirestoreService();
  final _geminiService = GeminiService();

  String? _dailyQuestion;
  bool _loadingQuestion = false;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    // Daily question sa negeneruje automaticky - šetríme API limit
    // Užívateľ klikne na "Vygenerovať" tlačidlo manuálne
  }

  Future<void> _loadStreak() async {
    try {
      final streak = await _firestoreService.calculateStreak();
      if (mounted) setState(() => _streak = streak);
    } catch (_) {}
  }

  Future<void> _generateDailyQuestion() async {
    setState(() => _loadingQuestion = true);
    try {
      final entries = await _firestoreService.entriesStream().first;
      final question = await _geminiService.generateDailyQuestion(entries);
      if (!mounted) return;
      setState(() {
        _dailyQuestion = question;
        _loadingQuestion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dailyQuestion = 'Ako sa dnes cítiš a čo ťa zaujalo?';
        _loadingQuestion = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Uvítacia karta s username a streakom
          StreamBuilder<String?>(
            stream: _firestoreService.usernameStream(),
            builder: (context, snapshot) {
              final username = snapshot.data ?? 'Priateľ';
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vitaj späť, $username! 👋',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  FirebaseAuth.instance.currentUser?.email ??
                                      '',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_streak > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_streak ${_streak == 1 ? "deň" : (_streak < 5 ? "dni" : "dní")}',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (_streak == 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '✍️ Napíš dnešný zápisok a začni svoj streak!',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // AI denná otázka - manuálne generovanie
          Card(
            elevation: 2,
            color: Colors.deepPurple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('AI Reflexná otázka',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (_dailyQuestion != null)
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: Colors.deepPurple),
                          onPressed:
                              _loadingQuestion ? null : _generateDailyQuestion,
                          tooltip: 'Nová otázka',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loadingQuestion)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.deepPurple),
                        ),
                        SizedBox(width: 12),
                        Text('AI premýšľa nad otázkou...',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey)),
                      ],
                    )
                  else if (_dailyQuestion == null)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Klikni pre vygenerovanie personalizovanej AI otázky podľa tvojich zápiskov',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _generateDailyQuestion,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Vygenerovať otázku'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      _dailyQuestion!,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Karta na otvorenie Chat s denníkom
          Card(
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.chat_bubble_outline,
                          color: Colors.deepPurple, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat s denníkom',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            'Pýtaj sa AI o svojich zápiskoch',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Karta na otvorenie Týždennej reflexie
          Card(
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const WeeklySummaryScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.insights,
                          color: Colors.green, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Týždenná reflexia',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text(
                            'AI zhrnie tvoj posledný týždeň',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tip dole
          Center(
            child: Column(
              children: [
                Icon(Icons.edit_note,
                    size: 50, color: Colors.deepPurple.shade300),
                const SizedBox(height: 8),
                Text('Stlač + pre nový zápisok',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}