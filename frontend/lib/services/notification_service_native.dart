import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone));
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  Future<void> schedule(Task task) async {
    await _plugin.cancel(task.id);
    if (task.completed || task.dueDate == null || task.dueTime == null) return;
    final parts = task.dueTime!.split(':');
    final due = tz.TZDateTime(tz.local, DateTime.parse(task.dueDate!).year, DateTime.parse(task.dueDate!).month,
        DateTime.parse(task.dueDate!).day, int.parse(parts[0]), int.parse(parts[1]));
    final scheduled = due.subtract(Duration(minutes: task.reminderMinutes ?? 0));
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      task.id,
      task.reminderMinutes == 0 ? 'Task due now' : 'Task reminder',
      task.title,
      scheduled,
      const NotificationDetails(android: AndroidNotificationDetails('task_reminders', 'Task reminders', channelDescription: 'Due date reminders', importance: Importance.high, priority: Priority.high)),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: '${task.id}',
    );
  }

  Future<void> cancel(int taskId) => _plugin.cancel(taskId);
}
