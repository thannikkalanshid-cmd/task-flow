import '../models/task_model.dart';

/// Browser notifications are permission-gated and do not support Android's
/// native scheduling APIs. Due reminders remain visible in the app.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  Future<void> initialize() async {}
  Future<void> schedule(Task task) async {}
  Future<void> cancel(int taskId) async {}
}
