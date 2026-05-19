import 'package:cloud_firestore/cloud_firestore.dart';

class Entry {
  final String? id;
  final String userId;
  final String text;
  final int mood; // 1-5
  final DateTime date;
  final List<String> tags;

  Entry({
    this.id,
    required this.userId,
    required this.text,
    required this.mood,
    required this.date,
    this.tags = const [],
  });

  // Konvertovanie z Firestore dokumentu na Dart objekt
  factory Entry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Entry(
      id: doc.id,
      userId: data['userId'] ?? '',
      text: data['text'] ?? '',
      mood: data['mood'] ?? 3,
      date: (data['date'] as Timestamp).toDate(),
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Konvertovanie Dart objektu na Firestore mapu
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'text': text,
      'mood': mood,
      'date': Timestamp.fromDate(date),
      'tags': tags,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}