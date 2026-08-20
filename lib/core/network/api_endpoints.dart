/// Shared path constants for the LTC backend API.
abstract final class ApiEndpoints {
  static const authLogin = '/api/auth/login';
  static const authLogout = '/api/auth/logout';
  static const user = '/api/user';
  static const users = '/api/users';
  static const spasticityPatterns = '/api/spasticity-patterns';
  static const spasticityPatternsNeckJaw = '/api/spasticity-patterns/neck-jaw';

  static String userById(String id) => '$users/$id';

  static const facilities = '/api/ltc-facilities';

  static String facility(String id) => '$facilities/$id';

  static String facilityPatients(String facilityId) =>
      '${facility(facilityId)}/patients';

  static String facilityPatient(String facilityId, String patientLinkId) =>
      '${facilityPatients(facilityId)}/$patientLinkId';

  static String facilityMuscles(String facilityId) =>
      '${facility(facilityId)}/muscles';

  static String facilitySessions(String facilityId) =>
      '${facility(facilityId)}/sessions';

  static String facilitySession(String facilityId, String sessionId) =>
      '${facilitySessions(facilityId)}/$sessionId';

  static String sessionPatients(String facilityId, String sessionId) =>
      '${facilitySession(facilityId, sessionId)}/patients';

  static String sessionPatient(
    String facilityId,
    String sessionId,
    String patientId,
  ) =>
      '${sessionPatients(facilityId, sessionId)}/$patientId';

  static String sessionAssessments(String facilityId, String sessionId) =>
      '${facilitySession(facilityId, sessionId)}/assessments';

  static String sessionAssessment(
    String facilityId,
    String sessionId,
    String assessmentId,
  ) =>
      '${sessionAssessments(facilityId, sessionId)}/$assessmentId';

  static String sessionAssessmentNeckJawPatterns(
    String facilityId,
    String sessionId,
    String assessmentId,
  ) =>
      '${sessionAssessment(facilityId, sessionId, assessmentId)}/neck-jaw-patterns';
}
