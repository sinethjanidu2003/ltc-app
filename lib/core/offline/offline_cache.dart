import 'dart:convert';

import '../../models/assessment_session.dart';
import '../../models/ltc_facility.dart';
import '../../models/muscle.dart';
import '../../models/patient.dart';
import '../../models/spasticity_assessment.dart';
import '../../models/spasticity_pattern_catalog.dart';
import 'offline_file_store.dart';

/// Device-local JSON cache for LTC clinical data.
///
/// On web this is a no-op (no persistent offline cache).
/// On mobile/desktop it writes under the app documents directory.
class OfflineCache {
  Future<void> savePatternCatalog(SpasticityPatternCatalog catalog) async {
    await writeOfflineFile(
      'spasticity_patterns.json',
      jsonEncode(catalog.toJson()),
    );
  }

  Future<SpasticityPatternCatalog?> loadPatternCatalog() async {
    return _loadCatalogFile('spasticity_patterns.json');
  }

  Future<void> saveNeckJawPatternCatalog(SpasticityPatternCatalog catalog) async {
    await writeOfflineFile(
      'spasticity_patterns_neck_jaw.json',
      jsonEncode(catalog.toJson()),
    );
  }

  Future<SpasticityPatternCatalog?> loadNeckJawPatternCatalog() async {
    return _loadCatalogFile('spasticity_patterns_neck_jaw.json');
  }

  Future<SpasticityPatternCatalog?> _loadCatalogFile(String filename) async {
    final rawText = await readOfflineFile(filename);
    if (rawText == null || rawText.isEmpty) return null;
    try {
      final raw = jsonDecode(rawText);
      if (raw is! Map) return null;
      return SpasticityPatternCatalog.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot({
    required List<LtcFacility> facilities,
    required Map<String, List<Muscle>> musclesByFacility,
    required Map<String, Set<String>> sessionPatientIds,
  }) async {
    final payload = {
      'saved_at': DateTime.now().toIso8601String(),
      'facilities': facilities.map(_facilityToJson).toList(),
      'muscles': {
        for (final entry in musclesByFacility.entries)
          entry.key: entry.value.map((m) => m.toJson()).toList(),
      },
      'session_patients': {
        for (final entry in sessionPatientIds.entries)
          entry.key: entry.value.toList(),
      },
    };

    await writeOfflineFile('snapshot.json', jsonEncode(payload));
  }

  Future<OfflineSnapshot?> loadSnapshot() async {
    final rawText = await readOfflineFile('snapshot.json');
    if (rawText == null || rawText.isEmpty) return null;

    try {
      final raw = jsonDecode(rawText);
      if (raw is! Map) return null;
      final map = Map<String, dynamic>.from(raw);

      final facilitiesJson = map['facilities'];
      final facilities = <LtcFacility>[];
      if (facilitiesJson is List) {
        for (final item in facilitiesJson.whereType<Map>()) {
          facilities.add(_facilityFromJson(Map<String, dynamic>.from(item)));
        }
      }

      final muscles = <String, List<Muscle>>{};
      final musclesJson = map['muscles'];
      if (musclesJson is Map) {
        musclesJson.forEach((key, value) {
          if (value is List) {
            muscles['$key'] = value
                .whereType<Map>()
                .map((item) => Muscle.fromJson(Map<String, dynamic>.from(item)))
                .toList();
          }
        });
      }

      final roster = <String, Set<String>>{};
      final rosterJson = map['session_patients'];
      if (rosterJson is Map) {
        rosterJson.forEach((key, value) {
          if (value is List) {
            roster['$key'] = value.map((id) => id.toString()).toSet();
          }
        });
      }

      return OfflineSnapshot(
        facilities: facilities,
        musclesByFacility: muscles,
        sessionPatientIds: roster,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _facilityToJson(LtcFacility facility) {
    return {
      'id': facility.id,
      'name': facility.name,
      'location': facility.address,
      'patients_count': facility.displayPatientCount,
      'sessions_count': facility.displaySessionCount,
      'patients': facility.patients.map(_patientToJson).toList(),
      'sessions': facility.sessions.map((s) => s.toJson()).toList(),
    };
  }

  LtcFacility _facilityFromJson(Map<String, dynamic> json) {
    final patientsJson = json['patients'];
    final sessionsJson = json['sessions'];
    return LtcFacility(
      id: '${json['id']}',
      name: (json['name'] as String?) ?? 'Facility',
      address: (json['location'] as String?) ??
          (json['address'] as String?) ??
          '',
      patients: patientsJson is List
          ? patientsJson
              .whereType<Map>()
              .map((item) => _patientFromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
      sessions: sessionsJson is List
          ? sessionsJson
              .whereType<Map>()
              .map(
                (item) =>
                    AssessmentSession.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
          : const [],
      patientsCount: json['patients_count'] is int
          ? json['patients_count'] as int
          : null,
      sessionsCount: json['sessions_count'] is int
          ? json['sessions_count'] as int
          : null,
    );
  }

  Map<String, dynamic> _patientToJson(Patient patient) {
    return {
      'id': patient.linkId,
      'patient_id': patient.patientId,
      'name': patient.name,
      'ohip_number': patient.ohipNumber,
      'date_of_birth': patient.dateOfBirth.toIso8601String(),
      'address': patient.address,
      'assessments':
          patient.assessments.map((a) => a.toCacheJson()).toList(),
    };
  }

  Patient _patientFromJson(Map<String, dynamic> json) {
    final patientId = '${json['patient_id'] ?? json['id'] ?? ''}';
    final assessmentsJson = json['assessments'];
    final assessments = assessmentsJson is List
        ? assessmentsJson
            .whereType<Map>()
            .map(
              (item) => SpasticityAssessment.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <SpasticityAssessment>[];

    final dob = DateTime.tryParse('${json['date_of_birth'] ?? ''}');

    return Patient(
      id: patientId,
      patientId: patientId,
      linkId: json['id']?.toString(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Patient $patientId',
      ohipNumber: (json['ohip_number'] as String?) ?? '—',
      dateOfBirth: dob ?? DateTime(1900, 1, 1),
      address: json['address'] as String?,
      assessments: assessments,
    );
  }
}

class OfflineSnapshot {
  const OfflineSnapshot({
    required this.facilities,
    required this.musclesByFacility,
    required this.sessionPatientIds,
  });

  final List<LtcFacility> facilities;
  final Map<String, List<Muscle>> musclesByFacility;
  final Map<String, Set<String>> sessionPatientIds;
}
