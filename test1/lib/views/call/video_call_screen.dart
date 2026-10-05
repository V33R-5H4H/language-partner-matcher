import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/webrtc_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/call_controls_bar.dart';
import '../../widgets/video_render_box.dart';
import 'in_call_chat_sheet.dart';

class VideoCallScreen extends StatefulWidget {
  final MatchModel? match;
  final String peerUsername;
  final String targetLanguage;
  final bool isAudioOnly;

  const VideoCallScreen({
    super.key,
    this.match,
    this.peerUsername = 'Practice Partner',
    this.targetLanguage = 'Spanish',
    this.isAudioOnly = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  bool _isRemoteMicMuted = false;
  bool _isRemoteVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isPipSwapped = false;
  late bool _isAudioOnly;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _inCallMessageSub;
  bool _isLoadingMedia = true;
  late AnimationController _waveformController;
  int _unreadChatCount = 0;
  bool _isChatOpen = false;
  String? _recentMessageToast;
  Timer? _recentMessageTimer;

  String get _effectivePeerName =>
      widget.match?.peerUsername ?? widget.peerUsername;
  String get _effectiveTargetLang =>
      widget.match?.peerNativeLang ?? widget.targetLanguage;

  @override
  void initState() {
    super.initState();
    _isAudioOnly = widget.isAudioOnly;
    WidgetsBinding.instance.addObserver(this);
    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WebRTCService.instance.remoteStreamNotifier.addListener(_onStreamChanged);
    WebRTCService.instance.localStreamNotifier.addListener(_onStreamChanged);
    _initializeCallMediaAndSession();
    _startDurationTimer();
    _listenForRemoteCallEnded();
    _listenForInCallMessages();
  }

  void _listenForInCallMessages() {
    _inCallMessageSub = WebRTCService.instance.inCallMessages.listen((msg) {
      if (mounted) {
        final sender = (msg['sender'] != null &&
                msg['sender'] != 'Partner' &&
                msg['sender'] != 'Practice Partner')
            ? msg['sender'].toString()
            : (msg['isSelf'] == true ? 'You' : _effectivePeerName);
        final text = msg['text']?.toString() ?? '';

        if (!_isChatOpen) {
          setState(() {
            _unreadChatCount++;
            _recentMessageToast = '$sender: $text';
          });
          _recentMessageTimer?.cancel();
          _recentMessageTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              setState(() => _recentMessageToast = null);
            }
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (!_isVideoOff && !_isAudioOnly) {
        WebRTCService.instance.toggleCamera(true);
        _sendMediaState(isMicMuted: _isMicMuted, isVideoOff: true);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_isVideoOff && !_isAudioOnly) {
        WebRTCService.instance.toggleCamera(false);
        _sendMediaState(isMicMuted: _isMicMuted, isVideoOff: false);
      }
    }
  }

  void _onStreamChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeCallMediaAndSession() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (widget.match != null) {
      await WebRTCService.instance.startCall(
        roomId: widget.match!.roomId,
        peerId: widget.match!.peerId,
        isInitiator: widget.match!.isInitiator,
        localUsername: user.username,
        peerUsername: _effectivePeerName,
        isAudioOnly: _isAudioOnly,
      );
    } else {
      await WebRTCService.instance.startLocalMedia(isAudioOnly: _isAudioOnly);
    }

    if (mounted) {
      setState(() {
        _isLoadingMedia = false;
      });
    }

    // Connection timeout fallback: if remote stream not received in 25s, exit cleanly
    Timer(const Duration(seconds: 25), () {
      if (mounted && WebRTCService.instance.remoteStreamNotifier.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partner did not connect. Returning to discovery...'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 3),
          ),
        );
        _endCall(isRemoteTriggered: true);
      }
    });
  }

  void _listenForRemoteCallEnded() {
    _wsSubscription = WebSocketService.instance.messages.listen((event) {
      final type = event['type'];
      if (type == 'call_ended' ||
          type == 'peer_disconnected' ||
          type == 'call_declined' ||
          type == 'peer_left_radar' ||
          type == 'peer_unavailable') {
        if (mounted) {
          final isDeclined = type == 'call_declined';
          final isUnavailable = type == 'peer_unavailable' || type == 'peer_left_radar';
          String msg = 'Partner ended the call';
          if (isDeclined) msg = 'Partner declined the call';
          if (isUnavailable) msg = 'Partner went offline or stopped scanning';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.danger,
              duration: const Duration(seconds: 3),
            ),
          );
          _endCall(isRemoteTriggered: true);
        }
      } else if (event['type'] == 'media_state_changed') {
        if (mounted) {
          setState(() {
            if (event.containsKey('is_mic_muted')) {
              _isRemoteMicMuted = event['is_mic_muted'] == true;
            }
            if (event.containsKey('is_video_off')) {
              _isRemoteVideoOff = event['is_video_off'] == true;
            }
          });
        }
      } else if (event['type'] == 'call_mode_changed') {
        if (mounted) {
          final remoteAudioOnly = event['is_audio_only'] == true;
          setState(() {
            _isAudioOnly = remoteAudioOnly;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    remoteAudioOnly ? Icons.phone_in_talk : Icons.videocam,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remoteAudioOnly
                        ? '$_effectivePeerName switched to Voice Mode (Data Saver)'
                        : '$_effectivePeerName switched to Video Call',
                  ),
                ],
              ),
              backgroundColor: AppColors.primaryDark,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _sendMediaState({required bool isMicMuted, required bool isVideoOff}) {
    if (widget.match != null) {
      WebSocketService.instance.send({
        'type': 'media_state_changed',
        'room_id': widget.match!.roomId,
        'peer_id': widget.match!.peerId,
        'is_mic_muted': isMicMuted,
        'is_video_off': isVideoOff,
      });
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _onToggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    WebRTCService.instance.setSpeakerphoneOn(_isSpeakerOn);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isSpeakerOn ? Icons.volume_up : Icons.hearing,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(_isSpeakerOn ? 'Speakerphone ON' : 'Earpiece Mode Active'),
          ],
        ),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _onToggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    WebRTCService.instance.toggleMicrophone(_isMicMuted);
    _sendMediaState(isMicMuted: _isMicMuted, isVideoOff: _isVideoOff);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isMicMuted ? Icons.mic_off : Icons.mic,
              color: _isMicMuted ? AppColors.danger : AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(_isMicMuted ? 'Microphone Muted' : 'Microphone Unmuted'),
          ],
        ),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _onToggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    WebRTCService.instance.toggleCamera(_isVideoOff);
    _sendMediaState(isMicMuted: _isMicMuted, isVideoOff: _isVideoOff);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isVideoOff ? Icons.videocam_off : Icons.videocam,
              color: _isVideoOff ? AppColors.danger : AppColors.success,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(_isVideoOff ? 'Video Paused (Camera Off)' : 'Video Resumed (Camera On)'),
          ],
        ),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  Future<void> _onToggleCallMode() async {
    final newMode = !_isAudioOnly;
    setState(() {
      _isAudioOnly = newMode;
    });
    await WebRTCService.instance.switchCallMode(isAudioOnly: newMode);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(newMode ? Icons.phone_in_talk : Icons.videocam, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                newMode
                    ? 'Switched to Voice-Only Mode (Conserving Battery & Data)'
                    : 'Switched to Video Call (Camera Active)',
              ),
            ],
          ),
          backgroundColor: AppColors.primaryDark,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _onSwitchCamera() async {
    final success = await WebRTCService.instance.switchCamera();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera switch not supported on this device/browser'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _endCall({bool isRemoteTriggered = false}) async {
    _durationTimer?.cancel();
    _wsSubscription?.cancel();
    await WebRTCService.instance.dispose();

    // Persist completed call to Call History
    if (_callDurationSeconds > 0) {
      await DatabaseHelper.instance.insertSession({
        'session_id': widget.match?.roomId ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
        'peer_id': widget.match?.peerId ?? '',
        'peer_name': _effectivePeerName,
        'language': _effectiveTargetLang,
        'duration_seconds': _callDurationSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      if (!isRemoteTriggered) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Call ended • Duration: ${_formatDuration(_callDurationSeconds)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  void _openInCallChat() async {
    setState(() {
      _unreadChatCount = 0;
      _recentMessageToast = null;
    });
    _isChatOpen = true;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InCallChatSheet(peerUsername: _effectivePeerName),
    );
    _isChatOpen = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _waveformController.dispose();
    WebRTCService.instance.remoteStreamNotifier.removeListener(_onStreamChanged);
    WebRTCService.instance.localStreamNotifier.removeListener(_onStreamChanged);
    _durationTimer?.cancel();
    _wsSubscription?.cancel();
    _inCallMessageSub?.cancel();
    _recentMessageTimer?.cancel();
    WebRTCService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111B21),
      body: _isAudioOnly ? _buildVoiceCallLayout() : _buildVideoCallLayout(),
    );
  }

  Widget _buildVoiceCallLayout() {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      children: [
        // Top Header
        Positioned(
          top: topInset + 14,
          left: 16,
          right: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: _buildCallHeader(isVoice: true),
            ),
          ),
        ),

        // Central Waveform Avatar
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _waveformController,
                  builder: (context, child) {
                    final scale = 1.0 + (_waveformController.value * 0.08);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Concentric audio wave rings
                        Container(
                          width: 155 * scale,
                          height: 155 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00A884).withValues(alpha: 0.10 * (1 - _waveformController.value)),
                          ),
                        ),
                        Container(
                          width: 130 * scale,
                          height: 130 * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00A884).withValues(alpha: 0.18 * (1 - _waveformController.value)),
                          ),
                        ),
                        // Main Avatar
                        Container(
                          width: 100,
                          height: 100,
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
                              _effectivePeerName.isNotEmpty ? _effectivePeerName[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  _effectivePeerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202C33),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A3942)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic, color: Color(0xFF00E676), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Voice Exchange • $_effectiveTargetLang',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_isRemoteMicMuted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic_off, color: AppColors.danger, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$_effectivePeerName is muted',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isMicMuted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic_off, color: Colors.orange, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Your microphone is muted',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  _formatDuration(_callDurationSeconds),
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),

        // Connection Status Banner
        _buildConnectionStatusPill(topInset),

        // Floating In-Call Message Notification Pill
        if (_recentMessageToast != null) _buildRecentMessageToast(topInset),

        // Bottom Controls
        Positioned(
          bottom: bottomInset + 24,
          left: 0,
          right: 0,
          child: CallControlsBar(
            isMicMuted: _isMicMuted,
            isVideoOff: true,
            isSpeakerOn: _isSpeakerOn,
            isAudioOnlyMode: true,
            unreadMessageCount: _unreadChatCount,
            onToggleMic: _onToggleMic,
            onToggleVideo: _onToggleCallMode,
            onSwitchCamera: () {},
            onToggleSpeaker: _onToggleSpeaker,
            onToggleCallMode: _onToggleCallMode,
            onOpenChat: _openInCallChat,
            onEndCall: _endCall,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCallLayout() {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final mainRenderer = _isPipSwapped
        ? WebRTCService.instance.localRenderer
        : WebRTCService.instance.remoteRenderer;
    final mainIsLocal = _isPipSwapped;
    final mainLabel = _isPipSwapped ? 'You' : '$_effectivePeerName ($_effectiveTargetLang)';
    final mainIsVideoOff = _isPipSwapped ? _isVideoOff : _isRemoteVideoOff;
    final mainIsMicMuted = _isPipSwapped ? _isMicMuted : _isRemoteMicMuted;

    final pipRenderer = _isPipSwapped
        ? WebRTCService.instance.remoteRenderer
        : WebRTCService.instance.localRenderer;
    final pipIsLocal = !_isPipSwapped;
    final pipLabel = _isPipSwapped ? _effectivePeerName : 'You';
    final pipIsVideoOff = !_isPipSwapped ? _isVideoOff : _isRemoteVideoOff;
    final pipIsMicMuted = !_isPipSwapped ? _isMicMuted : _isRemoteMicMuted;

    return Stack(
      children: [
        // Main Video Fullscreen Spanning (True edge-to-edge)
        Positioned.fill(
          child: VideoRenderBox(
            renderer: mainRenderer,
            isLocal: mainIsLocal,
            isVideoOff: mainIsVideoOff,
            isMicMuted: mainIsMicMuted,
            showTopBadges: false,
            label: mainLabel,
          ),
        ),

        // Top Header
        Positioned(
          top: topInset + 12,
          left: 16,
          right: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _buildCallHeader(isVoice: false),
            ),
          ),
        ),

        // Connection Status Banner
        _buildConnectionStatusPill(topInset),

        // Floating In-Call Message Notification Pill
        if (_recentMessageToast != null) _buildRecentMessageToast(topInset),

        // Picture-in-Picture (PiP) Overlay with interactive swap
        Positioned(
          top: topInset + 64,
          right: 16,
          width: 110,
          height: 160,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isPipSwapped = !_isPipSwapped;
              });
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111B21),
                  border: Border.all(color: const Color(0xFF00E676), width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: VideoRenderBox(
                        renderer: pipRenderer,
                        isLocal: pipIsLocal,
                        isVideoOff: pipIsVideoOff,
                        isMicMuted: pipIsMicMuted,
                        showTopBadges: true,
                        label: pipLabel,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_isLoadingMedia)
          Positioned(
            bottom: bottomInset + 88,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Connecting media stream...',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Call Controls Overlay
        Positioned(
          bottom: bottomInset + 20,
          left: 0,
          right: 0,
          child: CallControlsBar(
            isMicMuted: _isMicMuted,
            isVideoOff: _isVideoOff,
            isSpeakerOn: _isSpeakerOn,
            isAudioOnlyMode: false,
            unreadMessageCount: _unreadChatCount,
            onToggleMic: _onToggleMic,
            onToggleVideo: _onToggleVideo,
            onSwitchCamera: _onSwitchCamera,
            onToggleSpeaker: _onToggleSpeaker,
            onToggleCallMode: _onToggleCallMode,
            onOpenChat: _openInCallChat,
            onEndCall: _endCall,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentMessageToast(double topInset) {
    return Positioned(
      top: topInset + 60,
      left: 20,
      right: 20,
      child: Center(
        child: GestureDetector(
          onTap: _openInCallChat,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2C34).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E676), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _recentMessageToast ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: Color(0xFF00E676),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatusPill(double topInset) {
    return Positioned(
      top: topInset + 58,
      left: 0,
      right: 0,
      child: Center(
        child: ValueListenableBuilder<String>(
          valueListenable: WebRTCService.instance.connectionStatusTextNotifier,
          builder: (context, statusText, _) {
            if (statusText == 'Connected') {
              return const SizedBox.shrink();
            }
            final isReconnecting = statusText.contains('Reconnecting') || statusText.contains('Lost');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isReconnecting
                    ? AppColors.danger.withValues(alpha: 0.9)
                    : AppColors.surfaceDark.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isReconnecting ? AppColors.danger : Colors.white24,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCallHeader({required bool isVoice}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _effectivePeerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isRemoteMicMuted) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.mic_off, size: 14, color: AppColors.danger),
                ],
                if (!isVoice && _isRemoteVideoOff) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.videocam_off, size: 14, color: AppColors.danger),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSpeakerOn ? Icons.volume_up : Icons.hearing,
                size: 14,
                color: _isSpeakerOn ? AppColors.primaryLight : Colors.white70,
              ),
              const SizedBox(width: 6),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _formatDuration(_callDurationSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
