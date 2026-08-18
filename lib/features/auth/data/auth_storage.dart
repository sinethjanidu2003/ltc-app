import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_models.dart';

/// Device-local session + PIN storage. PIN is never sent to the API.
class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _tokenKey = 'auth_token';
  static const _userJsonKey = 'auth_user_json';
  static const _userNameKey = 'auth_user_name';
  static const _userEmailKey = 'auth_user_email';
  static const _userIdKey = 'auth_user_id';

  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _pinUserKey = 'pin_user_key';
  static const _pinSkippedKey = 'pin_skipped_user';

  static const pinLength = 4;
  static const maxPinAttempts = 5;

  final FlutterSecureStorage _storage;

  Future<void> saveSession({
    required String token,
    AuthUser? user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    if (user != null) {
      await _storage.write(
        key: _userJsonKey,
        value: jsonEncode(user.toJson()),
      );
      await _storage.write(key: _userIdKey, value: user.id);
      await _storage.write(key: _userNameKey, value: user.name);
      await _storage.write(key: _userEmailKey, value: user.email);
    }
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _userJsonKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) return AuthUser.fromJson(json);
        if (json is Map) {
          return AuthUser.fromJson(Map<String, dynamic>.from(json));
        }
      } catch (_) {
        // Fall back to legacy id/name/email fields below.
      }
    }

    final id = await _storage.read(key: _userIdKey);
    final name = await _storage.read(key: _userNameKey);
    final email = await _storage.read(key: _userEmailKey);
    if ((id == null || id.isEmpty) &&
        (email == null || email.isEmpty) &&
        (name == null || name.isEmpty)) {
      return null;
    }

    return AuthUser(
      id: id ?? '',
      name: name ?? 'User',
      email: email ?? '',
    );
  }

  /// Stable per-account key for tying a PIN to a user on this device.
  static String userPinKey({String? id, String? email}) {
    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    if (id != null && id.isNotEmpty) return 'id:$id';
    if (normalizedEmail.isNotEmpty) return 'email:$normalizedEmail';
    return '';
  }

  Future<bool> hasPinForUser(String userKey) async {
    if (userKey.isEmpty) return false;
    final storedUser = await _storage.read(key: _pinUserKey);
    final hash = await _storage.read(key: _pinHashKey);
    return storedUser == userKey && hash != null && hash.isNotEmpty;
  }

  Future<String?> readPinUserKey() => _storage.read(key: _pinUserKey);

  Future<void> savePin({
    required String userKey,
    required String pin,
  }) async {
    final salt = _randomSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinUserKey, value: userKey);
    await _storage.delete(key: _pinSkippedKey);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final hash = await _storage.read(key: _pinHashKey);
    if (salt == null || hash == null) return false;
    return _hashPin(pin, salt) == hash;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinUserKey);
  }

  Future<void> markPinSkipped(String userKey) async {
    await _storage.write(key: _pinSkippedKey, value: userKey);
  }

  Future<bool> wasPinSkipped(String userKey) async {
    if (userKey.isEmpty) return false;
    final skipped = await _storage.read(key: _pinSkippedKey);
    return skipped == userKey;
  }

  Future<void> clearSessionOnly() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userJsonKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userEmailKey);
  }

  Future<void> clear() async {
    await clearSessionOnly();
    await clearPin();
    await _storage.delete(key: _pinSkippedKey);
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }
}
