import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/entry_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper: kolekcia zápiskov aktuálneho užívateľa
  CollectionReference<Map<String, dynamic>> _userEntries() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw Exception('Užívateľ nie je prihlásený');
    }
    return _db.collection('users').doc(userId).collection('entries');
  }

  // Vytvorí zápisok
  Future<String> createEntry(Entry entry) async {
    final docRef = await _userEntries().add(entry.toFirestore());
    return docRef.id;
  }

  // Stream zápiskov (auto-update UI keď sa zmenia)
  Stream<List<Entry>> entriesStream() {
    return _userEntries()
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Entry.fromFirestore(doc)).toList());
  }

  // Vymaže zápisok
  Future<void> deleteEntry(String entryId) async {
    await _userEntries().doc(entryId).delete();
  }

  // Aktualizuje tagy (použijeme neskôr po AI tagovaní)
  Future<void> updateTags(String entryId, List<String> tags) async {
    await _userEntries().doc(entryId).update({'tags': tags});
  }
  // Helper: kolekcia chat správ aktuálneho užívateľa
CollectionReference<Map<String, dynamic>> _userChatMessages() {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    throw Exception('Užívateľ nie je prihlásený');
  }
  return _db.collection('users').doc(userId).collection('chat_messages');
}

// Uloží chat správu
Future<void> saveChatMessage(String text, bool isUser) async {
  await _userChatMessages().add({
    'text': text,
    'isUser': isUser,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

// Načíta všetky chat správy (zoradené od najstaršej)
Future<List<Map<String, dynamic>>> getChatMessages() async {
  final snapshot =
      await _userChatMessages().orderBy('timestamp', descending: false).get();
  return snapshot.docs.map((doc) => doc.data()).toList();
}

// Vymaže celú chat históriu
Future<void> clearChatMessages() async {
  final snapshot = await _userChatMessages().get();
  for (final doc in snapshot.docs) {
    await doc.reference.delete();
  }
}
}