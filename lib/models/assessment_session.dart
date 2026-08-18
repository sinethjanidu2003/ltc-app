class AssessmentSession {
  const AssessmentSession({
    required this.id,
    required this.sessionDate,
    this.assessmentsCount,
  });

  final String id;
  final DateTime sessionDate;
  final int? assessmentsCount;

  factory AssessmentSession.fromJson(Map<String, dynamic> json) {
    final rawDate = json['session_date']?.toString();
    final parsed = rawDate == null ? null : DateTime.tryParse(rawDate);

    return AssessmentSession(
      id: '${json['id']}',
      sessionDate: parsed ?? DateTime.now(),
      assessmentsCount: json['assessments_count'] is int
          ? json['assessments_count'] as int
          : int.tryParse('${json['assessments_count'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_date': sessionDate.toIso8601String(),
        'assessments_count': assessmentsCount,
      };
}
