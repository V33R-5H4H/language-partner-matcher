class ApiEndpoints {
  static String _sanitizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('ws:') && !trimmed.startsWith('ws://')) {
      trimmed = trimmed.replaceFirst('ws:', 'ws://');
    } else if (trimmed.startsWith('wss:') && !trimmed.startsWith('wss://')) {
      trimmed = trimmed.replaceFirst('wss:', 'wss://');
    } else if (trimmed.startsWith('http:') && !trimmed.startsWith('http://')) {
      trimmed = trimmed.replaceFirst('http:', 'http://');
    } else if (trimmed.startsWith('https:') && !trimmed.startsWith('https://')) {
      trimmed = trimmed.replaceFirst('https:', 'https://');
    } else if (!trimmed.startsWith('http://') &&
        !trimmed.startsWith('https://') &&
        !trimmed.startsWith('ws://') &&
        !trimmed.startsWith('wss://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Base HTTP URL for the backend API.
  ///
  /// Set at build time via:
  ///   --dart-define=API_BASE_URL=http://<your-server>:8000
  ///
  /// For local development (emulator): http://10.0.2.2:8000
  /// For local development (web/chrome): http://localhost:8000
  /// For production (AWS EC2): http://<EC2_PUBLIC_IP>:8000
  static String get baseUrl {
    const custom = String.fromEnvironment('API_BASE_URL');
    if (custom.isNotEmpty) return _sanitizeUrl(custom);
    // Default to active AWS EC2 server so mobile APKs connect out-of-the-box
    return 'http://13.235.12.217:8000';
  }

  /// Base WebSocket URL for signaling (derived from API_BASE_URL or overridden).
  ///
  /// Set at build time via:
  ///   --dart-define=WS_BASE_URL=ws://<your-server>:8000
  /// (If not set, derived automatically from API_BASE_URL)
  static String get wsUrl {
    const customWs = String.fromEnvironment('WS_BASE_URL');
    if (customWs.isNotEmpty) {
      var sanitized = _sanitizeUrl(customWs);
      if (sanitized.startsWith('http://')) {
        sanitized = sanitized.replaceFirst('http://', 'ws://');
      } else if (sanitized.startsWith('https://')) {
        sanitized = sanitized.replaceFirst('https://', 'wss://');
      }
      return sanitized;
    }
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    return base.replaceFirst('http://', 'ws://');
  }

  // Auth endpoints
  static String get login => '$baseUrl/api/v1/auth/login';
  static String get register => '$baseUrl/api/v1/auth/register';
  static String get me => '$baseUrl/api/v1/auth/me';

  // Matchmaking endpoints
  static String get enqueueMatch => '$baseUrl/api/v1/match/enqueue';
  static String get cancelMatch => '$baseUrl/api/v1/match/cancel';
  static String get matchStatus => '$baseUrl/api/v1/match/status';

  // Metadata endpoints
  static String get languages => '$baseUrl/api/v1/languages';
  static String get userProfile => '$baseUrl/api/v1/users/profile';

  // WebSocket signaling endpoint
  static String signalingSocket(String userId, String token) =>
      '$wsUrl/ws/signaling/$userId?token=$token';

  // WebRTC ICE & TURN Servers
  static String get iceServers => '$baseUrl/api/v1/webrtc/ice-servers';
}
