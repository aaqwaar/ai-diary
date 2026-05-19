import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream sledujúci zmeny stavu prihlásenia (auto-update UI)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Aktuálne prihlásený užívateľ
  User? get currentUser => _auth.currentUser;

  // Prihlásenie
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Registrácia
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Odhlásenie
  Future<void> signOut() async {
    await _auth.signOut();
  }
}