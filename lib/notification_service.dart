import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings: initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showTestNow() async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'tasks_channel',
      'Tehtävämuistutukset',
      channelDescription: 'Viikkotehtävät-muistutukset',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      id: 1,
      title: 'Testi',
      body: 'Notifikaatiot toimii 🎉',
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Ajastaa viikottaisen muistutuksen, oletuksena 30 min ennen tehtävää.
  Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int weekday, // DateTime.monday..DateTime.sunday
    required int hour,
    required int minute,
    int minutesBefore = 30, // 👈 oletus 30 min ennen
  }) async {
    if (kIsWeb) return;

    final now = tz.TZDateTime.now(tz.local);

    // Seuraava tehtäväaika
    var nextTaskTime =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (nextTaskTime.weekday != weekday) {
      nextTaskTime = nextTaskTime.add(const Duration(days: 1));
    }
    if (nextTaskTime.isBefore(now)) {
      nextTaskTime = nextTaskTime.add(const Duration(days: 7));
    }

    // Muistutus ennen tehtävää
    final scheduled = nextTaskTime.subtract(Duration(minutes: minutesBefore));

    const androidDetails = AndroidNotificationDetails(
      'tasks_channel',
      'Tehtävämuistutukset',
      channelDescription: 'Viikkotehtävät-muistutukset',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: id);
  }
}
