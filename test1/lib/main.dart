import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/local/database_helper.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/match_provider.dart';
import 'providers/theme_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/call/video_call_screen.dart';
import 'views/home/home_screen.dart';

import 'data/local/local_storage.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.instance.init();
  await DatabaseHelper.instance.initDatabase();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  final authProvider = AuthProvider()..reloadFromStorage();
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: const LanguageMatcherApp(),
    ),
  );
}

class LanguageMatcherApp extends StatelessWidget {
  const LanguageMatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Language Partner Matcher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/call': (context) => const VideoCallScreen(),
      },
    );
  }
}
