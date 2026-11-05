import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

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

          theme: AppTheme.dark(),

          darkTheme: AppTheme.dark(),

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
              Color(0xFF070B1E),
              Color(0xFF111B3A),
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