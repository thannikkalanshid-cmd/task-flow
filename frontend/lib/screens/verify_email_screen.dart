import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Enter the 6-digit code from your email.', isError: true);
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final response = await ApiService().verifyEmail(widget.email, code);
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showMessage('Email verified. Please log in.');
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        _showMessage(_messageFrom(response.body, 'Verification failed.'), isError: true);
      }
    } catch (_) {
      _showMessage('Unable to connect to the backend.', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final response = await ApiService().resendVerification(widget.email);
      if (!mounted) return;
      _showMessage(response.statusCode == 200
          ? 'A new code has been sent.'
          : _messageFrom(response.body, 'Could not resend the code.'));
    } catch (_) {
      _showMessage('Unable to connect to the backend.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _messageFrom(String body, String fallback) {
    try {
      return jsonDecode(body)['detail'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF070B1E), Color(0xFF111B3A)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: const Color(0xFF111B3A), borderRadius: BorderRadius.circular(28)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 56),
                  const SizedBox(height: 20),
                  const Text('Verify your email', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('We sent a 6-digit code to\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Verification code', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verify,
                    child: _isVerifying ? const CircularProgressIndicator(color: Colors.white) : const Text('Verify email'),
                  )),
                  TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(_isResending ? 'Sending…' : 'Resend code', style: const TextStyle(color: Colors.white70)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
