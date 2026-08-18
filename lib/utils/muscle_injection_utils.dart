import '../data/muscle_constants.dart';
import '../models/muscle_row_state.dart';
import '../models/spasticity_assessment.dart';

const kCustomMuscleKeyPrefix = '__custom_';
const kDefaultCustomMuscleSlots = 3;

bool isCustomMuscleKey(String key) => key.startsWith(kCustomMuscleKeyPrefix);

String customMuscleKey(int index) => '$kCustomMuscleKeyPrefix$index';

Map<String, MuscleRowState> createEmptyMuscleRows([
  List<String> muscles = kAvailableMuscles,
  int customSlots = kDefaultCustomMuscleSlots,
]) {
  return {
    for (final muscle in muscles) muscle: MuscleRowState(),
    for (var i = 0; i < customSlots; i++)
      customMuscleKey(i): MuscleRowState(isCustom: true, customLabel: ''),
  };
}

Map<String, MuscleRowState> muscleRowsFromInjections(
  List<BotoxInjection> injections, {
  List<String> muscles = kAvailableMuscles,
  int customSlots = kDefaultCustomMuscleSlots,
}) {
  final rows = createEmptyMuscleRows(muscles, customSlots);
  var nextCustomIndex = customSlots;

  for (final injection in injections) {
    final name = injection.muscle.trim();
    if (name.isEmpty) continue;

    if (rows.containsKey(name) && !isCustomMuscleKey(name)) {
      rows[name] = MuscleRowState(
        selected: true,
        rightUnits: injection.rightUnits,
        leftUnits: injection.leftUnits,
      );
      continue;
    }

    // Existing custom / unknown muscle from API history.
    final key = customMuscleKey(nextCustomIndex++);
    rows[key] = MuscleRowState(
      selected: true,
      isCustom: true,
      customLabel: name,
      rightUnits: injection.rightUnits,
      leftUnits: injection.leftUnits,
    );
  }

  // Keep at least [customSlots] empty free slots available.
  final emptyCustom = rows.entries
      .where(
        (e) =>
            e.value.isCustom &&
            (e.value.customLabel == null ||
                e.value.customLabel!.trim().isEmpty) &&
            !e.value.selected &&
            (e.value.rightUnits ?? 0) == 0 &&
            (e.value.leftUnits ?? 0) == 0,
      )
      .length;
  for (var i = emptyCustom; i < customSlots; i++) {
    final key = customMuscleKey(nextCustomIndex++);
    rows.putIfAbsent(
      key,
      () => MuscleRowState(isCustom: true, customLabel: ''),
    );
  }

  return rows;
}

Map<String, MuscleRowState> addCustomMuscleSlot(
  Map<String, MuscleRowState> rows,
) {
  final updated = Map<String, MuscleRowState>.from(rows);
  var index = 0;
  while (updated.containsKey(customMuscleKey(index))) {
    index++;
  }
  updated[customMuscleKey(index)] =
      MuscleRowState(isCustom: true, customLabel: '', selected: true);
  return updated;
}

List<BotoxInjection> injectionsFromMuscleRows(
  Map<String, MuscleRowState> rows, {
  Map<String, String> muscleIdsByName = const {},
}) {
  final injections = <BotoxInjection>[];

  for (final entry in rows.entries) {
    final row = entry.value;
    if (!row.selected) continue;
    final hasUnits =
        (row.rightUnits ?? 0) > 0 || (row.leftUnits ?? 0) > 0;
    if (!hasUnits) continue;

    final name = row.isCustom
        ? (row.customLabel?.trim() ?? '')
        : entry.key;
    if (name.isEmpty) continue;

    injections.add(
      BotoxInjection(
        muscle: name,
        muscleId: muscleIdsByName[name],
        rightUnits: row.rightUnits,
        leftUnits: row.leftUnits,
      ),
    );
  }

  return injections;
}

int totalUnitsForRows(Map<String, MuscleRowState> rows) {
  var total = 0;
  for (final row in rows.values) {
    if (row.selected) {
      total += (row.rightUnits ?? 0) + (row.leftUnits ?? 0);
    }
  }
  return total;
}

/// Catalog muscle names first, then custom slots (stable order).
List<String> orderedMuscleKeys(
  Map<String, MuscleRowState> rows,
  List<String> catalogMuscles,
) {
  final keys = <String>[];
  for (final muscle in catalogMuscles) {
    if (rows.containsKey(muscle)) keys.add(muscle);
  }
  final customKeys = rows.keys.where(isCustomMuscleKey).toList()
    ..sort((a, b) {
      final ai = int.tryParse(a.replaceFirst(kCustomMuscleKeyPrefix, '')) ?? 0;
      final bi = int.tryParse(b.replaceFirst(kCustomMuscleKeyPrefix, '')) ?? 0;
      return ai.compareTo(bi);
    });
  keys.addAll(customKeys);
  return keys;
}
