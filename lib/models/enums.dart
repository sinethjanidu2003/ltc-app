enum BodyPartAffected { upperLimb, lowerLimb, neck, trunk }

enum SideAffected { right, left, bilateral }

enum AssessmentType { initial, followUp }

enum Outcome { improved, notImproved }

extension BodyPartAffectedLabel on BodyPartAffected {
  String get label => switch (this) {
        BodyPartAffected.upperLimb => 'Upper Limb',
        BodyPartAffected.lowerLimb => 'Lower Limb',
        BodyPartAffected.neck => 'Neck',
        BodyPartAffected.trunk => 'Trunk',
      };

  String get apiValue => switch (this) {
        BodyPartAffected.upperLimb => 'upper_limb',
        BodyPartAffected.lowerLimb => 'lower_limb',
        BodyPartAffected.neck => 'neck',
        BodyPartAffected.trunk => 'trunk',
      };

  static BodyPartAffected? fromApi(String? value) {
    return switch (value) {
      'upper_limb' => BodyPartAffected.upperLimb,
      'lower_limb' => BodyPartAffected.lowerLimb,
      'neck' => BodyPartAffected.neck,
      'trunk' => BodyPartAffected.trunk,
      _ => null,
    };
  }
}

String formatBodyParts(Iterable<BodyPartAffected> parts) {
  return parts.map((p) => p.label).join(', ');
}

extension SideAffectedLabel on SideAffected {
  String get label => switch (this) {
        SideAffected.right => 'Right',
        SideAffected.left => 'Left',
        SideAffected.bilateral => 'Bilateral',
      };

  String get apiValue => switch (this) {
        SideAffected.right => 'right',
        SideAffected.left => 'left',
        SideAffected.bilateral => 'bilateral',
      };

  static SideAffected fromApi(String? value) {
    return switch (value) {
      'left' => SideAffected.left,
      'bilateral' => SideAffected.bilateral,
      _ => SideAffected.right,
    };
  }
}

extension AssessmentTypeLabel on AssessmentType {
  String get label => switch (this) {
        AssessmentType.initial => 'Initial',
        AssessmentType.followUp => 'Follow Up',
      };

  String get apiValue => switch (this) {
        AssessmentType.initial => 'initial',
        AssessmentType.followUp => 'follow_up',
      };

  static AssessmentType fromApi(String? value) {
    return value == 'follow_up'
        ? AssessmentType.followUp
        : AssessmentType.initial;
  }
}

extension OutcomeLabel on Outcome {
  String get label => switch (this) {
        Outcome.improved => 'Improved',
        Outcome.notImproved => 'Not Improved',
      };

  String get apiValue => switch (this) {
        Outcome.improved => 'improved',
        Outcome.notImproved => 'not_improved',
      };

  static Outcome? fromApi(String? value) {
    return switch (value) {
      'improved' => Outcome.improved,
      'not_improved' => Outcome.notImproved,
      _ => null,
    };
  }
}
