import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/depth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Handle user login
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService().login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final accessToken = body['access'];
        final refreshToken = body['refresh'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        if (refreshToken is String && refreshToken.isNotEmpty) {
          await prefs.setString('refresh_token', refreshToken);
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          _createRoute(HomeScreen(token: accessToken)),
        );
      } else {
        _showError('Login failed. Check your credentials.');
      }
    } catch (_) {
      _showError('Unable to connect to the backend.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Show error message to user
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  children: [
                    DepthCard(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TaskFlow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Sign in and get things done.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildTextField(
                            controller: _usernameController,
                            label: 'Username',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: !_passwordVisible,
                            onToggleVisibility: () => setState(() => _passwordVisible = !_passwordVisible),
                          ),
                          const SizedBox(height: 24),
                          DepthButton(
                            label: 'Log in',
                            loading: _isLoading,
                            onPressed: _isLoading ? null : _login,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        _createRoute(const RegisterScreen()),
                      ),
                      child: const Text(
                        'Create a new account',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a text field with icon and label
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        suffixIcon: onToggleVisibility == null
            ? null
            : IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white70),
              ),
      ),
    );
  }

  /// Create a page route with smooth animation
  Route _createRoute(Widget page, {bool reverse = false}) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetAnimation = Tween<Offset>(
          begin: reverse ? const Offset(-0.3, 0.0) : const Offset(0.25, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fadeAnimation = CurvedAnimation(parent: animation, curve: Curves.easeIn);
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: child),
        );
      },
    );
  }
}
