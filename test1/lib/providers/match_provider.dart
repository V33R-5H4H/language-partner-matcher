import 'package:flutter/material.dart';
import '../data/repositories/match_repository.dart';
import '../models/match_model.dart';

enum MatchState { idle, searching, matched, failed }

class MatchProvider extends ChangeNotifier {
  final MatchRepository _matchRepository = MatchRepository();

  MatchState _state = MatchState.idle;
  MatchModel? _currentMatch;
  int _searchElapsedSeconds = 0;

  MatchState get state => _state;
  MatchModel? get currentMatch => _currentMatch;
  int get searchElapsedSeconds => _searchElapsedSeconds;

  Future<void> startMatching(int targetLanguageId) async {
    _state = MatchState.searching;
    _searchElapsedSeconds = 0;
    notifyListeners();

    final success = await _matchRepository.enqueue(targetLanguageId);
    if (!success) {
      _state = MatchState.failed;
      notifyListeners();
    }
  }

  void onMatchDiscovered(MatchModel match) {
    _currentMatch = match;
    _state = MatchState.matched;
    notifyListeners();
  }

  Future<void> cancelMatching() async {
    await _matchRepository.cancel();
    _state = MatchState.idle;
    _currentMatch = null;
    notifyListeners();
  }
}
