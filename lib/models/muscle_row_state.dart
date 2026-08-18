import 'spasticity_assessment.dart';

class MuscleRowState {
  MuscleRowState({
    this.selected = false,
    this.rightUnits,
    this.leftUnits,
    this.isCustom = false,
    this.customLabel,
  });

  bool selected;
  int? rightUnits;
  int? leftUnits;

  /// Free-text row the clinician can name in the Botox table.
  final bool isCustom;

  /// Display name for custom rows (catalog rows use the map key).
  final String? customLabel;

  String displayName(String key) {
    if (isCustom) {
      final label = customLabel?.trim();
      if (label != null && label.isNotEmpty) return label;
      return '';
    }
    return key;
  }

  MuscleRowState copyWith({
    bool? selected,
    int? rightUnits,
    int? leftUnits,
    bool clearRight = false,
    bool clearLeft = false,
    bool? isCustom,
    String? customLabel,
  }) {
    return MuscleRowState(
      selected: selected ?? this.selected,
      rightUnits: clearRight ? null : (rightUnits ?? this.rightUnits),
      leftUnits: clearLeft ? null : (leftUnits ?? this.leftUnits),
      isCustom: isCustom ?? this.isCustom,
      customLabel: customLabel ?? this.customLabel,
    );
  }
}

class InjectionHistoryColumn {
  const InjectionHistoryColumn({
    required this.assessmentId,
    required this.date,
    required this.injections,
    required this.initials,
    required this.isSigned,
  });

  final String assessmentId;
  final DateTime date;
  final List<BotoxInjection> injections;
  final String? initials;
  final bool isSigned;

  BotoxInjection? injectionFor(String muscle) {
    try {
      return injections.firstWhere((i) => i.muscle == muscle);
    } catch (_) {
      return null;
    }
  }

  int get totalRight {
    var sum = 0;
    for (final injection in injections) {
      sum += injection.rightUnits ?? 0;
    }
    return sum;
  }

  int get totalLeft {
    var sum = 0;
    for (final injection in injections) {
      sum += injection.leftUnits ?? 0;
    }
    return sum;
  }
}
