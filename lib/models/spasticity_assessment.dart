import 'enums.dart';

class BotoxInjection {
  const BotoxInjection({
    required this.muscle,
    this.muscleId,
    this.rightUnits,
    this.leftUnits,
  });

  final String muscle;
  final String? muscleId;
  final int? rightUnits;
  final int? leftUnits;

  int get totalUnits => (rightUnits ?? 0) + (leftUnits ?? 0);

  factory BotoxInjection.fromJson(Map<String, dynamic> json) {
    final muscleJson = json['muscle'];
    final muscleName = muscleJson is Map
        ? (muscleJson['name'] as String?)?.trim()
        : null;

    return BotoxInjection(
      muscle: muscleName?.isNotEmpty == true
          ? muscleName!
          : 'Muscle ${json['muscle_id'] ?? ''}',
      muscleId: json['muscle_id']?.toString() ??
          (muscleJson is Map ? muscleJson['id']?.toString() : null),
      rightUnits: _asInt(json['right_units']),
      leftUnits: _asInt(json['left_units']),
    );
  }

  Map<String, dynamic> toApiJson() {
    final id = int.tryParse(muscleId ?? '');
    return {
      if (id != null) 'muscle_id': id,
      if (rightUnits != null) 'right_units': rightUnits,
      if (leftUnits != null) 'left_units': leftUnits,
    };
  }

  BotoxInjection copyWith({
    String? muscle,
    String? muscleId,
    int? rightUnits,
    int? leftUnits,
    bool clearRight = false,
    bool clearLeft = false,
  }) {
    return BotoxInjection(
      muscle: muscle ?? this.muscle,
      muscleId: muscleId ?? this.muscleId,
      rightUnits: clearRight ? null : (rightUnits ?? this.rightUnits),
      leftUnits: clearLeft ? null : (leftUnits ?? this.leftUnits),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class SpasticityPatterns {
  const SpasticityPatterns({
    this.shoulder = const [],
    this.elbow = const [],
    this.wrist = const [],
    this.thumb = const [],
    this.fingers = const [],
    this.hip = const [],
    this.knee = const [],
    this.ankle = const [],
    this.trunk = const [],
    this.neck = const [],
    this.jaw = const [],
  });

  final List<String> shoulder;
  final List<String> elbow;
  final List<String> wrist;
  final List<String> thumb;
  final List<String> fingers;
  final List<String> hip;
  final List<String> knee;
  final List<String> ankle;
  final List<String> trunk;
  final List<String> neck;
  final List<String> jaw;

  /// Region field name without `pattern_` prefix → selected keys.
  Map<String, List<String>> get byRegion => {
        'shoulder': shoulder,
        'elbow': elbow,
        'wrist': wrist,
        'thumb': thumb,
        'fingers': fingers,
        'hip': hip,
        'knee': knee,
        'ankle': ankle,
        if (trunk.isNotEmpty) 'trunk': trunk,
        'neck': neck,
        'jaw': jaw,
      };

  bool get hasNeckJaw => neck.isNotEmpty || jaw.isNotEmpty;

  bool get hasAny => byRegion.values.any((keys) => keys.isNotEmpty);

  List<String> keysFor(String region) {
    switch (region) {
      case 'shoulder':
        return shoulder;
      case 'elbow':
        return elbow;
      case 'wrist':
        return wrist;
      case 'thumb':
        return thumb;
      case 'fingers':
        return fingers;
      case 'hip':
        return hip;
      case 'knee':
        return knee;
      case 'ankle':
        return ankle;
      case 'trunk':
        return trunk;
      case 'neck':
        return neck;
      case 'jaw':
        return jaw;
      default:
        return const [];
    }
  }

  factory SpasticityPatterns.fromJson(Map<String, dynamic> json) {
    return SpasticityPatterns(
      shoulder: _stringList(json['pattern_shoulder']),
      elbow: _stringList(json['pattern_elbow']),
      wrist: _stringList(json['pattern_wrist']),
      thumb: _stringList(json['pattern_thumb']),
      fingers: _stringList(json['pattern_fingers']),
      hip: _stringList(json['pattern_hip']),
      knee: _stringList(json['pattern_knee']),
      ankle: _stringList(json['pattern_ankle']),
      trunk: _stringList(json['pattern_trunk']),
      neck: _stringList(json['pattern_neck']),
      jaw: _stringList(json['pattern_jaw']),
    );
  }

  /// Limb fields for assessment POST / PUT. Neck and jaw use a separate API.
  Map<String, dynamic> toApiJson() => {
        'pattern_shoulder': shoulder,
        'pattern_elbow': elbow,
        'pattern_wrist': wrist,
        'pattern_thumb': thumb,
        'pattern_fingers': fingers,
        'pattern_hip': hip,
        'pattern_knee': knee,
        'pattern_ankle': ankle,
        'pattern_trunk': trunk,
      };

  Map<String, dynamic> toNeckJawApiJson() => {
        'pattern_neck': neck,
        'pattern_jaw': jaw,
      };

  Map<String, dynamic> toCacheJson() => {
        ...toApiJson(),
        ...toNeckJawApiJson(),
      };

  SpasticityPatterns copyWith({
    List<String>? shoulder,
    List<String>? elbow,
    List<String>? wrist,
    List<String>? thumb,
    List<String>? fingers,
    List<String>? hip,
    List<String>? knee,
    List<String>? ankle,
    List<String>? trunk,
    List<String>? neck,
    List<String>? jaw,
  }) {
    return SpasticityPatterns(
      shoulder: shoulder ?? this.shoulder,
      elbow: elbow ?? this.elbow,
      wrist: wrist ?? this.wrist,
      thumb: thumb ?? this.thumb,
      fingers: fingers ?? this.fingers,
      hip: hip ?? this.hip,
      knee: knee ?? this.knee,
      ankle: ankle ?? this.ankle,
      trunk: trunk ?? this.trunk,
      neck: neck ?? this.neck,
      jaw: jaw ?? this.jaw,
    );
  }

  SpasticityPatterns withRegion(String region, List<String> keys) {
    switch (region) {
      case 'shoulder':
        return copyWith(shoulder: List<String>.from(keys));
      case 'elbow':
        return copyWith(elbow: List<String>.from(keys));
      case 'wrist':
        return copyWith(wrist: List<String>.from(keys));
      case 'thumb':
        return copyWith(thumb: List<String>.from(keys));
      case 'fingers':
        return copyWith(fingers: List<String>.from(keys));
      case 'hip':
        return copyWith(hip: List<String>.from(keys));
      case 'knee':
        return copyWith(knee: List<String>.from(keys));
      case 'ankle':
        return copyWith(ankle: List<String>.from(keys));
      case 'trunk':
        return copyWith(trunk: List<String>.from(keys));
      case 'neck':
        return copyWith(neck: List<String>.from(keys));
      case 'jaw':
        return copyWith(jaw: List<String>.from(keys));
      default:
        return this;
    }
  }

  static List<String> _stringList(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class TreatmentGoals {
  const TreatmentGoals({
    this.spasm = false,
    this.pain = false,
    this.positioning = false,
    this.contracture = false,
    this.deformity = false,
    this.pressureSore = false,
    this.poorSleep = false,
    this.reducedMobility = false,
    this.reducedHygiene = false,
    this.carerBurden = false,
    this.customGoal1,
    this.customGoal2,
  });

  final bool spasm;
  final bool pain;
  final bool positioning;
  final bool contracture;
  final bool deformity;
  final bool pressureSore;
  final bool poorSleep;
  final bool reducedMobility;
  final bool reducedHygiene;
  final bool carerBurden;
  final String? customGoal1;
  final String? customGoal2;

  factory TreatmentGoals.fromJson(Map<String, dynamic> json) {
    return TreatmentGoals(
      spasm: json['goal_spasm'] == true,
      pain: json['goal_pain'] == true,
      positioning: json['goal_positioning'] == true,
      contracture: json['goal_contracture'] == true,
      deformity: json['goal_deformity'] == true,
      pressureSore: json['goal_pressure_sore'] == true,
      poorSleep: json['goal_poor_sleep'] == true,
      reducedMobility: json['goal_reduced_mobility'] == true,
      reducedHygiene: json['goal_reduced_hygiene'] == true,
      carerBurden: json['goal_carer_burden'] == true,
      customGoal1: json['goal_custom_1'] as String?,
      customGoal2: json['goal_custom_2'] as String?,
    );
  }

  List<String> get activeGoals {
    final goals = <String>[];
    if (spasm) goals.add('Spasm');
    if (pain) goals.add('Pain');
    if (positioning) goals.add('Positioning');
    if (contracture) goals.add('Contracture');
    if (deformity) goals.add('Deformity');
    if (pressureSore) goals.add('Pressure Sore');
    if (poorSleep) goals.add('Poor Sleep');
    if (reducedMobility) goals.add('Increase Mobility');
    if (reducedHygiene) goals.add('Increase Hygiene');
    if (carerBurden) goals.add('Carer Burden');
    if (customGoal1 != null && customGoal1!.isNotEmpty) goals.add(customGoal1!);
    if (customGoal2 != null && customGoal2!.isNotEmpty) goals.add(customGoal2!);
    return goals;
  }

  TreatmentGoals copyWith({
    bool? spasm,
    bool? pain,
    bool? positioning,
    bool? contracture,
    bool? deformity,
    bool? pressureSore,
    bool? poorSleep,
    bool? reducedMobility,
    bool? reducedHygiene,
    bool? carerBurden,
    String? customGoal1,
    String? customGoal2,
  }) {
    return TreatmentGoals(
      spasm: spasm ?? this.spasm,
      pain: pain ?? this.pain,
      positioning: positioning ?? this.positioning,
      contracture: contracture ?? this.contracture,
      deformity: deformity ?? this.deformity,
      pressureSore: pressureSore ?? this.pressureSore,
      poorSleep: poorSleep ?? this.poorSleep,
      reducedMobility: reducedMobility ?? this.reducedMobility,
      reducedHygiene: reducedHygiene ?? this.reducedHygiene,
      carerBurden: carerBurden ?? this.carerBurden,
      customGoal1: customGoal1 ?? this.customGoal1,
      customGoal2: customGoal2 ?? this.customGoal2,
    );
  }
}

class SpasticityAssessment {
  const SpasticityAssessment({
    required this.id,
    required this.sessionId,
    required this.patientId,
    required this.assessmentDate,
    required this.bodyParts,
    required this.side,
    required this.assessmentType,
    this.outcome,
    required this.patterns,
    required this.goals,
    this.notes = '',
    required this.botoxInjections,
    this.initials,
  });

  final String id;
  final String sessionId;
  final String patientId;
  final DateTime assessmentDate;
  final List<BodyPartAffected> bodyParts;
  final SideAffected side;
  final AssessmentType assessmentType;
  final Outcome? outcome;
  final SpasticityPatterns patterns;
  final TreatmentGoals goals;
  final String notes;
  final List<BotoxInjection> botoxInjections;
  final String? initials;

  bool get isSigned => initials != null && initials!.trim().isNotEmpty;

  int get totalBotoxUnits {
    var total = 0;
    for (final injection in botoxInjections) {
      total += injection.totalUnits;
    }
    return total;
  }

  factory SpasticityAssessment.fromJson(
    Map<String, dynamic> json, {
    String? fallbackSessionId,
  }) {
    final bodyPartsJson = json['body_parts'];
    final bodyParts = <BodyPartAffected>[];
    if (bodyPartsJson is List) {
      for (final item in bodyPartsJson) {
        if (item is Map) {
          final part = BodyPartAffectedLabel.fromApi(
            item['body_part']?.toString(),
          );
          if (part != null) bodyParts.add(part);
        } else if (item is String) {
          final part = BodyPartAffectedLabel.fromApi(item);
          if (part != null) bodyParts.add(part);
        }
      }
    }

    final injectionsJson = json['botox_injections'];
    final injections = injectionsJson is List
        ? injectionsJson
            .whereType<Map>()
            .map(
              (item) =>
                  BotoxInjection.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
        : <BotoxInjection>[];

    final rawDate = json['assessment_date']?.toString();
    final date = rawDate == null
        ? DateTime.now()
        : (DateTime.tryParse(rawDate) ?? DateTime.now());

    return SpasticityAssessment(
      id: '${json['id']}',
      sessionId:
          '${json['assessment_session_id'] ?? fallbackSessionId ?? ''}',
      patientId: '${json['patient_id']}',
      assessmentDate: date,
      bodyParts: bodyParts,
      side: SideAffectedLabel.fromApi(json['side']?.toString()),
      assessmentType:
          AssessmentTypeLabel.fromApi(json['assessment_type']?.toString()),
      outcome: OutcomeLabel.fromApi(json['outcome']?.toString()),
      patterns: SpasticityPatterns.fromJson(json),
      goals: TreatmentGoals.fromJson(json),
      notes: (json['notes'] as String?) ?? '',
      botoxInjections: injections,
      initials: json['initials'] as String?,
    );
  }

  Map<String, dynamic> toApiBody({bool includePatientId = false}) {
    return {
      if (includePatientId) 'patient_id': patientId,
      'side': side.apiValue,
      'assessment_type': assessmentType.apiValue,
      'outcome': outcome?.apiValue,
      'notes': notes,
      'initials': initials,
      ...patterns.toApiJson(),
      'goal_spasm': goals.spasm,
      'goal_pain': goals.pain,
      'goal_positioning': goals.positioning,
      'goal_contracture': goals.contracture,
      'goal_deformity': goals.deformity,
      'goal_pressure_sore': goals.pressureSore,
      'goal_poor_sleep': goals.poorSleep,
      'goal_reduced_mobility': goals.reducedMobility,
      'goal_reduced_hygiene': goals.reducedHygiene,
      'goal_carer_burden': goals.carerBurden,
      'goal_custom_1': goals.customGoal1,
      'goal_custom_2': goals.customGoal2,
      'body_parts': bodyParts.map((part) => part.apiValue).toList(),
      'botox_injections': botoxInjections
          .where((injection) => injection.muscleId != null)
          .map((injection) => injection.toApiJson())
          .toList(),
    };
  }

  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'assessment_session_id': sessionId,
      'patient_id': patientId,
      'assessment_date': assessmentDate.toIso8601String(),
      'side': side.apiValue,
      'assessment_type': assessmentType.apiValue,
      'outcome': outcome?.apiValue,
      'notes': notes,
      'initials': initials,
      ...patterns.toCacheJson(),
      'goal_spasm': goals.spasm,
      'goal_pain': goals.pain,
      'goal_positioning': goals.positioning,
      'goal_contracture': goals.contracture,
      'goal_deformity': goals.deformity,
      'goal_pressure_sore': goals.pressureSore,
      'goal_poor_sleep': goals.poorSleep,
      'goal_reduced_mobility': goals.reducedMobility,
      'goal_reduced_hygiene': goals.reducedHygiene,
      'goal_carer_burden': goals.carerBurden,
      'goal_custom_1': goals.customGoal1,
      'goal_custom_2': goals.customGoal2,
      'body_parts': bodyParts
          .map((part) => {'body_part': part.apiValue})
          .toList(),
      'botox_injections': botoxInjections
          .map(
            (injection) => {
              'muscle_id': injection.muscleId,
              'right_units': injection.rightUnits,
              'left_units': injection.leftUnits,
              'muscle': {
                'id': injection.muscleId,
                'name': injection.muscle,
              },
            },
          )
          .toList(),
    };
  }

  SpasticityAssessment copyWith({
    String? id,
    String? sessionId,
    String? patientId,
    DateTime? assessmentDate,
    List<BodyPartAffected>? bodyParts,
    SideAffected? side,
    AssessmentType? assessmentType,
    Outcome? outcome,
    bool clearOutcome = false,
    SpasticityPatterns? patterns,
    TreatmentGoals? goals,
    String? notes,
    List<BotoxInjection>? botoxInjections,
    String? initials,
  }) {
    return SpasticityAssessment(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      patientId: patientId ?? this.patientId,
      assessmentDate: assessmentDate ?? this.assessmentDate,
      bodyParts: bodyParts ?? this.bodyParts,
      side: side ?? this.side,
      assessmentType: assessmentType ?? this.assessmentType,
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      patterns: patterns ?? this.patterns,
      goals: goals ?? this.goals,
      notes: notes ?? this.notes,
      botoxInjections: botoxInjections ?? this.botoxInjections,
      initials: initials ?? this.initials,
    );
  }
}
