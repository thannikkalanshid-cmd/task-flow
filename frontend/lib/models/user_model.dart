class UserProfile {
  final int id;
  final String username;
  final String email;
  final String bio;

  UserProfile({required this.id, required this.username, required this.email, required this.bio});

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      bio: json['bio'] ?? '',
    );
  }
}
