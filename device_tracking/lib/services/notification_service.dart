import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );
    
    await _notificationsPlugin.initialize(settings: initializationSettings);
    
    // Request Android 13+ permissions
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  DateTime calculateWorkingDays(DateTime startDate, int workingDaysToAdd) {
    DateTime result = DateTime(startDate.year, startDate.month, startDate.day);
    int addedDays = 0;
    while (addedDays < workingDaysToAdd) {
      result = result.add(const Duration(days: 1));
      if (result.weekday != DateTime.friday && result.weekday != DateTime.saturday) {
        addedDays++;
      }
    }
    return result;
  }

  Future<void> scheduleMaintenanceDelays(String orderId, String orderNumber, DateTime maintenanceStartDate) async {
    final DateTime target7Days = calculateWorkingDays(maintenanceStartDate, 7);
    final DateTime target10Days = calculateWorkingDays(maintenanceStartDate, 10);
    
    final int id7 = orderId.hashCode.abs();
    final int id10 = orderId.hashCode.abs() + 100000;

    if (target7Days.isAfter(DateTime.now())) {
      await _schedule(id7, 'تأخير في الصيانة!', 'الطلب رقم $orderNumber تأخر في الصيانة لمدة 7 أيام عمل.', target7Days);
    }
    if (target10Days.isAfter(DateTime.now())) {
      await _schedule(id10, 'تأخير شديد في الصيانة!', 'الطلب رقم $orderNumber تجاوز 10 أيام عمل في الصيانة.', target10Days);
    }
  }

  Future<void> scheduleBranchDelays(String orderId, String orderNumber, DateTime receivedFromCustomerDate) async {
    final DateTime target10Days = calculateWorkingDays(receivedFromCustomerDate, 10);
    
    final int idBranch = orderId.hashCode.abs() + 200000;

    if (target10Days.isAfter(DateTime.now())) {
      await _schedule(idBranch, 'تأخير في الفرع!', 'الطلب رقم $orderNumber تأخر في الفرع أكثر من 10 أيام عمل.', target10Days);
    }
  }

  Future<void> _schedule(int id, String title, String body, DateTime targetDate) async {
    final scheduledDate = tz.TZDateTime.from(
      DateTime(targetDate.year, targetDate.month, targetDate.day, 10, 0),
      tz.local,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'maintenance_delay',
          'Maintenance Delays',
          channelDescription: 'Notifications for delayed maintenance orders',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelMaintenanceDelays(String orderId) async {
    await _notificationsPlugin.cancel(id: orderId.hashCode.abs());
    await _notificationsPlugin.cancel(id: orderId.hashCode.abs() + 100000);
  }

  Future<void> cancelBranchDelays(String orderId) async {
    await _notificationsPlugin.cancel(id: orderId.hashCode.abs() + 200000);
  }
}
