import '../../models/session_model.dart';
import '../local/database_helper.dart';

class HistoryRepository {
  Future<void> saveSession(CallSessionModel session) async {
    await DatabaseHelper.instance.insertSession(session.toMap());
  }

  Future<List<CallSessionModel>> getSessions() async {
    final list = await DatabaseHelper.instance.getSessions();
    return list.map((map) => CallSessionModel.fromMap(map)).toList();
  }

  Future<void> saveVocabulary(VocabularyItemModel item) async {
    await DatabaseHelper.instance.insertVocabulary(item.toMap());
  }

  Future<List<VocabularyItemModel>> getVocabulary() async {
    final list = await DatabaseHelper.instance.getVocabulary();
    return list.map((map) => VocabularyItemModel.fromMap(map)).toList();
  }
}
