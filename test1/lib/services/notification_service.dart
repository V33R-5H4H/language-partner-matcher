import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  NotificationService._init();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const int _incomingCallNotificationId = 8888;
  static const int _chatMessageNotificationId = 9999;

  static const String _callChannelId = 'incoming_calls';
  static const String _callChannelName = 'Incoming Call Alerts';
  static const String _callChannelDesc = 'High-priority notifications for incoming language practice calls';

  static const String _chatChannelId = 'chat_messages';
  static const String _chatChannelName = 'Practice Messages';
  static const String _chatChannelDesc = 'Notifications for new text messages from practice partners';

  // Callbacks for notification tap / actions
  Function(String payload)? onCallNotificationTapped;
  Function(String payload)? onMessageNotificationTapped;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Create Android Notification Channels
      if (!kIsWeb) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // Channel 1: Incoming Calls (High Priority with vibration & full screen intent)
          const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
            _callChannelId,
            _callChannelName,
            description: _callChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

          // Channel 2: Chat Messages
          const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
            _chatChannelId,
            _chatChannelName,
            description: _chatChannelDesc,
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );

          await androidPlugin.createNotificationChannel(callChannel);
          await androidPlugin.createNotificationChannel(chatChannel);
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService: Initialization error: $e');
    }
  }

  Future<void> requestPermissions() async {
    try {
      if (!kIsWeb) {
        await Permission.notification.request();

        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error requesting permissions: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    debugPrint('NotificationService: Notification tapped with payload: $payload, actionId: ${response.actionId}');

    if (payload.startsWith('call:')) {
      onCallNotificationTapped?.call(payload.replaceFirst('call:', ''));
    } else if (payload.startsWith('chat:')) {
      onMessageNotificationTapped?.call(payload.replaceFirst('chat:', ''));
    }
  }

  /// Show high-priority ringing notification for an incoming practice call
  Future<void> showIncomingCallNotification({
    required String callerId,
    required String callerName,
    required String roomId,
    required String targetLang,
    required bool isAudioOnly,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final androidDetails = AndroidNotificationDetails(
        _callChannelId,
        _callChannelName,
        channelDescription: _callChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        autoCancel: true,
        ongoing: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 800, 500, 800, 500, 800]),
        color: const Color(0xFF00A884),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'accept_call',
            'Answer Call',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'decline_call',
            'Decline',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id: _incomingCallNotificationId,
        title: 'Incoming ${isAudioOnly ? "Voice" : "Video"} Call',
        body: '$callerName wants to practice $targetLang with you',
        notificationDetails: details,
        payload: 'call:$callerId:$callerName:$roomId:$targetLang:$isAudioOnly',
      );
    } catch (e) {
      debugPrint('NotificationService: Error showing call notification: $e');
    }
  }

  /// Cancel incoming call notification when call is answered, declined or cancelled
  Future<void> cancelIncomingCallNotification() async {
    try {
      await _localNotifications.cancel(id: _incomingCallNotificationId);
    } catch (e) {
      debugPrint('NotificationService: Error cancelling call notification: $e');
    }
  }

  /// Show message notification when a new text arrives while app is in background or another tab
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    required String peerId,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const androidDetails = AndroidNotificationDetails(
        _chatChannelId,
        _chatChannelName,
        channelDescription: _chatChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        autoCancel: true,
        showWhen: true,
        color: Color(0xFF00A884),
      );

      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        id: _chatMessageNotificationId + (peerId.hashCode % 1000).abs(),
        title: senderName,
        body: messageText,
        notificationDetails: details,
        payload: 'chat:$peerId:$senderName',
      );
    } catch (e) {
      debugPrint('NotificationService: Error showing chat notification: $e');
    }
  }
}
