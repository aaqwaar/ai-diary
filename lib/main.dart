import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/firestore_service.dart';
import 'screens/set_username_screen.dart';
import 'screens/home_screen.dart';


// Globálny kľúč pre zobrazovanie snackbarov odkiaľkoľvek v appke
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('sk');
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Denník',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// Rozhoduje, či zobraziť login alebo home na základe stavu prihlásenia
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Užívateľ nie je prihlásený → Login
        if (!authSnapshot.hasData) {
          return const LoginScreen();
        }

        // Užívateľ je prihlásený, skontroluj či má username
        return StreamBuilder<String?>(
          stream: FirestoreService().usernameStream(),
          builder: (context, usernameSnapshot) {
            if (usernameSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final username = usernameSnapshot.data;

            // Nemá username → SetUsernameScreen
            if (username == null || username.isEmpty) {
              return const SetUsernameScreen();
            }

            // Má všetko → HomeScreen
            return const HomeScreen();
          },
        );
      },
    );
  }
}