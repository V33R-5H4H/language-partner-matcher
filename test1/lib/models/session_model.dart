class CallSessionModel {
  final String sessionId;
  final String partnerUsername;
  final String languagePracticed;
  final String startedAt;
  final int durationSeconds;
  final String? notes;

  CallSessionModel({
    required this.sessionId,
    required this.partnerUsername,
    required this.languagePracticed,
    required this.startedAt,
    required this.durationSeconds,
    this.notes,
  });

  factory CallSessionModel.fromMap(Map<String, dynamic> map) {
    return CallSessionModel(
      sessionId: map['session_id'] ?? '',
      partnerUsername: map['partner_username'] ?? '',
      languagePracticed: map['language_practiced'] ?? '',
      startedAt: map['started_at'] ?? '',
      durationSeconds: map['duration_seconds'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'partner_username': partnerUsername,
      'language_practiced': languagePracticed,
      'started_at': startedAt,
      'duration_seconds': durationSeconds,
      'notes': notes,
    };
  }
}

class VocabularyItemModel {
  final int? vocabId;
  final String? sessionId;
  final String wordOrPhrase;
  final String translation;
  final String? notes;
  final String createdAt;

  VocabularyItemModel({
    this.vocabId,
    this.sessionId,
    required this.wordOrPhrase,
    required this.translation,
    this.notes,
    required this.createdAt,
  });

  factory VocabularyItemModel.fromMap(Map<String, dynamic> map) {
    return VocabularyItemModel(
      vocabId: map['vocab_id'],
      sessionId: map['session_id'],
      wordOrPhrase: map['word_or_phrase'] ?? '',
      translation: map['translation'] ?? '',
      notes: map['notes'],
      createdAt: map['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vocab_id': vocabId,
      'session_id': sessionId,
      'word_or_phrase': wordOrPhrase,
      'translation': translation,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
