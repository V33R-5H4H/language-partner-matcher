import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/websocket_service.dart';
import '../call/video_call_screen.dart';
import '../chat/chat_list_tab.dart';
import '../history/call_history_screen.dart';
import '../match/match_screen.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription? _incomingCallSub;
  BuildContext? _incomingCallDialogContext;
  bool _isWsInitialized = false;

  final List<Widget> _pages = const [
    MatchScreen(),
    ChatListTab(),
    CallHistoryScreen(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForIncomingCallRequests();
    _setupNotificationHandlers();
  }

  void _setupNotificationHandlers() {
    NotificationService.instance.onCallNotificationTapped = (payload) {
      if (!mounted) return;
      final parts = payload.split(':');
      if (parts.length >= 5) {
        final callerId = parts[0];
        final callerName = parts[1];
        final roomId = parts[2];
        final targetLang = parts[3];
        final isAudioOnly = parts[4] == 'true';

        // Auto-accept call
        WebSocketService.instance.send({
          'type': 'call_accepted',
          'peer_id': callerId,
          'room_id': roomId,
          'is_audio_only': isAudioOnly,
        });

        if (_incomingCallDialogContext != null) {
          Navigator.pop(_incomingCallDialogContext!);
          _incomingCallDialogContext = null;
        }
        NotificationService.instance.cancelIncomingCallNotification();

        final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
        final match = MatchModel(
          roomId: roomId,
          peerId: callerId,
          peerUsername: callerName,
          peerNativeLang: targetLang,
          peerTargetLang: user.nativeLanguageName ?? 'English',
          isInitiator: false,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              match: match,
              peerUsername: callerName,
              targetLanguage: targetLang,
              isAudioOnly: isAudioOnly,
            ),
          ),
        );
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isWsInitialized) {
      _isWsInitialized = true;
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      final wsUrl = ApiEndpoints.signalingSocket(user.userId, 'local_token');
      WebSocketService.instance.connect(wsUrl, userId: user.userId);
    }
  }

  void _listenForIncomingCallRequests() {
    _incomingCallSub = WebSocketService.instance.messages.listen((event) {
      if (event['type'] == 'incoming_call_request') {
        final callerId = (event['caller_id'] ?? event['from'] ?? '').toString();
        final callerName = (event['caller_name'] ?? 'Practice Partner').toString();
        final roomId = (event['room_id'] ?? '').toString();
        final targetLang = (event['target_lang'] ?? 'Spanish').toString();
        final isAudioOnly = event['is_audio_only'] == true;

        // Trigger native notification
        NotificationService.instance.showIncomingCallNotification(
          callerId: callerId,
          callerName: callerName,
          roomId: roomId,
          targetLang: targetLang,
          isAudioOnly: isAudioOnly,
        );

        if (mounted && _incomingCallDialogContext == null) {
          _showIncomingCallDialog(
            callerId: callerId,
            callerName: callerName,
            roomId: roomId,
            targetLang: targetLang,
            isAudioOnly: isAudioOnly,
          );
        }
      } else if (event['type'] == 'chat_message') {
        final fromPeerId = (event['from'] ?? event['peer_id'] ?? '').toString();
        final peerName = (event['sender'] ?? 'Practice Partner').toString();
        final msgId = (event['id'] ?? 'msg_${DateTime.now().millisecondsSinceEpoch}').toString();
        final text = (event['text'] ?? '').toString();
        final time = (event['time'] ?? DateTime.now().toIso8601String()).toString();
        final lang = (event['target_lang'] ?? event['language'] ?? 'Spanish').toString();

        if (fromPeerId.isNotEmpty && text.isNotEmpty) {
          DatabaseHelper.instance.saveDirectMessage(
            peerId: fromPeerId,
            peerName: peerName,
            id: msgId,
            text: text,
            time: time,
            isSelf: false,
            language: lang,
          );

          // Show background notification if user is not in the Chats tab
          if (_currentIndex != 1) {
            NotificationService.instance.showChatMessageNotification(
              senderName: peerName,
              messageText: text,
              peerId: fromPeerId,
            );
          }
        }
      } else if (event['type'] == 'call_declined' || event['type'] == 'call_ended') {
        NotificationService.instance.cancelIncomingCallNotification();
        if (_incomingCallDialogContext != null && mounted) {
          Navigator.of(_incomingCallDialogContext!).pop();
          _incomingCallDialogContext = null;
        }
      }
    });
  }

  void _showIncomingCallDialog({
    required String callerId,
    required String callerName,
    required String roomId,
    required String targetLang,
    required bool isAudioOnly,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _incomingCallDialogContext = ctx;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.surfaceDark,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Ringing Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00A884),
                    border: Border.all(color: const Color(0xFF00E676), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      callerName.isNotEmpty ? callerName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Incoming ${isAudioOnly ? "Voice" : "Video"} Call • $targetLang',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                // Accept / Decline Action Row
                Row(
                  children: [
                    // Decline Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          NotificationService.instance.cancelIncomingCallNotification();
                          WebSocketService.instance.send({
                            'type': 'call_declined',
                            'peer_id': callerId,
                            'room_id': roomId,
                          });
                          Navigator.pop(ctx);
                          _incomingCallDialogContext = null;
                        },
                        icon: const Icon(Icons.call_end, size: 20),
                        label: const Text('Decline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Accept Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          NotificationService.instance.cancelIncomingCallNotification();
                          WebSocketService.instance.send({
                            'type': 'call_accepted',
                            'peer_id': callerId,
                            'room_id': roomId,
                            'is_audio_only': isAudioOnly,
                          });
                          Navigator.pop(ctx);
                          _incomingCallDialogContext = null;

                          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                          final match = MatchModel(
                            roomId: roomId,
                            peerId: callerId,
                            peerUsername: callerName,
                            peerNativeLang: targetLang,
                            peerTargetLang: user.nativeLanguageName ?? 'English',
                            isInitiator: false,
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoCallScreen(
                                match: match,
                                peerUsername: callerName,
                                targetLanguage: targetLang,
                                isAudioOnly: isAudioOnly,
                              ),
                            ),
                          );
                        },
                        icon: Icon(isAudioOnly ? Icons.phone : Icons.videocam, size: 20),
                        label: const Text('Accept', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _incomingCallDialogContext = null;
    });
  }

  @override
  void dispose() {
    _incomingCallSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: Row(
              children: [
                // Left Vertical Navigation Rail for Web & Desktop
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceDark,
                    border: Border(
                      right: BorderSide(color: Color(0xFF2A3942), width: 1),
                    ),
                  ),
                  child: NavigationRail(
                    backgroundColor: AppColors.surfaceDark,
                    indicatorColor: AppColors.primaryDark.withValues(alpha: 0.25),
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.language,
                              color: Color(0xFF00E676),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.language, color: Colors.white70),
                        selectedIcon: Icon(Icons.language, color: AppColors.primaryDark),
                        label: Text('Practice', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.white70),
                        selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primaryDark),
                        label: Text('Chats', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.call_outlined, color: Colors.white70),
                        selectedIcon: Icon(Icons.call, color: AppColors.primaryDark),
                        label: Text('Calls', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person_outline, color: Colors.white70),
                        selectedIcon: Icon(Icons.person, color: AppColors.primaryDark),
                        label: Text('Profile', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // Main Page Content spanning remaining viewport width
                Expanded(
                  child: _pages[_currentIndex],
                ),
              ],
            ),
          );
        }

        // Standard Mobile/Narrow Layout: Bottom Navigation Bar
        return Scaffold(
          backgroundColor: AppColors.backgroundDark,
          body: _pages[_currentIndex],
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: NavigationBar(
              backgroundColor: AppColors.surfaceDark,
              indicatorColor: AppColors.primaryDark.withValues(alpha: 0.25),
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.language, color: Colors.white70),
                  selectedIcon: Icon(Icons.language, color: AppColors.primaryDark),
                  label: 'Practice',
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline, color: Colors.white70),
                  selectedIcon: Icon(Icons.chat_bubble, color: AppColors.primaryDark),
                  label: 'Chats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.call_outlined, color: Colors.white70),
                  selectedIcon: Icon(Icons.call, color: AppColors.primaryDark),
                  label: 'Calls',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline, color: Colors.white70),
                  selectedIcon: Icon(Icons.person, color: AppColors.primaryDark),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
