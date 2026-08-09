import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.initialize();

  final themeController = ThemeController();
  await themeController.load();

  runApp(
    MobileApp(themeController: themeController),
  );
}

class MobileApp extends StatelessWidget {
  final ThemeController themeController;

  const MobileApp({
    super.key,
    required this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (_, __) {
        return MaterialApp(
          title: "TaskFlow",
          debugShowCheckedModeBanner: false,

          theme: ThemeData(
            brightness: Brightness.dark,

            primaryColor: const Color(0xFF6366F1),

            scaffoldBackgroundColor: const Color(0xFF08122A),

            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF22C55E),
              surface: Color(0xFF111827),
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF111827),
              elevation: 0,
              centerTitle: false,
            ),

            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF0F172A),

              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                ),
              ),
            ),

            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          darkTheme: ThemeData(
            brightness: Brightness.dark,

            primaryColor: const Color(0xFF6366F1),

            scaffoldBackgroundColor: const Color(0xFF08122A),

            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF22C55E),
              surface: Color(0xFF111827),
            ),

            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF111827),
              elevation: 0,
            ),
          ),

          themeMode: themeController.mode,

          home: _StartupScreen(
            themeController: themeController,
          ),
        );
      },
    );
  }
}

class _StartupScreen extends StatefulWidget {
  final ThemeController themeController;

  const _StartupScreen({
    required this.themeController,
  });

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    final prefs = await SharedPreferences.getInstance();

    var token = prefs.getString("access_token");
    final refresh = prefs.getString("refresh_token");

    if (refresh != null && refresh.isNotEmpty) {
      final newToken = await ApiService().refreshAccessToken(refresh);

      if (newToken != null) {
        token = newToken;
        await prefs.setString(
          "access_token",
          newToken,
        );
      }
    }

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            token: token!,
            themeController: widget.themeController,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1228),
              Color(0xFF111827),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "TaskFlow",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(height: 24),

              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Color(0xFF6366F1),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}