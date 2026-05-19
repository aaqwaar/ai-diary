import 'package:flutter/material.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _firestoreService = FirestoreService();
  final _geminiService = GeminiService();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  List<Entry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    // Načítaj zápisky (pre kontext pre AI)
    try {
      _entries = await _firestoreService.entriesStream().first;
    } catch (e) {
      // Continue with empty entries
    }

    // Načítaj uloženú chat históriu
    try {
      final savedMessages = await _firestoreService.getChatMessages();
      if (savedMessages.isNotEmpty) {
        // Načítaj všetky uložené správy
        for (final msg in savedMessages) {
          _messages.add(_ChatMessage(
            text: msg['text'] ?? '',
            isUser: msg['isUser'] ?? false,
          ));
        }
      } else {
        // Privítacia správa ak je chat prázdny
        _messages.add(_ChatMessage(
          text:
              'Ahoj! 👋 Som tvoj AI denníkový asistent. Môžeš sa ma pýtať otázky o svojich zápiskoch.\n\nNapríklad:\n• "Kedy som bol naposledy šťastný?"\n• "Čo ma posledne najviac stresovalo?"\n• "Akú náladu som mal tento týždeň?"',
          isUser: false,
        ));
      }
    } catch (e) {
      _messages.add(_ChatMessage(
        text:
            'Ahoj! 👋 Som tvoj AI denníkový asistent. Spýtaj sa ma niečo o svojich zápiskoch.',
        isUser: false,
      ));
    }

    if (mounted) {
      setState(() => _isInitializing = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final userMessage = _ChatMessage(text: text, isUser: true);

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _messageController.clear();
    });
    _scrollToBottom();

    // Ulož užívateľovu správu do Firestore
    try {
      await _firestoreService.saveChatMessage(text, true);
    } catch (_) {}

    try {
      final response = await _geminiService.chatWithDiary(text, _entries);
      if (!mounted) return;

      final aiMessage = _ChatMessage(text: response, isUser: false);
      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });
      _scrollToBottom();

      // Ulož AI odpoveď do Firestore
      try {
        await _firestoreService.saveChatMessage(response, false);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Prepáč, nastala chyba. Skús to znova. 🙏',
          isUser: false,
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vymazať históriu chatu?'),
        content: const Text(
            'Všetky predošlé správy budú nenávratne vymazané.'),
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

    if (confirmed == true) {
      try {
        await _firestoreService.clearChatMessages();
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _messages.add(_ChatMessage(
            text:
                'História vymazaná. Pýtaj sa ďalej! 👋',
            isUser: false,
          ));
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri mazaní: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome),
            SizedBox(width: 8),
            Text('Chat s denníkom'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearChat,
            tooltip: 'Vymazať históriu',
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Spýtaj sa niečo...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: IconButton(
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send, color: Colors.white),
                            onPressed: _isLoading ? null : _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.deepPurple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.deepPurple,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'AI premýšľa...',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}