import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/constants/app_colors.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/websocket_service.dart';
import 'video_call_screen.dart';

class OutgoingCallDialog extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String targetLanguage;
  final bool isAudioOnly;

  const OutgoingCallDialog({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.targetLanguage,
    required this.isAudioOnly,
  });

  static Future<void> show(
    BuildContext context, {
    required String peerId,
    required String peerName,
    required String targetLanguage,
    required bool isAudioOnly,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => OutgoingCallDialog(
        peerId: peerId,
        peerName: peerName,
        targetLanguage: targetLanguage,
        isAudioOnly: isAudioOnly,
      ),
    );
  }

  @override
  State<OutgoingCallDialog> createState() => _OutgoingCallDialogState();
}

class _OutgoingCallDialogState extends State<OutgoingCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription? _wsSubscription;
  Timer? _timeoutTimer;
  late String _roomId;
  late String _effectivePeerId;

  String _resolveEffectivePeerId(String peerId, String myUserId) {
    if (peerId.startsWith('user_') && !peerId.contains('_user_')) {
      return peerId;
    }
    final matches = RegExp(r'user_\d+').allMatches(peerId);
    for (final m in matches) {
      final id = m.group(0);
      if (id != null && id != myUserId) {
        return id;
      }
    }
    return peerId;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _effectivePeerId = _resolveEffectivePeerId(widget.peerId, currentUser.userId);
    _roomId = 'room_direct_${currentUser.userId}_${_effectivePeerId}_${DateTime.now().millisecondsSinceEpoch}';

    // Ensure WebSocket is connected
    if (!WebSocketService.instance.isConnected) {
      final wsUrl = ApiEndpoints.signalingSocket(currentUser.userId, 'local_token');
      WebSocketService.instance.connect(wsUrl, userId: currentUser.userId);
    }

    // 1. Send incoming call notification to peer
    WebSocketService.instance.send({
      'type': 'incoming_call_request',
      'caller_id': currentUser.userId,
      'caller_name': currentUser.username,
      'caller_native': currentUser.nativeLanguageName ?? 'English',
      'target_lang': widget.targetLanguage,
      'peer_id': _effectivePeerId,
      'room_id': _roomId,
      'is_audio_only': widget.isAudioOnly,
    });

    // 2. Listen for accept / decline / offline responses
    _wsSubscription = WebSocketService.instance.messages.listen((event) {
      if (!mounted) return;
      final type = event['type'];

      if (type == 'call_accepted') {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();

        final match = MatchModel(
          roomId: _roomId,
          peerId: _effectivePeerId,
          peerUsername: widget.peerName,
          peerNativeLang: widget.targetLanguage,
          peerTargetLang: currentUser.nativeLanguageName ?? 'English',
          isInitiator: true,
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoCallScreen(
              match: match,
              peerUsername: widget.peerName,
              targetLanguage: widget.targetLanguage,
              isAudioOnly: widget.isAudioOnly,
            ),
          ),
        );
      } else if (type == 'call_declined') {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.peerName} is busy or declined the call'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (type == 'peer_unavailable') {
        _timeoutTimer?.cancel();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.peerName} is currently offline'),
            backgroundColor: AppColors.cardDark,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    // 3. Timeout after 35 seconds if no response
    _timeoutTimer = Timer(const Duration(seconds: 35), () {
      if (mounted) {
        _cancelCall(reason: 'No answer from ${widget.peerName}');
      }
    });
  }

  void _cancelCall({String? reason}) {
    _timeoutTimer?.cancel();
    WebSocketService.instance.send({
      'type': 'call_ended',
      'peer_id': _effectivePeerId,
      'room_id': _roomId,
    });

    if (mounted) {
      Navigator.of(context).pop();
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason),
            backgroundColor: AppColors.cardDark,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsSubscription?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surfaceDark,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ringing Avatar with pulsing animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.06);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 90,
                    height: 90,
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
                        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Peer Name
            Text(
              widget.peerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            // Call Mode & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isAudioOnly ? Icons.mic : Icons.videocam,
                  color: AppColors.primaryLight,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Calling • ${widget.targetLanguage}...',
                  style: const TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Ringing partner\'s device',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),

            // Cancel / End Call Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _cancelCall(reason: 'Call cancelled'),
                icon: const Icon(Icons.call_end, size: 20),
                label: const Text(
                  'Cancel Call',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
