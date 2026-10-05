class LanguageModel {
  final int languageId;
  final String languageName;
  final String languageCode;

  LanguageModel({
    required this.languageId,
    required this.languageName,
    required this.languageCode,
  });

  factory LanguageModel.fromJson(Map<String, dynamic> json) {
    return LanguageModel(
      languageId: json['language_id'] ?? 0,
      languageName: json['language_name'] ?? '',
      languageCode: json['language_code'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language_id': languageId,
      'language_name': languageName,
      'language_code': languageCode,
    };
  }
}
