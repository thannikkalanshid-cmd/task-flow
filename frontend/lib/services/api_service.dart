import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import '../models/task_note_model.dart';
import '../models/user_model.dart';

/// ApiService handles all API communication with the Django backend
class ApiService {
  // Override for a physical device or deployed backend with --dart-define.
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static final baseUrl = _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : kIsWeb
          ? 'http://127.0.0.1:8000/api'
          : 'http://10.0.2.2:8000/api';

  final String? token;

  ApiService({this.token});

  /// Get authorization headers with JWT token
  Map<String, String> get _headers {
    final map = {'Content-Type': 'application/json'};
    if (token != null) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // ====================== Authentication Methods ======================

  /// Register a new user
  Future<http.Response> register(
      String username, String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/register/'),
      headers: _headers,
      body: jsonEncode(
          {'username': username, 'email': email, 'password': password}),
    );
  }

  Future<http.Response> verifyEmail(String email, String otp) {
    return http.post(
      Uri.parse('$baseUrl/verify-email/'),
      headers: _headers,
      body: jsonEncode({'email': email, 'otp': otp}),
    );
  }

  Future<http.Response> resendVerification(String email) {
    return http.post(
      Uri.parse('$baseUrl/resend-verification/'),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
  }

  /// Login with username and password, returns JWT tokens
  Future<http.Response> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token/'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    return response;
  }

  /// Exchanges a persisted refresh token for a new access token.
  Future<String?> refreshAccessToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refreshToken}),
    );
    if (response.statusCode != 200) return null;
    return (jsonDecode(response.body) as Map<String, dynamic>)['access']
        as String?;
  }

  // ====================== User Profile Methods ======================

  /// Fetch the current user's profile
  Future<UserProfile> fetchProfile() async {
    final response =
        await http.get(Uri.parse('$baseUrl/profile/'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    return UserProfile.fromJson(jsonDecode(response.body));
  }

  /// Update editable fields on the current user's profile.
  Future<UserProfile> updateProfile({
    required String username,
    required String email,
    required String bio,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/profile/'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'bio': bio,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to update profile'));
    }
    return UserProfile.fromJson(jsonDecode(response.body));
  }

  /// Upload a profile image as multipart data and return its absolute URL.
  Future<String> uploadProfileImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/image/'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'profile_image',
        bytes,
        filename: filename,
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to upload image'));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['profile_image_url'] as String;
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        final value = data.values.first;
        if (value is List && value.isNotEmpty) return value.first.toString();
        return value.toString();
      }
    } catch (_) {}
    return fallback;
  }

  // ====================== Task Methods ======================

  /// Fetch all tasks for the current user
  Future<List<Task>> fetchTasks() async {
    final response =
        await http.get(Uri.parse('$baseUrl/tasks/'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load tasks');
    }
    final body = jsonDecode(response.body) as List;
    return body.map((json) => Task.fromJson(json)).toList();
  }

  /// Create a new task with optional fields
  Future<Task> createTask({
    required String title,
    String description = '',
    String category = 'General',
    String priority = 'medium',
    String? dueDate,
    String? dueTime,
    String notes = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'priority': priority,
        'due_date': dueDate,
        'due_time': dueTime,
        'notes': notes,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create task: ${response.body}');
    }
    return Task.fromJson(jsonDecode(response.body));
  }

  /// Update an existing task
  Future<Task> updateTask(
    int id, {
    String? title,
    String? description,
    String? category,
    String? priority,
    String? dueDate,
    String? dueTime,
    String? notes,
    bool? completed,
    List<int>? tagIds,
    String? recurrence,
    int? reminderMinutes,
  }) async {
    final updateData = <String, dynamic>{};
    if (title != null) updateData['title'] = title;
    if (description != null) updateData['description'] = description;
    if (category != null) updateData['category'] = category;
    if (priority != null) updateData['priority'] = priority;
    if (dueDate != null) updateData['due_date'] = dueDate;
    if (dueTime != null) updateData['due_time'] = dueTime;
    if (notes != null) updateData['notes'] = notes;
    if (completed != null) updateData['completed'] = completed;
    if (tagIds != null) updateData['tag_ids'] = tagIds;
    if (recurrence != null) updateData['recurrence'] = recurrence;
    if (reminderMinutes != null)
      updateData['reminder_minutes'] = reminderMinutes;

    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/$id/'),
      headers: _headers,
      body: jsonEncode(updateData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update task: ${response.body}');
    }
    return Task.fromJson(jsonDecode(response.body));
  }

  /// Delete a task
  Future<void> deleteTask(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tasks/$id/'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete task: ${response.body}');
    }
  }

  Future<List<Tag>> fetchTags() async {
    final response =
        await http.get(Uri.parse('$baseUrl/tags/'), headers: _headers);
    if (response.statusCode != 200)
      throw Exception(_errorMessage(response, 'Failed to load tags'));
    return (jsonDecode(response.body) as List)
        .map((item) => Tag.fromJson(item))
        .toList();
  }

  Future<Tag> createTag(String name, String color) async {
    final response = await http.post(Uri.parse('$baseUrl/tags/'),
        headers: _headers, body: jsonEncode({'name': name, 'color': color}));
    if (response.statusCode != 201)
      throw Exception(_errorMessage(response, 'Failed to create tag'));
    return Tag.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteTag(int id) async {
    final response =
        await http.delete(Uri.parse('$baseUrl/tags/$id/'), headers: _headers);
    if (response.statusCode != 204)
      throw Exception(_errorMessage(response, 'Failed to delete tag'));
  }

  Future<Map<String, dynamic>> fetchAnalytics() async {
    final response = await http.get(Uri.parse('$baseUrl/tasks/analytics/'),
        headers: _headers);
    if (response.statusCode != 200)
      throw Exception(_errorMessage(response, 'Failed to load analytics'));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Uploads a file to a task, or to one of its notes when [noteId] is given.
  Future<Attachment> uploadAttachment(
      {required int taskId,
      int? noteId,
      required List<int> bytes,
      required String filename}) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/attachments/'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['task_id'] = '$taskId';
    if (noteId != null) request.fields['note_id'] = '$noteId';
    request.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 201)
      throw Exception(_errorMessage(response, 'Failed to upload attachment'));
    return Attachment.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteAttachment(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/attachments/$id/'),
        headers: _headers);
    if (response.statusCode != 204)
      throw Exception(_errorMessage(response, 'Failed to delete attachment'));
  }

  // ====================== Task Note Methods ======================

  Future<List<TaskNote>> getTaskNotes(int taskId) async {
    final response = await http.get(Uri.parse('$baseUrl/tasks/$taskId/notes/'),
        headers: _headers);
    if (response.statusCode != 200)
      throw Exception(_errorMessage(response, 'Failed to load notes'));
    return (jsonDecode(response.body) as List)
        .map((item) => TaskNote.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TaskNote> createTaskNote(int taskId,
      {required String title, required String content}) async {
    final response = await http.post(Uri.parse('$baseUrl/tasks/$taskId/notes/'),
        headers: _headers,
        body: jsonEncode({'title': title, 'content': content}));
    if (response.statusCode != 201)
      throw Exception(_errorMessage(response, 'Failed to create note'));
    return TaskNote.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<TaskNote> updateTaskNote(int noteId,
      {required String title, required String content}) async {
    final response = await http.patch(Uri.parse('$baseUrl/notes/$noteId/'),
        headers: _headers,
        body: jsonEncode({'title': title, 'content': content}));
    if (response.statusCode != 200)
      throw Exception(_errorMessage(response, 'Failed to save note'));
    return TaskNote.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteTaskNote(int noteId) async {
    final response = await http.delete(Uri.parse('$baseUrl/notes/$noteId/'),
        headers: _headers);
    if (response.statusCode != 204)
      throw Exception(_errorMessage(response, 'Failed to delete note'));
  }

  // ====================== Checklist Item Methods ======================

  /// Add a checklist item to a task
  Future<ChecklistItem> addChecklistItem(
    int taskId, {
    required String title,
    int order = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/checklist-items/'),
      headers: _headers,
      body: jsonEncode({
        'task_id': taskId,
        'title': title,
        'order': order,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to add checklist item: ${response.body}');
    }
    return ChecklistItem.fromJson(jsonDecode(response.body));
  }

  /// Update a checklist item
  Future<ChecklistItem> updateChecklistItem(
    int itemId, {
    String? title,
    bool? completed,
    int? order,
  }) async {
    final updateData = <String, dynamic>{};
    if (title != null) updateData['title'] = title;
    if (completed != null) updateData['completed'] = completed;
    if (order != null) updateData['order'] = order;

    final response = await http.patch(
      Uri.parse('$baseUrl/checklist-items/$itemId/'),
      headers: _headers,
      body: jsonEncode(updateData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update checklist item: ${response.body}');
    }
    return ChecklistItem.fromJson(jsonDecode(response.body));
  }

  /// Delete a checklist item
  Future<void> deleteChecklistItem(int itemId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/checklist-items/$itemId/'),
      headers: _headers,
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete checklist item: ${response.body}');
    }
  }
}
