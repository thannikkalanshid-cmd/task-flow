class UserProfile {
  final int id;
  final String username;
  final String email;
  final String bio;
  final String? profileImageUrl;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.bio,
    this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      bio: json['bio'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }
}
