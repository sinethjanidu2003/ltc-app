import 'enums.dart';
import 'spasticity_assessment.dart';

class Patient {
  const Patient({
    required this.id,
    required this.patientId,
    required this.name,
    required this.ohipNumber,
    required this.dateOfBirth,
    required this.assessments,
    this.linkId,
    this.address,
  });

  /// Stable key used across the app UI (NeoClinic / LTC `patient_id`).
  final String id;

  /// External patient id stored on the LTC facility patient link.
  final String patientId;

  /// LTC facility-patient link row id (when known).
  final String? linkId;

  final String name;
  final String ohipNumber;
  final DateTime dateOfBirth;
  final String? address;
  final List<SpasticityAssessment> assessments;

  SpasticityAssessment? get latestAssessmentOrNull {
    if (assessments.isEmpty) return null;
    final sorted = List<SpasticityAssessment>.from(assessments)
      ..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
    return sorted.first;
  }

  SpasticityAssessment get latestAssessment {
    return latestAssessmentOrNull!;
  }

  SpasticityAssessment? get initialAssessmentOrNull {
    if (assessments.isEmpty) return null;

    for (final assessment in assessments) {
      if (assessment.assessmentType == AssessmentType.initial) {
        return assessment;
      }
    }

    final sorted = List<SpasticityAssessment>.from(assessments)
      ..sort((a, b) => a.assessmentDate.compareTo(b.assessmentDate));
    return sorted.first;
  }

  SpasticityAssessment? get previousAssessment {
    if (assessments.length < 2) return null;
    final sorted = List<SpasticityAssessment>.from(assessments)
      ..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
    return sorted[1];
  }

  int get visitCount => assessments.length;

  int get age {
    final now = DateTime.now();
    var years = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      years--;
    }
    return years;
  }

  /// Facility patient-link payload from LTC API (demographics filled later).
  factory Patient.fromFacilityLinkJson(Map<String, dynamic> json) {
    final patientId = '${json['patient_id']}';
    return Patient(
      id: patientId,
      patientId: patientId,
      linkId: json['id']?.toString(),
      name: 'Patient $patientId',
      ohipNumber: '—',
      dateOfBirth: DateTime(1900, 1, 1),
      assessments: const [],
    );
  }

  Patient copyWith({
    String? id,
    String? patientId,
    String? linkId,
    String? name,
    String? ohipNumber,
    DateTime? dateOfBirth,
    String? address,
    List<SpasticityAssessment>? assessments,
  }) {
    return Patient(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      linkId: linkId ?? this.linkId,
      name: name ?? this.name,
      ohipNumber: ohipNumber ?? this.ohipNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      assessments: assessments ?? this.assessments,
    );
  }
}
