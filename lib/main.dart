import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'screens/main_menu_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/gameplay_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return settingsAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error loading settings: $err'),
          ),
        ),
      ),
      data: (settings) {
        return MaterialApp(
          title: 'Schafkopf Rechner',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            cardTheme: CardTheme(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              centerTitle: true,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            cardTheme: CardTheme(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          ),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
      },
    );
  }
}
