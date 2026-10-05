import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/api_endpoints.dart';
import 'websocket_service.dart';

class WebRTCService {
  static final WebRTCService instance = WebRTCService._init();
  WebRTCService._init();

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  StreamSubscription? _wsSubscription;

  bool _isInitialized = false;
  bool _isCameraMuted = false;
  bool _isMicMuted = false;
  bool _hasRemoteDescriptionSet = false;
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  String _targetPeerId = '';
  String _currentRoomId = '';
  String? _lastOfferSdp;
  bool _isInitiator = false;
  String _localUsername = 'You';
  String _peerUsername = 'Partner';

  bool get isInitialized => _isInitialized;
  bool get isCameraMuted => _isCameraMuted;
  bool get isMicMuted => _isMicMuted;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCDataChannel? get dataChannel => _dataChannel;
  String get localUsername => _localUsername;
  String get peerUsername => _peerUsername;

  // Persistent in-call chat history during an active session
  final List<Map<String, dynamic>> chatHistory = [];

  // Reactive stream notifiers for UI
  final ValueNotifier<MediaStream?> localStreamNotifier = ValueNotifier<MediaStream?>(null);
  final ValueNotifier<MediaStream?> remoteStreamNotifier = ValueNotifier<MediaStream?>(null);

  // Reactive connection state notifiers
  final ValueNotifier<RTCIceConnectionState> iceConnectionStateNotifier =
      ValueNotifier<RTCIceConnectionState>(RTCIceConnectionState.RTCIceConnectionStateNew);
  final ValueNotifier<String> connectionStatusTextNotifier =
      ValueNotifier<String>('Connecting...');

  // Stream for real-time in-call text messages received over DataChannel or WebSocket
  final _inCallMessageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get inCallMessages => _inCallMessageController.stream;

  // STUN & TURN Configuration (dynamically refreshed from backend)
  final Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {'urls': 'stun:global.stun.twilio.com:3478'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  /// Fetch dynamic TURN/STUN ICE servers from backend
  Future<void> fetchIceServers({String? userId}) async {
    try {
      final user = userId ?? _localUsername;
      final uri = Uri.parse('${ApiEndpoints.iceServers}?user_id=$user');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['iceServers'] is List) {
          rtcConfiguration['iceServers'] = data['iceServers'];
          debugPrint('WebRTCService: Dynamic TURN/STUN ICE servers configured successfully.');
        }
      }
    } catch (e) {
      debugPrint('WebRTCService: Using fallback STUN servers (ICE fetch notice: $e)');
    }
  }

  /// Initialize video renderers for local and remote streams
  Future<void> initializeRenderers() async {
    if (_isInitialized) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _isInitialized = true;
      debugPrint('WebRTCService: Renderers initialized successfully.');
    } catch (e) {
      debugPrint('WebRTCService: Error initializing renderers: $e');
    }
  }

  /// Request hardware permissions and start camera & microphone stream
  Future<bool> startLocalMedia({bool isAudioOnly = false}) async {
    try {
      await initializeRenderers();

      if (!kIsWeb) {
        try {
          await Permission.camera.request();
          await Permission.microphone.request();
        } catch (e) {
          debugPrint('WebRTCService: Permission request warning: $e');
        }
      }

      final mediaConstraints = <String, dynamic>{
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'highpassFilter': true,
        },
        'video': isAudioOnly
            ? false
            : {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'idealWidth': '1280',
                  'idealHeight': '720',
                  'minFrameRate': '24',
                  'maxFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              },
      };

      try {
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      } catch (camError) {
        debugPrint('WebRTCService: Primary camera stream failed ($camError), falling back...');
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': true});
        } catch (camError2) {
          debugPrint('WebRTCService: Video stream fallback failed ($camError2), starting audio-only...');
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
        }
      }

      if (_localStream != null) {
        localRenderer.srcObject = _localStream;
        localStreamNotifier.value = _localStream;
      }
      _isMicMuted = false;
      _isCameraMuted = false;

      debugPrint('WebRTCService: Local camera & audio stream ready.');
      return true;
    } catch (e) {
      debugPrint('WebRTCService: Media capture error: $e');
      return false;
    }
  }

  /// Initialize PeerConnection and establish WebRTC session
  Future<void> startCall({
    required String roomId,
    required String peerId,
    required bool isInitiator,
    String localUsername = 'You',
    String peerUsername = 'Practice Partner',
    bool isAudioOnly = false,
  }) async {
    _currentRoomId = roomId;
    _targetPeerId = peerId;
    _isInitiator = isInitiator;
    _localUsername = localUsername;
    _peerUsername = peerUsername;
    _hasRemoteDescriptionSet = false;
    _pendingIceCandidates.clear();
    _lastOfferSdp = null;

    // Reset connection status text
    connectionStatusTextNotifier.value = 'Connecting...';
    iceConnectionStateNotifier.value = RTCIceConnectionState.RTCIceConnectionStateNew;

    // Listen for WebSocket signaling messages immediately
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService.instance.messages.listen(_handleSignalingMessage);

    await startLocalMedia(isAudioOnly: isAudioOnly);
    await fetchIceServers(userId: localUsername);

    try {
      // Close previous peer connection if any
      if (_peerConnection != null) {
        await _peerConnection?.close();
        _peerConnection = null;
      }

      _peerConnection = await createPeerConnection(rtcConfiguration);

      // Add local tracks to peer connection (Unified-Plan)
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection?.addTrack(track, _localStream!);
        }
      }

      // Handle Remote Tracks (Unified-Plan)
      _peerConnection?.onTrack = (RTCTrackEvent event) async {
        debugPrint('WebRTCService: onTrack received kind=${event.track.kind}, streams=${event.streams.length}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
        } else {
          _remoteStream ??= await createLocalMediaStream('remote_stream_${DateTime.now().millisecondsSinceEpoch}');
          await _remoteStream!.addTrack(event.track);
        }
        event.track.enabled = true;
        remoteRenderer.srcObject = null;
        remoteRenderer.srcObject = _remoteStream;
        remoteStreamNotifier.value = _remoteStream;
        connectionStatusTextNotifier.value = 'Connected';
        debugPrint('WebRTCService: Remote track (${event.track.kind}) successfully bound to remoteRenderer.');
      };

      // Handle ICE Candidates
      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        WebSocketService.instance.send({
          'type': 'ice_candidate',
          'peer_id': _targetPeerId,
          'room_id': _currentRoomId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      };

      _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('WebRTCService: PeerConnection state -> $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          connectionStatusTextNotifier.value = 'Connected';
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnecting) {
          connectionStatusTextNotifier.value = 'Connecting...';
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          connectionStatusTextNotifier.value = 'Reconnecting...';
          _attemptIceRestart();
        }
      };

      _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        debugPrint('WebRTCService: ICE Connection state -> $state');
        iceConnectionStateNotifier.value = state;
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          connectionStatusTextNotifier.value = 'Connected';
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
          connectionStatusTextNotifier.value = 'Connecting...';
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          connectionStatusTextNotifier.value = 'Reconnecting...';
          _attemptIceRestart();
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          connectionStatusTextNotifier.value = 'Connection Lost';
          _attemptIceRestart();
        }
      };

      // Announce readiness to peer
      WebSocketService.instance.send({
        'type': 'peer_ready',
        'peer_id': _targetPeerId,
        'room_id': _currentRoomId,
      });

      if (isInitiator) {
        // Create DataChannel for instant chat
        final dcInit = RTCDataChannelInit()..ordered = true;
        _dataChannel = await _peerConnection?.createDataChannel('chat', dcInit);
        _setupDataChannel(_dataChannel);

        // Create SDP Offer with optimized Opus audio
        final offer = await _peerConnection!.createOffer({
          'offerToReceiveVideo': 1,
          'offerToReceiveAudio': 1,
        });
        final optimizedSdp = _optimizeSdpAudio(offer.sdp);
        final optimizedOffer = RTCSessionDescription(optimizedSdp, offer.type);
        _lastOfferSdp = optimizedSdp;
        await _peerConnection!.setLocalDescription(optimizedOffer);

        WebSocketService.instance.send({
          'type': 'offer',
          'peer_id': _targetPeerId,
          'room_id': _currentRoomId,
          'sdp': optimizedSdp,
        });
        debugPrint('WebRTCService: Sent optimized SDP Offer to peer $_targetPeerId');
      } else {
        // Handle incoming DataChannel on receiver side
        _peerConnection?.onDataChannel = (RTCDataChannel channel) {
          _dataChannel = channel;
          _setupDataChannel(_dataChannel);
        };
      }
    } catch (e) {
      debugPrint('WebRTCService: Error starting call: $e');
    }
  }

  bool _isRestartingIce = false;

  Future<void> _attemptIceRestart() async {
    if (_isRestartingIce || _peerConnection == null || !_isInitiator) return;
    _isRestartingIce = true;
    debugPrint('WebRTCService: Attempting automatic ICE restart for room $_currentRoomId...');
    try {
      final offer = await _peerConnection!.createOffer({
        'iceRestart': true,
        'offerToReceiveVideo': 1,
        'offerToReceiveAudio': 1,
      });
      final optimizedSdp = _optimizeSdpAudio(offer.sdp);
      final restartOffer = RTCSessionDescription(optimizedSdp, offer.type);
      await _peerConnection!.setLocalDescription(restartOffer);
      WebSocketService.instance.send({
        'type': 'offer',
        'peer_id': _targetPeerId,
        'room_id': _currentRoomId,
        'sdp': optimizedSdp,
      });
      debugPrint('WebRTCService: ICE restart offer dispatched successfully.');
    } catch (e) {
      debugPrint('WebRTCService: Error during ICE restart: $e');
    } finally {
      await Future.delayed(const Duration(seconds: 4));
      _isRestartingIce = false;
    }
  }

  // Track received message IDs to prevent duplicates between DataChannel and WebSocket
  final Set<String> _receivedMessageIds = <String>{};

  void _addIncomingChatMessage({
    required String id,
    required String sender,
    required String text,
    required String time,
  }) {
    if (id.isNotEmpty && _receivedMessageIds.contains(id)) {
      debugPrint('WebRTCService: Duplicate message ignored ($id).');
      return;
    }
    if (id.isNotEmpty) {
      _receivedMessageIds.add(id);
    }
    final effectiveSender = (sender.isNotEmpty && sender != 'Partner' && sender != 'Practice Partner')
        ? sender
        : (_peerUsername.isNotEmpty ? _peerUsername : 'Partner');

    final messageData = {
      'id': id,
      'sender': effectiveSender,
      'text': text,
      'time': time,
      'isSelf': false,
    };
    chatHistory.add(messageData);
    _inCallMessageController.add(messageData);
  }

  void _setupDataChannel(RTCDataChannel? channel) {
    if (channel == null) return;
    channel.onMessage = (RTCDataChannelMessage message) {
      debugPrint('WebRTCService: Raw message on DataChannel: ${message.text}');
      try {
        final Map<String, dynamic> data = jsonDecode(message.text);
        _addIncomingChatMessage(
          id: data['id']?.toString() ?? '',
          sender: data['sender'] ?? _peerUsername,
          text: data['text'] ?? message.text,
          time: data['time'] ?? DateTime.now().toIso8601String(),
        );
      } catch (_) {
        _addIncomingChatMessage(
          id: '',
          sender: _peerUsername,
          text: message.text,
          time: DateTime.now().toIso8601String(),
        );
      }
    };
  }

  Future<void> _handleSignalingMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    final from = data['from'] ?? data['peer_id'];

    try {
      if (type == 'peer_ready') {
        debugPrint('WebRTCService: Peer $from announced ready.');
        // If initiator and offer already created, re-send offer to ensure handshake completes
        if (_isInitiator && _lastOfferSdp != null && _peerConnection != null) {
          WebSocketService.instance.send({
            'type': 'offer',
            'peer_id': _targetPeerId,
            'room_id': _currentRoomId,
            'sdp': _lastOfferSdp,
          });
          debugPrint('WebRTCService: Re-sent SDP Offer following peer_ready.');
        }
      } else if (type == 'offer') {
        final sdp = data['sdp'];
        if (_peerConnection == null) {
          debugPrint('WebRTCService: Received offer before PeerConnection ready. Waiting...');
          await Future.delayed(const Duration(milliseconds: 300));
        }
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _hasRemoteDescriptionSet = true;
        await _flushPendingIceCandidates();

        final answer = await _peerConnection!.createAnswer({
          'offerToReceiveVideo': 1,
          'offerToReceiveAudio': 1,
        });
        final optimizedAnswerSdp = _optimizeSdpAudio(answer.sdp);
        final optimizedAnswer = RTCSessionDescription(optimizedAnswerSdp, answer.type);
        await _peerConnection!.setLocalDescription(optimizedAnswer);

        WebSocketService.instance.send({
          'type': 'answer',
          'peer_id': from,
          'room_id': _currentRoomId,
          'sdp': optimizedAnswerSdp,
        });
        debugPrint('WebRTCService: Sent optimized SDP Answer to peer $from');
      } else if (type == 'answer') {
        final sdp = data['sdp'];
        await _peerConnection?.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _hasRemoteDescriptionSet = true;
        await _flushPendingIceCandidates();
        debugPrint('WebRTCService: Received & applied SDP Answer from peer $from');
      } else if (type == 'ice_candidate') {
        final candData = data['candidate'];
        if (candData != null && candData['candidate'] != null) {
          final candidateStr = candData['candidate'].toString();
          final candidate = RTCIceCandidate(
            candidateStr,
            candData['sdpMid'],
            candData['sdpMLineIndex'],
          );
          if (_hasRemoteDescriptionSet && _peerConnection != null) {
            await _peerConnection?.addCandidate(candidate);
          } else {
            _pendingIceCandidates.add(candidate);
          }

          // Android Emulator Localhost NAT Bridge:
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && candidateStr.contains('127.0.0.1')) {
            final emuCandidate = RTCIceCandidate(
              candidateStr.replaceAll('127.0.0.1', '10.0.2.2'),
              candData['sdpMid'],
              candData['sdpMLineIndex'],
            );
            if (_hasRemoteDescriptionSet && _peerConnection != null) {
              await _peerConnection?.addCandidate(emuCandidate);
            } else {
              _pendingIceCandidates.add(emuCandidate);
            }
          }
        }
      } else if (type == 'chat_message') {
        _addIncomingChatMessage(
          id: data['id']?.toString() ?? '',
          sender: data['sender'] ?? _peerUsername,
          text: data['text'] ?? '',
          time: data['time'] ?? DateTime.now().toIso8601String(),
        );
      }
    } catch (e) {
      debugPrint('WebRTCService: Error handling signaling message: $e');
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('WebRTCService: Error flushing pending ICE candidate: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  /// Send in-call chat message via WebRTC DataChannel with guaranteed WebSocket delivery
  void sendChatMessage(String text) {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
    final timeStr = DateTime.now().toIso8601String();

    _receivedMessageIds.add(msgId);

    final messageData = {
      'id': msgId,
      'sender': 'You',
      'text': text,
      'time': timeStr,
      'isSelf': true,
    };
    chatHistory.add(messageData);
    _inCallMessageController.add(messageData);

    // 1. Send via DataChannel if open
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      try {
        _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
          'id': msgId,
          'text': text,
          'time': timeStr,
          'sender': _localUsername.isNotEmpty ? _localUsername : 'Partner',
        })));
        debugPrint('WebRTCService: Sent message over DataChannel.');
      } catch (e) {
        debugPrint('WebRTCService: DataChannel send error: $e');
      }
    }

    // 2. Always relay over WebSocket to ensure reliable delivery across Android Emulator and Web local network
    if (_targetPeerId.isNotEmpty) {
      WebSocketService.instance.send({
        'type': 'chat_message',
        'id': msgId,
        'peer_id': _targetPeerId,
        'room_id': _currentRoomId,
        'text': text,
        'sender': _localUsername.isNotEmpty ? _localUsername : 'Partner',
        'time': timeStr,
      });
      debugPrint('WebRTCService: Relayed message over WebSocket to peer $_targetPeerId');
    }
  }

  /// Toggle speakerphone on mobile devices
  Future<void> setSpeakerphoneOn(bool enable) async {
    try {
      if (!kIsWeb) {
        await Helper.setSpeakerphoneOn(enable);
        debugPrint('WebRTCService: Speakerphone set to $enable');
      }
    } catch (e) {
      debugPrint('WebRTCService: Error toggling speakerphone: $e');
    }
  }

  /// Toggle microphone mute
  void toggleMicrophone(bool mute) {
    _isMicMuted = mute;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !mute;
      }
      debugPrint('WebRTCService: Microphone ${mute ? "muted" : "unmuted"}.');
    }
  }

  /// Toggle camera video on/off
  void toggleCamera(bool disableVideo) {
    _isCameraMuted = disableVideo;
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = !disableVideo;
      }
      debugPrint('WebRTCService: Camera video ${disableVideo ? "disabled" : "enabled"}.');
    }
  }

  /// Switch between front and back camera
  Future<bool> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks().first;
      try {
        await Helper.switchCamera(videoTrack);
        debugPrint('WebRTCService: Switched camera via Helper.switchCamera.');
        return true;
      } catch (e) {
        debugPrint('WebRTCService: Helper.switchCamera failed: $e, attempting fallback...');
        try {
          // ignore: deprecated_member_use
          await videoTrack.switchCamera();
          debugPrint('WebRTCService: Switched camera via videoTrack.switchCamera.');
          return true;
        } catch (e2) {
          debugPrint('WebRTCService: Switch camera not supported on this device: $e2');
          return false;
        }
      }
    }
    return false;
  }

  /// Convert ongoing call between Voice-Only mode (saves battery/bandwidth) and Video mode
  Future<bool> switchCallMode({required bool isAudioOnly}) async {
    try {
      debugPrint('WebRTCService: Switching call mode to isAudioOnly=$isAudioOnly');
      if (isAudioOnly) {
        // Disable local camera track completely to conserve CPU/GPU/network resources
        toggleCamera(true);
      } else {
        // Switching to Video Mode: Ensure camera track is active and available
        if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
          toggleCamera(false);
        } else {
          // Camera track wasn't captured initially (call started audio-only)
          try {
            final camStream = await navigator.mediaDevices.getUserMedia({
              'audio': false,
              'video': {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'idealWidth': '1280',
                  'idealHeight': '720',
                  'minFrameRate': '24',
                  'maxFrameRate': '30',
                },
                'facingMode': 'user',
              },
            });
            if (camStream.getVideoTracks().isNotEmpty) {
              final newVideoTrack = camStream.getVideoTracks().first;
              _localStream?.addTrack(newVideoTrack);
              if (_peerConnection != null && _localStream != null) {
                await _peerConnection!.addTrack(newVideoTrack, _localStream!);
              }
              localRenderer.srcObject = _localStream;
              localStreamNotifier.value = _localStream;
            }
          } catch (camErr) {
            debugPrint('WebRTCService: Error acquiring video track on upgrade: $camErr');
          }
        }
      }

      // Notify remote peer of call mode switch
      if (_targetPeerId.isNotEmpty && _currentRoomId.isNotEmpty) {
        WebSocketService.instance.send({
          'type': 'call_mode_changed',
          'room_id': _currentRoomId,
          'peer_id': _targetPeerId,
          'is_audio_only': isAudioOnly,
        });
      }
      return true;
    } catch (e) {
      debugPrint('WebRTCService: Error switching call mode: $e');
      return false;
    }
  }

  /// Clean up media streams and renderers safely
  Future<void> dispose() async {
    try {
      if (_targetPeerId.isNotEmpty && _currentRoomId.isNotEmpty) {
        WebSocketService.instance.send({
          'type': 'call_ended',
          'peer_id': _targetPeerId,
          'room_id': _currentRoomId,
        });
      }

      await _wsSubscription?.cancel();
      _wsSubscription = null;

      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
      _localStream = null;
      localStreamNotifier.value = null;

      _remoteStream?.getTracks().forEach((track) => track.stop());
      await _remoteStream?.dispose();
      _remoteStream = null;
      remoteStreamNotifier.value = null;

      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;

      await _peerConnection?.close();
      _peerConnection = null;

      await _dataChannel?.close();
      _dataChannel = null;

      _receivedMessageIds.clear();
      _pendingIceCandidates.clear();
      chatHistory.clear();
      _hasRemoteDescriptionSet = false;
      _lastOfferSdp = null;

      _targetPeerId = '';
      _currentRoomId = '';

      debugPrint('WebRTCService: Cleaned up and disposed all media streams.');
    } catch (e) {
      debugPrint('WebRTCService: Error disposing streams: $e');
    }
  }

  /// Optimize Opus audio parameters in SDP for high-resilience voice call
  String? _optimizeSdpAudio(String? sdp) {
    if (sdp == null || sdp.isEmpty) return sdp;
    try {
      final lines = sdp.split('\r\n');
      final newLines = <String>[];
      for (final line in lines) {
        if (line.startsWith('a=fmtp:') && line.contains('opus/48000') || (line.startsWith('a=fmtp:111') || line.startsWith('a=fmtp:96') || line.startsWith('a=fmtp:97'))) {
          // If Opus fmtp line, ensure forward error correction & discontinuous transmission are set
          if (!line.contains('useinbandfec=1')) {
            newLines.add('$line;useinbandfec=1;usedtx=1;minptime=10');
            continue;
          }
        }
        newLines.add(line);
      }
      return newLines.join('\r\n');
    } catch (e) {
      debugPrint('WebRTCService: Error optimizing SDP: $e');
      return sdp;
    }
  }
}
