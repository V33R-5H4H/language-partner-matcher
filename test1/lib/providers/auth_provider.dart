import 'package:flutter/material.dart';
import '../data/local/local_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  late UserModel _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _initDefaultProfile();
  }

  void reloadFromStorage() {
    _initDefaultProfile();
    notifyListeners();
  }

  void _initDefaultProfile() {
    final storage = LocalStorage.instance;
    final id = storage.userId ?? 'user_10001';
    final name = storage.username ?? 'User_${id.substring(id.length >= 4 ? id.length - 4 : 0)}';
    final native = storage.nativeLang;
    final target = storage.targetLang;
    final level = storage.proficiency;

    _currentUser = UserModel(
      userId: id,
      username: name,
      email: '$name@example.com',
      nativeLanguageName: native,
      targetLanguageName: target,
      proficiencyLevel: level,
    );
  }

  UserModel get currentUser => _currentUser;
  bool get isAuthenticated => LocalStorage.instance.token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> updateProfile({
    required String username,
    required String nativeLanguage,
    required String targetLanguage,
    required int proficiencyLevel,
  }) async {
    _currentUser = UserModel(
      userId: _currentUser.userId,
      username: username.trim().isEmpty ? _currentUser.username : username.trim(),
      email: '${username.toLowerCase().replaceAll(' ', '')}@example.com',
      nativeLanguageName: nativeLanguage,
      targetLanguageName: targetLanguage,
      proficiencyLevel: proficiencyLevel,
    );

    await LocalStorage.instance.saveProfile(
      username: _currentUser.username,
      nativeLang: nativeLanguage,
      targetLang: targetLanguage,
      proficiency: proficiencyLevel,
    );

    notifyListeners();
  }

  Future<void> setNativeLanguage(String nativeLang) async {
    _currentUser = UserModel(
      userId: _currentUser.userId,
      username: _currentUser.username,
      email: _currentUser.email,
      nativeLanguageName: nativeLang,
      targetLanguageName: _currentUser.targetLanguageName,
      proficiencyLevel: _currentUser.proficiencyLevel,
    );
    await LocalStorage.instance.setNativeLang(nativeLang);
    notifyListeners();
  }

  Future<void> setTargetLanguage(String targetLang) async {
    _currentUser = UserModel(
      userId: _currentUser.userId,
      username: _currentUser.username,
      email: _currentUser.email,
      nativeLanguageName: _currentUser.nativeLanguageName,
      targetLanguageName: targetLang,
      proficiencyLevel: _currentUser.proficiencyLevel,
    );
    await LocalStorage.instance.setTargetLang(targetLang);
    notifyListeners();
  }

  Future<void> setProficiencyLevel(int level) async {
    _currentUser = UserModel(
      userId: _currentUser.userId,
      username: _currentUser.username,
      email: _currentUser.email,
      nativeLanguageName: _currentUser.nativeLanguageName,
      targetLanguageName: _currentUser.targetLanguageName,
      proficiencyLevel: level,
    );
    await LocalStorage.instance.setProficiency(level);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(email, password);
      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Invalid email or password';
      }
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await LocalStorage.instance.clearAuth();
    _initDefaultProfile();
    notifyListeners();
  }
}
