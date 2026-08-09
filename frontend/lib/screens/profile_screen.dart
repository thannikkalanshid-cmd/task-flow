import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ApiService _apiService;
  UserProfile? _profile;
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    _loadProfile();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final shouldUpload = await _showImagePreview(bytes);
      if (!shouldUpload || !mounted) return;

      setState(() => _isUploading = true);
      final oldUrl = _profile?.profileImageUrl;
      if (oldUrl != null) {
        await CachedNetworkImage.evictFromCache(oldUrl);
      }
      await _apiService.uploadProfileImage(
        bytes: bytes,
        filename: image.name,
      );
      await _loadProfile();
      _showMessage('Profile picture updated.');
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<bool> _showImagePreview(Uint8List bytes) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Profile picture preview'),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(bytes, height: 240, fit: BoxFit.cover),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Upload'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final updated = await Navigator.push<UserProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: profile,
          apiService: _apiService,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _profile = updated);
    _showMessage('Profile updated.');
    await _loadProfile();
  }

  /// Load user profile from API
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await _apiService.fetchProfile();
      if (mounted) setState(() => _profile = user);
    } catch (_) {
      _showMessage('Unable to load profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Logout user and clear token
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Show a message to the user
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF08122A), Color(0xFF0F172A)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : ListView(
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: const Color(0xFF6366F1),
                                backgroundImage: _profile?.profileImageUrl != null
                                    ? CachedNetworkImageProvider(
                                        _profile!.profileImageUrl!,
                                      )
                                    : null,
                                child: _profile?.profileImageUrl == null
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 44,
                                      )
                                    : null,
                              ),
                              Material(
                                color: const Color(0xFF6366F1),
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Choose profile picture',
                                  onPressed:
                                      _isUploading ? null : _pickAndUploadImage,
                                  icon: _isUploading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_outlined,
                                          size: 20,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _profile?.username ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _profile?.email ?? '',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _profile?.bio.isNotEmpty == true ? _profile!.bio : 'Share a short bio from your profile.',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInfoTile('Username', _profile?.username ?? '-'),
                    _buildInfoTile('Email', _profile?.email ?? '-'),
                    _buildInfoTile('Bio', _profile?.bio.isNotEmpty == true ? _profile!.bio : 'No bio set'),
                    const SizedBox(height: 18),
                    // Logout button with proper text styling
                    ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Build an info tile displaying label and value
  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
