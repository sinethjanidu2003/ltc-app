import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../models/auth_models.dart';
import 'auth_storage.dart';

/// Owns authentication + device-local PIN unlock state.
class AuthRepository extends ChangeNotifier {
  AuthRepository({
    ApiClient? apiClient,
    AuthStorage? storage,
  })  : _api = apiClient ?? ApiClient(),
        _ownsApi = apiClient == null,
        _storage = storage ?? AuthStorage();

  final ApiClient _api;
  final bool _ownsApi;
  final AuthStorage _storage;

  AuthSession? _session;
  bool _ready = false;
  bool _busy = false;
  bool _unlocked = false;
  bool _hasPin = false;
  bool _shouldOfferPinSetup = false;
  bool _isSettingUpPin = false;
  int _pinAttemptsLeft = AuthStorage.maxPinAttempts;
  String? _lastError;

  AuthSession? get session => _session;
  bool get isAuthenticated => _session?.token.isNotEmpty == true;
  bool get isReady => _ready;
  bool get isBusy => _busy;
  bool get isUnlocked => _unlocked;
  bool get hasPin => _hasPin;
  bool get shouldOfferPinSetup => _shouldOfferPinSetup;
  bool get isSettingUpPin => _isSettingUpPin;
  bool get requiresPinUnlock => isAuthenticated && _hasPin && !_unlocked;
  int get pinAttemptsLeft => _pinAttemptsLeft;
  String? get lastError => _lastError;
  AuthUser? get user => _session?.user;
  String get role => user?.role ?? '';
  ApiClient get apiClient => _api;

  bool can(AuthResource resource, AuthAction action) =>
      user?.can(resource, action) ?? false;

  bool canRead(AuthResource resource) => can(resource, AuthAction.read);
  bool canCreate(AuthResource resource) => can(resource, AuthAction.create);
  bool canUpdate(AuthResource resource) => can(resource, AuthAction.update);
  bool canDelete(AuthResource resource) => can(resource, AuthAction.delete);

  bool canAccessFacility(String facilityId) =>
      user?.canAccessFacility(facilityId) ?? false;

  String get _currentUserKey => AuthStorage.userPinKey(
        id: _session?.user?.id,
        email: _session?.user?.email,
      );

  Future<void> bootstrap() async {
    try {
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        final cached = await _storage.readUser();
        if (cached != null && !cached.isActive) {
          await _storage.clearSessionOnly();
          _api.setAuthToken(null);
          return;
        }

        _session = AuthSession(token: token, user: cached);
        _api.setAuthToken(token);

        final userKey = AuthStorage.userPinKey(
          id: cached?.id,
          email: cached?.email,
        );
        _hasPin = await _storage.hasPinForUser(userKey);
        // Cold start with a PIN → require unlock.
        _unlocked = !_hasPin;
      }
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _busy = true;
    _lastError = null;
    notifyListeners();

    try {
      final deviceName = await _resolveDeviceName();
      final payload = LoginRequest(
        email: email.trim(),
        password: password,
        deviceName: deviceName,
      );

      final json = await _api.post(
        ApiEndpoints.authLogin,
        body: payload.toJson(),
      );

      final session = AuthSession.fromJson(json);
      await _storage.saveSession(
        token: session.token,
        user: session.user,
      );

      _session = session;
      _api.setAuthToken(session.token);
      _unlocked = true;
      _pinAttemptsLeft = AuthStorage.maxPinAttempts;

      final userKey = _currentUserKey;
      final existingPinUser = await _storage.readPinUserKey();

      // Different account on this device → drop the old PIN.
      if (existingPinUser != null &&
          existingPinUser.isNotEmpty &&
          existingPinUser != userKey) {
        await _storage.clearPin();
      }

      _hasPin = await _storage.hasPinForUser(userKey);
      final skipped = await _storage.wasPinSkipped(userKey);
      _shouldOfferPinSetup = !_hasPin && !skipped;

      return true;
    } on ApiException catch (error) {
      _lastError = error.message;
      return false;
    } on FormatException catch (error) {
      _lastError = error.message;
      return false;
    } catch (_) {
      _lastError = 'Something went wrong while signing in. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> setupPin(String pin) async {
    if (pin.length != AuthStorage.pinLength ||
        int.tryParse(pin) == null) {
      _lastError = 'Enter a ${AuthStorage.pinLength}-digit PIN.';
      notifyListeners();
      return false;
    }

    final userKey = _currentUserKey;
    if (userKey.isEmpty) {
      _lastError = 'Unable to link PIN to this account.';
      notifyListeners();
      return false;
    }

    await _storage.savePin(userKey: userKey, pin: pin);
    _hasPin = true;
    _shouldOfferPinSetup = false;
    _isSettingUpPin = false;
    _unlocked = true;
    _lastError = null;
    notifyListeners();
    return true;
  }

  void beginPinSetup() {
    _shouldOfferPinSetup = false;
    _isSettingUpPin = true;
    notifyListeners();
  }

  Future<void> skipPinSetup() async {
    final userKey = _currentUserKey;
    if (userKey.isNotEmpty) {
      await _storage.markPinSkipped(userKey);
    }
    _shouldOfferPinSetup = false;
    _isSettingUpPin = false;
    _unlocked = true;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    _lastError = null;

    final ok = await _storage.verifyPin(pin);
    if (ok) {
      _unlocked = true;
      _pinAttemptsLeft = AuthStorage.maxPinAttempts;
      notifyListeners();
      return true;
    }

    _pinAttemptsLeft = (_pinAttemptsLeft - 1).clamp(0, AuthStorage.maxPinAttempts);
    if (_pinAttemptsLeft <= 0) {
      _lastError = 'Too many incorrect attempts. Sign in with email and password.';
      await _forcePasswordLogin();
      return false;
    }

    _lastError =
        'Incorrect PIN. $_pinAttemptsLeft attempt${_pinAttemptsLeft == 1 ? '' : 's'} left.';
    notifyListeners();
    return false;
  }

  /// Cleared session so the user can sign in with email/password again.
  /// Keeps the device PIN for the same account after login.
  Future<void> usePasswordInstead() async {
    await _forcePasswordLogin(keepPin: true);
  }

  Future<void> logout({bool clearPin = true}) async {
    _busy = true;
    notifyListeners();
    try {
      try {
        await _api.post(ApiEndpoints.authLogout);
      } catch (_) {
        // Still clear local session even if remote logout fails.
      }
      if (clearPin) {
        await _storage.clear();
        _hasPin = false;
      } else {
        await _storage.clearSessionOnly();
      }
      _api.setAuthToken(null);
      _session = null;
      _unlocked = false;
      _shouldOfferPinSetup = false;
      _isSettingUpPin = false;
      _lastError = null;
      _pinAttemptsLeft = AuthStorage.maxPinAttempts;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _forcePasswordLogin({bool keepPin = true}) async {
    _api.setAuthToken(null);
    await _storage.clearSessionOnly();
    if (!keepPin) {
      await _storage.clearPin();
      _hasPin = false;
    }
    _session = null;
    _unlocked = false;
    _shouldOfferPinSetup = false;
    _isSettingUpPin = false;
    _pinAttemptsLeft = AuthStorage.maxPinAttempts;
    notifyListeners();
  }

  Future<String> _resolveDeviceName() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (kIsWeb) return 'LTC Web';
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await plugin.androidInfo;
          return 'Android ${info.model}';
        case TargetPlatform.iOS:
          final info = await plugin.iosInfo;
          return 'iOS ${info.name}';
        case TargetPlatform.windows:
          return 'Windows Desktop';
        case TargetPlatform.macOS:
          return 'macOS Desktop';
        case TargetPlatform.linux:
          return 'Linux Desktop';
        case TargetPlatform.fuchsia:
          return 'LTC Tablet';
      }
    } catch (_) {
      // Fall through to generic name.
    }
    return 'LTC Tablet';
  }

  @override
  void dispose() {
    if (_ownsApi) _api.dispose();
    super.dispose();
  }
}
