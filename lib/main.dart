import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schafkopf_rechner/providers/settings_provider.dart';
import 'firebase_options.dart';
import 'screens/main_menu_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    
    return MaterialApp(
      title: 'Schafkopf Rechner',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: settingsAsync.when(
        data: (settings) => settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        loading: () => ThemeMode.system,
        error: (_, __) => ThemeMode.system,
      ),
      home: const MainMenuScreen(),
      routes: {
        '/lobby': (context) => const LobbyScreen(),
        '/statistics': (context) => const StatisticsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/gameplay') {
          final args = settings.arguments as Map<String, dynamic>?;
          final sessionId = args?['sessionId'] as String?;
          
          if (sessionId == null) {
            return MaterialPageRoute(
              builder: (context) => const MainMenuScreen(),
            );
          }
          
          return MaterialPageRoute(
            builder: (context) => GameplayScreen(sessionId: sessionId),
          );
        }
        
        return MaterialPageRoute(
          builder: (context) => const MainMenuScreen(),
        );
      },
    );
  }
}
