import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/main_menu_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyASn90rXw7Ga_l28ajSD0rTASvmEwUOPLM",
      authDomain: "schafkopf-70bc6.firebaseapp.com",
      projectId: "schafkopf-70bc6",
      storageBucket: "schafkopf-70bc6.firebasestorage.app",
      messagingSenderId: "1597115911",
      appId: "1:1597115911:web:a0d165807b9284c79564a2"
    ),
  );
  runApp(const SchafkopfApp());
}

class SchafkopfApp extends StatelessWidget {
  const SchafkopfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schafkopf Scorer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainMenuScreen(),
        '/lobby': (context) => const LobbyScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/gameplay') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => GameplayScreen(
              gameId: args['gameId'],
              players: args['players'],
              initialDealer: args['dealer'],
              baseValue: args['baseValue'],
            ),
          );
        }
        return null;
      },
    );
  }
}

class FirestoreTestScreen extends StatelessWidget {
  const FirestoreTestScreen({super.key});

  Future<void> _addTestGame() async {
    try {
      await FirebaseFirestore.instance.collection('games').add({
        'date': Timestamp.now(),
        'players': ['Player 1', 'Player 2', 'Player 3', 'Player 4'],
        'rounds': [
          {
            'gameType': 'Solo',
            'player': 'Player 1',
            'points': 120,
            'won': true,
          }
        ]
      });
      debugPrint('Test game added successfully!');
    } catch (e) {
      debugPrint('Error adding test game: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Test'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _addTestGame,
            child: const Text('Add Test Game'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('games').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No games found'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var game = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text('Game ${index + 1}'),
                      subtitle: Text('Players: ${game['players'].join(', ')}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
