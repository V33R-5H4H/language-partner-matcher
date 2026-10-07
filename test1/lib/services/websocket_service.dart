import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService instance = WebSocketService._init();
  WebSocketService._init();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String _currentUserId = '';
  String _currentWsUrl = '';
  Timer? _reconnectTimer;
  final List<Map<String, dynamic>> _pendingSendQueue = [];

  bool get isConnected => _isConnected;
  String get currentUserId => _currentUserId;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Future<void> connect(String wsUrl, {required String userId}) async {
    _currentWsUrl = wsUrl;
    _currentUserId = userId;
    _reconnectTimer?.cancel();

    if (_isConnected && _channel != null) return;

    try {
      await _closeChannel();
      final uri = Uri.parse(wsUrl);
      debugPrint('WebSocketService: Connecting to signaling server at $uri');

      _channel = WebSocketChannel.connect(uri);
      await _channel?.ready;
      _isConnected = true;

      _subscription = _channel?.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(data.toString());
            debugPrint('WebSocketService: Received event: ${decoded['type']}');
            _messageController.add(decoded);
          } catch (e) {
            debugPrint('WebSocketService: Error decoding message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocketService: Stream error ($error). Scheduling reconnect...');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('WebSocketService: Connection closed. Scheduling reconnect...');
          _handleDisconnect();
        },
      );

      debugPrint('WebSocketService: Connected successfully as user $userId');
      _startHeartbeat();

      // Flush queued messages — but NEVER re-send enqueue/find_match automatically.
      // Those must be explicitly triggered by user action in the UI.
      if (_pendingSendQueue.isNotEmpty) {
        final toSend = List<Map<String, dynamic>>.from(_pendingSendQueue)
            .where((m) => m['type'] != 'enqueue' && m['type'] != 'find_match')
            .toList();
        _pendingSendQueue.clear();
        for (final item in toSend) {
          send(item);
        }
      }
    } catch (e) {
      debugPrint('WebSocketService: Connection error ($e). Retrying in 3s...');
      _handleDisconnect();
    }
  }

  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _channel != null) {
        send({'type': 'ping'});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _handleDisconnect() {
    _isConnected = false;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    if (_currentWsUrl.isNotEmpty && _currentUserId.isNotEmpty) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        if (!_isConnected) {
          connect(_currentWsUrl, userId: _currentUserId);
        }
      });
    }
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null && _isConnected) {
      try {
        final payload = jsonEncode(data);
        _channel?.sink.add(payload);
        debugPrint('WebSocketService: Sent event: ${data['type']}');
      } catch (e) {
        debugPrint('WebSocketService: Error sending data ($e), queued.');
        _pendingSendQueue.add(data);
      }
    } else {
      debugPrint('WebSocketService: Not connected yet. Queuing event: ${data['type']}');
      _pendingSendQueue.add(data);
      if (_currentWsUrl.isNotEmpty && _currentUserId.isNotEmpty) {
        connect(_currentWsUrl, userId: _currentUserId);
      }
    }
  }

  Future<void> _closeChannel() async {
    _isConnected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _currentWsUrl = '';
    _currentUserId = '';
    _pendingSendQueue.clear();
    await _closeChannel();
    debugPrint('WebSocketService: Disconnected cleanly.');
  }
}
