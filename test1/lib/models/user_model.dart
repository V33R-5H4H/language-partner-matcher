class UserModel {
  final String userId;
  final String username;
  final String email;
  final int? nativeLanguageId;
  final String? nativeLanguageName;
  final int? targetLanguageId;
  final String? targetLanguageName;
  final int proficiencyLevel; // 1 to 5
  final bool isActive;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.nativeLanguageId,
    this.nativeLanguageName,
    this.targetLanguageId,
    this.targetLanguageName,
    this.proficiencyLevel = 1,
    this.isActive = true,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      nativeLanguageId: json['native_language_id'],
      nativeLanguageName: json['native_language_name'],
      targetLanguageId: json['target_language_id'],
      targetLanguageName: json['target_language_name'],
      proficiencyLevel: json['proficiency_level'] ?? 1,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'native_language_id': nativeLanguageId,
      'native_language_name': nativeLanguageName,
      'target_language_id': targetLanguageId,
      'target_language_name': targetLanguageName,
      'proficiency_level': proficiencyLevel,
      'is_active': isActive,
    };
  }
}
