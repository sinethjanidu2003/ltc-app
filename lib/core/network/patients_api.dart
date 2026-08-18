import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

import '../../config/env.dart';
import '../network/api_exception.dart';

/// Demographic profile from NeoClinic (not stored on the LTC API).
class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
    this.dateOfBirth,
    this.gender,
    this.healthCardLast4,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? address;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? healthCardLast4;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Patient $id' : name;
  }

  String get ohipDisplay {
    final last4 = healthCardLast4?.trim();
    if (last4 != null && last4.isNotEmpty) return '••••$last4';
    return '—';
  }

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    return PatientProfile(
      id: '${json['id']}',
      firstName: (json['first_name'] as String?)?.trim() ?? '',
      lastName: (json['last_name'] as String?)?.trim() ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      dateOfBirth: _parseDate(json['date_of_birth']),
      gender: json['gender'] as String?,
      healthCardLast4: json['health_card_last4']?.toString(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

/// Calls NeoClinic patient find/get with a short-lived HS256 JWT.
class PatientsApi {
  PatientsApi({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Map<String, PatientProfile> _cache = {};

  Future<List<PatientProfile>> find(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final json = await _post(
      path: '/api/patients/find',
      route: 'api.v1.patients.find',
      body: {'q': q},
    );

    final patients = json['patients'];
    if (patients is! List) return const [];

    final results = patients
        .whereType<Map>()
        .map((item) => PatientProfile.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    for (final profile in results) {
      _cache[profile.id] = profile;
    }
    return results;
  }

  Future<PatientProfile?> getById(String patientId) async {
    final cached = _cache[patientId];
    if (cached != null) return cached;

    final json = await _post(
      path: '/api/patients/get',
      route: 'api.v1.patients.get',
      body: {
        'patient_id': int.tryParse(patientId) ?? patientId,
      },
    );

    if (json['found'] != true) return null;
    final patient = json['patient'];
    if (patient is! Map) return null;

    final profile =
        PatientProfile.fromJson(Map<String, dynamic>.from(patient));
    _cache[profile.id] = profile;
    return profile;
  }

  Future<Map<String, PatientProfile>> getMany(Iterable<String> ids) async {
    final unique = ids.toSet().where((id) => id.isNotEmpty).toList();
    final result = <String, PatientProfile>{};

    await Future.wait(unique.map((id) async {
      try {
        final profile = await getById(id);
        if (profile != null) result[id] = profile;
      } catch (_) {
        // Leave missing profiles to fall back to patient id in UI.
      }
    }));

    return result;
  }

  Future<Map<String, dynamic>> _post({
    required String path,
    required String route,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('${AppEnv.patientsApiBaseUrl}$path');
    final token = _signJwt(route);

    late final http.Response response;
    try {
      response = await _http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (error) {
      throw ApiException(
        message:
            'Unable to reach the patient API. Check PATIENT_BASE_URL.',
        body: error.toString(),
      );
    }

    final raw = response.body;
    Map<String, dynamic> json = {};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        } else if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        json = {'message': raw};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    throw ApiException(
      message: (json['message'] as String?) ??
          'Patient API request failed (${response.statusCode})',
      statusCode: response.statusCode,
      body: raw,
    );
  }

  String _signJwt(String route) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ttlSeconds = AppEnv.jwtTtlMinutes * 60;
    final jwt = JWT(
      {
        'route': route,
        'iss': 'NeoClinic',
        'iat': now,
        'exp': now + ttlSeconds,
      },
    );
    return jwt.sign(
      SecretKey(AppEnv.jwtSecret),
      algorithm: JWTAlgorithm.HS256,
    );
  }

  void dispose() => _http.close();
}
