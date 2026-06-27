import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';
import '../models/user_model.dart';

/// ApiService handles all API communication with the Django backend
class ApiService {
  // Override for a physical device or deployed backend with --dart-define.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

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
  Future<http.Response> register(String username, String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/register/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
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

    print('LOGIN STATUS: ${response.statusCode}');
    print('LOGIN BODY: ${response.body}');

    return response;
  }

  // ====================== User Profile Methods ======================

  /// Fetch the current user's profile
  Future<UserProfile> fetchProfile() async {
    final response = await http.get(Uri.parse('$baseUrl/profile/'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    return UserProfile.fromJson(jsonDecode(response.body));
  }

  // ====================== Task Methods ======================

  /// Fetch all tasks for the current user
  Future<List<Task>> fetchTasks() async {
    final response = await http.get(Uri.parse('$baseUrl/tasks/'), headers: _headers);
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
  Future<Task> updateTask(int id, {
    String? title,
    String? description,
    String? category,
    String? priority,
    String? dueDate,
    String? dueTime,
    String? notes,
    bool? completed,
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
