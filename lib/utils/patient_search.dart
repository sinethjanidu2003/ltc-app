import '../models/patient.dart';

bool patientMatchesQuery(Patient patient, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  return patient.name.toLowerCase().contains(normalized) ||
      patient.ohipNumber.toLowerCase().contains(normalized) ||
      patient.patientId.toLowerCase().contains(normalized);
}

List<Patient> filterPatients(List<Patient> patients, String query) {
  return patients
      .where((patient) => patientMatchesQuery(patient, query))
      .toList();
}
