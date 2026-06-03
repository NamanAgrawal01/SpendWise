import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  static Future<void> showTransactionAlert(String title, double amount, String type) async {
    final symbol = type == 'expense' ? '💸' : '💰';
    final action = type == 'expense' ? 'Spent' : 'Received';
    
    final androidDetails = AndroidNotificationDetails(
      'transactions',
      'Transaction Alerts',
      channelDescription: 'Alerts for new detected transactions',
      importance: Importance.high,
      priority: Priority.high,
      color: type == 'expense' ? const Color(0xFFFF5252) : const Color(0xFF4CAF50),
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '$symbol New $action Detected',
      '₹$amount at $title',
      notificationDetails,
    );
  }

  static Future<void> showBudgetAlert(String category, double spent, double budget) async {
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription: 'Alerts when budget limits are reached',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      999,
      '⚠️ Budget Alert: $category',
      'You have spent ₹$spent of your ₹$budget budget.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
