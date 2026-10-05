import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static final LocalStorage instance = LocalStorage._init();
  LocalStorage._init();

  SharedPreferences? _prefs;

  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'profile_username';
  static const String _keyNativeLang = 'profile_native_lang';
  static const String _keyTargetLang = 'profile_target_lang';
  static const String _keyProficiency = 'profile_proficiency';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAboutStatus = 'profile_about_status';

  String? _cachedToken;
  String? _cachedUserId;
  String? _cachedUsername;
  String? _cachedNativeLang;
  String? _cachedTargetLang;
  int _cachedProficiency = 3;
  String? _cachedThemeMode;
  String? _cachedAboutStatus;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _cachedToken = _prefs?.getString(_keyToken);
      _cachedUserId = _prefs?.getString(_keyUserId);
      _cachedUsername = _prefs?.getString(_keyUsername);
      _cachedNativeLang = _prefs?.getString(_keyNativeLang);
      _cachedTargetLang = _prefs?.getString(_keyTargetLang);
      _cachedProficiency = _prefs?.getInt(_keyProficiency) ?? 3;
      _cachedThemeMode = _prefs?.getString(_keyThemeMode);
      _cachedAboutStatus = _prefs?.getString(_keyAboutStatus);

      // Ensure stable persistent userId if not yet assigned
      if (_cachedUserId == null || _cachedUserId!.isEmpty) {
        _cachedUserId = 'user_${Random().nextInt(90000) + 10000}';
        await _prefs?.setString(_keyUserId, _cachedUserId!);
      }

      // Default username derived from persistent userId if not set
      if (_cachedUsername == null || _cachedUsername!.isEmpty) {
        _cachedUsername = 'User_${_cachedUserId!.substring(_cachedUserId!.length - 4)}';
        await _prefs?.setString(_keyUsername, _cachedUsername!);
      }

      // Default persistent languages if not set
      if (_cachedNativeLang == null || _cachedNativeLang!.isEmpty) {
        _cachedNativeLang = 'English';
        await _prefs?.setString(_keyNativeLang, _cachedNativeLang!);
      }

      if (_cachedTargetLang == null || _cachedTargetLang!.isEmpty) {
        _cachedTargetLang = 'Spanish';
        await _prefs?.setString(_keyTargetLang, _cachedTargetLang!);
      }

      if (_cachedAboutStatus == null || _cachedAboutStatus!.isEmpty) {
        _cachedAboutStatus = 'Available for Language Exchange • Practicing Daily';
        await _prefs?.setString(_keyAboutStatus, _cachedAboutStatus!);
      }

      debugPrint('LocalStorage: Loaded persistent profile -> User: $_cachedUsername, Native: $_cachedNativeLang, Target: $_cachedTargetLang');
    } catch (e) {
      debugPrint('LocalStorage: Init error: $e');
    }
  }

  Future<void> saveAuthToken(String token, String userId) async {
    _cachedToken = token;
    _cachedUserId = userId;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyToken, token);
    await _prefs?.setString(_keyUserId, userId);
  }

  Future<void> saveProfile({
    required String username,
    required String nativeLang,
    required String targetLang,
    required int proficiency,
  }) async {
    _cachedUsername = username;
    _cachedNativeLang = nativeLang;
    _cachedTargetLang = targetLang;
    _cachedProficiency = proficiency;

    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyUsername, username);
    await _prefs?.setString(_keyNativeLang, nativeLang);
    await _prefs?.setString(_keyTargetLang, targetLang);
    await _prefs?.setInt(_keyProficiency, proficiency);
    debugPrint('LocalStorage: Profile persistently saved (Native: $nativeLang, Target: $targetLang).');
  }

  Future<void> setNativeLang(String lang) async {
    _cachedNativeLang = lang;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyNativeLang, lang);
    debugPrint('LocalStorage: Native language set to $lang');
  }

  Future<void> setTargetLang(String lang) async {
    _cachedTargetLang = lang;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyTargetLang, lang);
    debugPrint('LocalStorage: Target language set to $lang');
  }

  Future<void> setUsername(String name) async {
    _cachedUsername = name;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyUsername, name);
  }

  Future<void> setProficiency(int level) async {
    _cachedProficiency = level;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setInt(_keyProficiency, level);
  }

  Future<void> setAboutStatus(String about) async {
    _cachedAboutStatus = about;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyAboutStatus, about);
  }

  Future<void> saveThemeMode(String mode) async {
    _cachedThemeMode = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_keyThemeMode, mode);
  }

  String? get token => _cachedToken ?? _prefs?.getString(_keyToken);
  String? get userId => _cachedUserId ?? _prefs?.getString(_keyUserId);
  String? get username => _cachedUsername ?? _prefs?.getString(_keyUsername);
  String get nativeLang => _cachedNativeLang ?? _prefs?.getString(_keyNativeLang) ?? 'English';
  String get targetLang => _cachedTargetLang ?? _prefs?.getString(_keyTargetLang) ?? 'Spanish';
  int get proficiency => _cachedProficiency;
  String? get themeMode => _cachedThemeMode ?? _prefs?.getString(_keyThemeMode);
  String get aboutStatus => _cachedAboutStatus ?? _prefs?.getString(_keyAboutStatus) ?? 'Available for Language Exchange • Practicing Daily';

  Future<void> clearAuth() async {
    _cachedToken = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(_keyToken);
  }
}
