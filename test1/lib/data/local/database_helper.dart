import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  static const String _keySessions = 'call_sessions_history';
  static const String _keyVocab = 'saved_vocabulary_list';
  static const String _keyDirectChats = 'direct_chats_history';

  final List<Map<String, dynamic>> _inMemorySessions = [];
  final List<Map<String, dynamic>> _inMemoryVocab = [];
  final Map<String, List<Map<String, dynamic>>> _inMemoryDirectChats = {};

  // Reactive notifier so CallHistoryScreen updates automatically
  final ValueNotifier<List<Map<String, dynamic>>> sessionsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  // Reactive notifier for persistent direct chats
  final ValueNotifier<Map<String, List<Map<String, dynamic>>>> directChatsNotifier =
      ValueNotifier<Map<String, List<Map<String, dynamic>>>>({});

  Future<void> initDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsRaw = prefs.getStringList(_keySessions);
      if (sessionsRaw != null) {
        _inMemorySessions.clear();
        for (final item in sessionsRaw) {
          try {
            _inMemorySessions.add(Map<String, dynamic>.from(jsonDecode(item)));
          } catch (_) {}
        }
        sessionsNotifier.value = List.from(_inMemorySessions);
      }

      final directChatsRaw = prefs.getString(_keyDirectChats);
      if (directChatsRaw != null) {
        final decoded = jsonDecode(directChatsRaw) as Map<String, dynamic>;
        _inMemoryDirectChats.clear();
        decoded.forEach((key, val) {
          if (val is List) {
            _inMemoryDirectChats[key] = val.map((e) => Map<String, dynamic>.from(e)).toList();
          }
        });
        directChatsNotifier.value = Map.from(_inMemoryDirectChats);
      }

      final vocabRaw = prefs.getStringList(_keyVocab);
      if (vocabRaw != null) {
        _inMemoryVocab.clear();
        for (final item in vocabRaw) {
          try {
            _inMemoryVocab.add(Map<String, dynamic>.from(jsonDecode(item)));
          } catch (_) {}
        }
      }

      debugPrint('DatabaseHelper: Loaded persistent database records.');
    } catch (e) {
      debugPrint('DatabaseHelper: Init error: $e');
    }
  }

  Timer? _sessionDebounce;
  Timer? _directChatDebounce;

  Future<void> _persistSessions() async {
    _sessionDebounce?.cancel();
    _sessionDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final stringList = _inMemorySessions.map((e) => jsonEncode(e)).toList();
        await prefs.setStringList(_keySessions, stringList);
      } catch (e) {
        debugPrint('DatabaseHelper: Error persisting sessions: $e');
      }
    });
  }

  Future<void> _persistDirectChats() async {
    _directChatDebounce?.cancel();
    _directChatDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyDirectChats, jsonEncode(_inMemoryDirectChats));
      } catch (e) {
        debugPrint('DatabaseHelper: Error persisting direct chats: $e');
      }
    });
  }

  // Reactive notifier for persistent vocabulary
  final ValueNotifier<List<Map<String, dynamic>>> vocabularyNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  Future<void> saveDirectMessage({
    required String peerId,
    required String peerName,
    required String id,
    required String text,
    required String time,
    required bool isSelf,
    String language = 'Spanish',
    String status = 'sent',
  }) async {
    if (peerId.isEmpty || text.trim().isEmpty) return;

    final effectiveId = id.isNotEmpty
        ? id
        : 'msg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

    _inMemoryDirectChats.putIfAbsent(peerId, () => []);

    // Check if message ID already exists
    final index = _inMemoryDirectChats[peerId]!.indexWhere((m) => m['id'] == effectiveId);
    if (index == -1) {
      _inMemoryDirectChats[peerId]!.add({
        'id': effectiveId,
        'peer_id': peerId,
        'peer_name': peerName.isNotEmpty ? peerName : 'Practice Partner',
        'text': text,
        'time': time.isNotEmpty ? time : DateTime.now().toIso8601String(),
        'isSelf': isSelf,
        'language': language,
        'status': status,
      });

      // Update peer name across previous messages if this name is more specific
      if (peerName.isNotEmpty && peerName != 'Partner' && peerName != 'Practice Partner') {
        for (final m in _inMemoryDirectChats[peerId]!) {
          if (m['peer_name'] == 'Partner' || m['peer_name'] == 'Practice Partner') {
            m['peer_name'] = peerName;
          }
        }
      }

      directChatsNotifier.value = Map.from(_inMemoryDirectChats);
      await _persistDirectChats();
      debugPrint('DatabaseHelper: Direct message saved with peer $peerId ($peerName): $text');
    }
  }

  Future<void> markMessagesAsRead(String peerId) async {
    if (!_inMemoryDirectChats.containsKey(peerId)) return;
    bool modified = false;
    for (final m in _inMemoryDirectChats[peerId]!) {
      if (m['isSelf'] == true && m['status'] != 'read') {
        m['status'] = 'read';
        modified = true;
      }
    }
    if (modified) {
      directChatsNotifier.value = Map.from(_inMemoryDirectChats);
      await _persistDirectChats();
    }
  }

  List<Map<String, dynamic>> getDirectMessages(String peerId) {
    if (_inMemoryDirectChats.containsKey(peerId)) {
      return List.from(_inMemoryDirectChats[peerId]!);
    }
    return [];
  }

  Future<void> deleteDirectChat(String peerId) async {
    _inMemoryDirectChats.remove(peerId);
    directChatsNotifier.value = Map.from(_inMemoryDirectChats);
    await _persistDirectChats();
  }

  Future<void> clearAllChats() async {
    _inMemoryDirectChats.clear();
    directChatsNotifier.value = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDirectChats);
  }

  Future<void> insertSession(Map<String, dynamic> session) async {
    _inMemorySessions.insert(0, session);
    sessionsNotifier.value = List.from(_inMemorySessions);
    await _persistSessions();
    debugPrint('DatabaseHelper: Session saved & persisted: ${session['peer_name']} (${session['duration_seconds']}s)');
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    return List.from(_inMemorySessions);
  }

  Future<void> deleteSession(String sessionId) async {
    _inMemorySessions.removeWhere((e) => e['session_id'] == sessionId);
    sessionsNotifier.value = List.from(_inMemorySessions);
    await _persistSessions();
  }

  Future<void> deleteSessionAtIndex(int index) async {
    if (index >= 0 && index < _inMemorySessions.length) {
      _inMemorySessions.removeAt(index);
      sessionsNotifier.value = List.from(_inMemorySessions);
      await _persistSessions();
    }
  }

  Future<void> clearSessions() async {
    _inMemorySessions.clear();
    sessionsNotifier.value = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessions);
  }

  Future<void> insertVocabulary(Map<String, dynamic> vocab) async {
    // Avoid duplicate vocabulary words
    final word = (vocab['word'] ?? '').toString().toLowerCase().trim();
    if (word.isEmpty) return;
    
    final exists = _inMemoryVocab.any((v) => (v['word'] ?? '').toString().toLowerCase().trim() == word);
    if (!exists) {
      _inMemoryVocab.insert(0, {
        'word': vocab['word'],
        'translation': vocab['translation'] ?? '',
        'language': vocab['language'] ?? 'Spanish',
        'context': vocab['context'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
      });
      vocabularyNotifier.value = List.from(_inMemoryVocab);
      try {
        final prefs = await SharedPreferences.getInstance();
        final stringList = _inMemoryVocab.map((e) => jsonEncode(e)).toList();
        await prefs.setStringList(_keyVocab, stringList);
      } catch (_) {}
    }
  }

  Future<void> deleteVocabularyAtIndex(int index) async {
    if (index >= 0 && index < _inMemoryVocab.length) {
      _inMemoryVocab.removeAt(index);
      vocabularyNotifier.value = List.from(_inMemoryVocab);
      try {
        final prefs = await SharedPreferences.getInstance();
        final stringList = _inMemoryVocab.map((e) => jsonEncode(e)).toList();
        await prefs.setStringList(_keyVocab, stringList);
      } catch (_) {}
    }
  }

  Future<List<Map<String, dynamic>>> getVocabulary() async {
    return List.from(_inMemoryVocab);
  }
}
