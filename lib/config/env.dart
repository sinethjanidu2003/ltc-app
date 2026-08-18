import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place for values loaded from `.env`.
class AppEnv {
  AppEnv._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get apiBaseUrl {
    final value = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('API_BASE_URL is missing from .env');
    }
    return _stripTrailingSlash(value);
  }

  static String get apiKey {
    final value = dotenv.env['API_KEY']?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('API_KEY is missing from .env');
    }
    return value;
  }

  /// NeoClinic patient API base, e.g. `https://portal.neoclinic.ca/v1`
  static String get patientsApiBaseUrl {
    final value = (dotenv.env['PATIENT_BASE_URL'] ??
            dotenv.env['PATIENTS_API_BASE_URL'] ??
            '')
        .trim();
    if (value.isEmpty) {
      throw StateError('PATIENT_BASE_URL is missing from .env');
    }
    return _stripTrailingSlash(value);
  }

  static String get jwtSecret {
    final value = dotenv.env['JWT_SECRET']?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('JWT_SECRET is missing from .env');
    }
    return value;
  }

  /// JWT lifetime in minutes (default 60).
  static int get jwtTtlMinutes {
    final raw = dotenv.env['JWT_TTL']?.trim();
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed <= 0) return 60;
    return parsed;
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
