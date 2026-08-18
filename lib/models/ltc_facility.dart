import 'assessment_session.dart';
import 'patient.dart';

class LtcFacility {
  const LtcFacility({
    required this.id,
    required this.name,
    required this.address,
    required this.patients,
    required this.sessions,
    this.patientsCount,
    this.sessionsCount,
  });

  final String id;
  final String name;

  /// Stored as `location` on the API.
  final String address;
  final List<Patient> patients;
  final List<AssessmentSession> sessions;
  final int? patientsCount;
  final int? sessionsCount;

  int get displayPatientCount => patientsCount ?? patients.length;
  int get displaySessionCount => sessionsCount ?? sessions.length;

  factory LtcFacility.fromJson(Map<String, dynamic> json) {
    final patientsJson = json['patients'];
    final sessionsJson = json['sessions'];

    return LtcFacility(
      id: '${json['id']}',
      name: (json['name'] as String?)?.trim() ?? 'Facility',
      address: (json['location'] as String?)?.trim() ??
          (json['address'] as String?)?.trim() ??
          '',
      patients: patientsJson is List
          ? patientsJson
              .whereType<Map>()
              .map((item) =>
                  Patient.fromFacilityLinkJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      sessions: sessionsJson is List
          ? sessionsJson
              .whereType<Map>()
              .map((item) => AssessmentSession.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
      patientsCount: _asInt(json['patients_count']),
      sessionsCount: _asInt(json['sessions_count']),
    );
  }

  LtcFacility copyWith({
    String? id,
    String? name,
    String? address,
    List<Patient>? patients,
    List<AssessmentSession>? sessions,
    int? patientsCount,
    int? sessionsCount,
  }) {
    return LtcFacility(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      patients: patients ?? this.patients,
      sessions: sessions ?? this.sessions,
      patientsCount: patientsCount ?? this.patientsCount,
      sessionsCount: sessionsCount ?? this.sessionsCount,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
