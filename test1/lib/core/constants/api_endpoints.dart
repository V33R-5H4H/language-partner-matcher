class ApiEndpoints {
  static String _sanitizeUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.isEmpty) return 'http://13.235.12.217:8000';
    if (trimmed.startsWith('http:') && !trimmed.startsWith('http://')) {
      trimmed = trimmed.replaceFirst('http:', 'http://');
    } else if (trimmed.startsWith('https:') && !trimmed.startsWith('https://')) {
      trimmed = trimmed.replaceFirst('https:', 'https://');
    } else if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'http://$trimmed';
    }
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  // Configurable base URLs with platform-aware smart defaults
  static String get baseUrl {
    const custom = String.fromEnvironment('API_BASE_URL');
    if (custom.isNotEmpty) return _sanitizeUrl(custom);
    // Default to active AWS Mumbai EC2 instance
    return 'http://13.235.12.217:8000';
  }

  static String get wsUrl {
    const customWs = String.fromEnvironment('WS_BASE_URL');
    if (customWs.isNotEmpty) {
      var sanitized = _sanitizeUrl(customWs);
      if (sanitized.startsWith('http://')) sanitized = sanitized.replaceFirst('http://', 'ws://');
      if (sanitized.startsWith('https://')) sanitized = sanitized.replaceFirst('https://', 'wss://');
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
