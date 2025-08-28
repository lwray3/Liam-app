import 'package:flutter/material.dart';

import 'welcome_screen.dart';
import 'signup_screen.dart';
import 'loading_screen.dart';
import 'profile_screen.dart';
import 'journal_screen.dart';
import 'habits_screen.dart';
import 'pillars_screen.dart';
import 'login_screen.dart';
import 'forgot_password.dart';
import 'friends.dart';

// 👇 Make sure these two exist & are imported correctly
import 'graph_awesome.dart'; // class GraphAwesome({ required List<Pillar> pillars })
import 'pillars_screen.dart'; // defines Pillar & Habit

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pillar',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,

      // ⛔ Don't start on /graph_awesome because it needs arguments.
      // Pick a normal entry screen (welcome/login/loading/etc.)
      initialRoute: '/welcome',

      // Static routes that don't need constructor args
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/loading': (context) => const LoadingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/journal': (context) => const JournalScreen(),
        '/habits': (context) => const HabitsScreen(),
        '/pillars': (context) => const PillarsScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/friends': (context) => const FriendsScreen(),
      },

      // Dynamic routes that need arguments (like pillars)
      onGenerateRoute: (settings) {
        if (settings.name == '/graph_awesome') {
          // Expect: Navigator.pushNamed(context, '/graph_awesome', arguments: List<Pillar>);
          final args = settings.arguments;
          if (args is List<Pillar>) {
            return MaterialPageRoute(
              builder: (_) => GraphAwesome(
                pillars: List<Pillar>.unmodifiable(args),
              ),
              settings: settings,
            );
          } else {
            // Defensive fallback if arguments were missing/wrong type
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(
                  child: Text(
                    'Error: /graph_awesome requires List<Pillar> as arguments.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              settings: settings,
            );
          }
        }

        // Unknown route fallback
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
          settings: settings,
        );
      },
    );
  }
}
