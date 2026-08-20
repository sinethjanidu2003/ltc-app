import 'package:flutter/material.dart';

import '../data/muscle_constants.dart';
import '../models/muscle_row_state.dart';
import '../theme/app_theme.dart';
import '../utils/muscle_injection_utils.dart';
import 'section_card.dart';

class MuscleInjectionGrid extends StatefulWidget {
  const MuscleInjectionGrid({
    super.key,
    required this.historyColumns,
    required this.currentDate,
    required this.muscleRows,
    required this.initialsController,
    required this.editable,
    required this.onRowsChanged,
    this.muscles = kAvailableMuscles,
    this.muscleEditable,
    this.onCopyFromPrevious,
    this.showCopyButton = false,
    this.compact = false,
  });

  final List<InjectionHistoryColumn> historyColumns;
  final DateTime currentDate;
  final Map<String, MuscleRowState> muscleRows;
  final TextEditingController initialsController;
  final bool editable;
  final List<String> muscles;
  final bool? muscleEditable;
  final ValueChanged<Map<String, MuscleRowState>> onRowsChanged;
  final VoidCallback? onCopyFromPrevious;
  final bool showCopyButton;
  final bool compact;

  @override
  State<MuscleInjectionGrid> createState() => _MuscleInjectionGridState();
}

class _MuscleInjectionGridState extends State<MuscleInjectionGrid> {
  final _verticalScrollController = ScrollController();
  late Map<String, GlobalKey> _muscleRowKeys;

  String? _activeMuscle;
  _DoseSide? _activeSide;

  bool get _muscleEditable => widget.muscleEditable ?? widget.editable;
  double get _muscleWidth => widget.compact ? 148.0 : 180.0;
  double get _cellWidth => widget.compact ? 56.0 : 68.0;
  double get _rowPaddingV => widget.compact ? 6.0 : 10.0;
  double get _fontSize => widget.compact ? 11.0 : 12.0;

  @override
  void initState() {
    super.initState();
    _muscleRowKeys = {
      for (final muscle in orderedMuscleKeys(widget.muscleRows, widget.muscles))
        muscle: GlobalKey(),
    };
  }

  @override
  void didUpdateWidget(covariant MuscleInjectionGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.muscles != widget.muscles ||
        oldWidget.muscleRows.keys.toSet() != widget.muscleRows.keys.toSet()) {
      _muscleRowKeys = {
        for (final muscle
            in orderedMuscleKeys(widget.muscleRows, widget.muscles))
          muscle: GlobalKey(),
      };
    }
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showCopyButton &&
            _muscleEditable &&
            widget.onCopyFromPrevious != null)
          Padding(
            padding: EdgeInsets.only(bottom: widget.compact ? 4 : 12),
            child: widget.compact
                ? Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: widget.onCopyFromPrevious,
                      icon: const Icon(Icons.content_copy, size: 16),
                      label: const Text('Copy prev.'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: widget.onCopyFromPrevious,
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Copy from Previous Record'),
                  ),
          ),
        if (!widget.editable)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: widget.compact ? 4 : 12),
            padding: EdgeInsets.all(widget.compact ? 8 : 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: widget.compact ? 14 : 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This record is signed and locked. It cannot be edited.',
                    style: TextStyle(
                      fontSize: widget.compact ? 11 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: _activeMuscle != null && _muscleEditable ? 16 : 0,
                  ),
                  child: _buildGrid(),
                ),
              ),
            ),
          ),
        ),
        if (_muscleEditable && _activeMuscle != null && _activeSide != null)
          Padding(
            padding: EdgeInsets.only(top: widget.compact ? 6 : 12),
            child: _DoseKeypad(
              compact: widget.compact,
              label: '$_activeMuscle · '
                  '${_activeSide == _DoseSide.right ? 'Right' : 'Left'}',
              onDigit: _onKeypadDigit,
              onBackspace: _onKeypadBackspace,
              onClear: _onKeypadClear,
              onDone: _clearActiveDose,
            ),
          ),
      ],
    );
  }

  void _clearActiveDose() {
    setState(() {
      _activeMuscle = null;
      _activeSide = null;
    });
  }

  void _selectDoseCell(String muscle, _DoseSide side, MuscleRowState row) {
    if (!_muscleEditable) return;
    if (!row.selected) {
      _updateRow(muscle, row.copyWith(selected: true));
    }
    setState(() {
      _activeMuscle = muscle;
      _activeSide = side;
    });
    _scheduleScrollToActiveRow();
  }

  void _scheduleScrollToActiveRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollActiveRowIntoView();
      // Scroll again after keypad layout takes space.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollActiveRowIntoView();
      });
    });
  }

  void _scrollActiveRowIntoView() {
    final muscle = _activeMuscle;
    if (muscle == null) return;

    final rowContext = _muscleRowKeys[muscle]?.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        alignment: 0.2,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final index = widget.muscles.indexOf(muscle);
    if (index < 0 || !_verticalScrollController.hasClients) return;

    final rowHeight = widget.compact ? 34.0 : 42.0;
    final headerHeight = widget.compact ? 56.0 : 72.0;
    final target = (headerHeight + (index * rowHeight) - 24)
        .clamp(0.0, _verticalScrollController.position.maxScrollExtent);

    _verticalScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  int? _activeDoseValue() {
    if (_activeMuscle == null || _activeSide == null) return null;
    final row = widget.muscleRows[_activeMuscle!] ?? MuscleRowState();
    return _activeSide == _DoseSide.right ? row.rightUnits : row.leftUnits;
  }

  void _setActiveDoseValue(int? value) {
    if (_activeMuscle == null || _activeSide == null) return;
    final row = widget.muscleRows[_activeMuscle!] ?? MuscleRowState();
    final updated = row.copyWith(selected: true);
    if (_activeSide == _DoseSide.right) {
      _updateRow(
        _activeMuscle!,
        updated.copyWith(
          rightUnits: value,
          clearRight: value == null,
        ),
      );
    } else {
      _updateRow(
        _activeMuscle!,
        updated.copyWith(
          leftUnits: value,
          clearLeft: value == null,
        ),
      );
    }
  }

  void _onKeypadDigit(String digit) {
    final current = _activeDoseValue();
    final currentText = (current ?? 0) > 0 ? '$current' : '';
    final parsed = int.tryParse('$currentText$digit');
    if (parsed != null) {
      _setActiveDoseValue(parsed);
    }
  }

  void _onKeypadBackspace() {
    final current = _activeDoseValue();
    final currentText = (current ?? 0) > 0 ? '$current' : '';
    if (currentText.isEmpty) {
      _setActiveDoseValue(null);
      return;
    }
    final nextText = currentText.substring(0, currentText.length - 1);
    _setActiveDoseValue(nextText.isEmpty ? null : int.parse(nextText));
  }

  void _onKeypadClear() => _setActiveDoseValue(null);

  List<String> get _visibleMuscles {
    final ordered = orderedMuscleKeys(widget.muscleRows, widget.muscles);

    // Editable forms keep the full muscle list + custom slots.
    if (widget.editable || _muscleEditable) {
      return ordered;
    }

    // Signed / read-only: only muscles that were actually injected.
    return ordered.where((muscle) {
      final row = widget.muscleRows[muscle];
      final currentUnits =
          (row?.rightUnits ?? 0) + (row?.leftUnits ?? 0);
      if (currentUnits > 0) return true;

      final lookupName = row?.isCustom == true
          ? (row!.customLabel?.trim().isNotEmpty == true
              ? row.customLabel!.trim()
              : muscle)
          : muscle;

      return widget.historyColumns.any((column) {
        final injection = column.injectionFor(lookupName);
        return injection != null && injection.totalUnits > 0;
      });
    }).toList();
  }

  Widget _buildGrid() {
    final allColumns = [
      ...widget.historyColumns,
      InjectionHistoryColumn(
        assessmentId: 'current',
        date: widget.currentDate,
        injections: const [],
        initials: widget.initialsController.text.trim().isEmpty
            ? null
            : widget.initialsController.text.trim(),
        isSigned: !widget.editable,
      ),
    ];
    final muscles = _visibleMuscles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDateHeader(allColumns),
        _buildSideHeader(allColumns),
        if (muscles.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: widget.compact ? 16 : 24,
              horizontal: 12,
            ),
            child: const Text(
              'No injections recorded for this visit.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...muscles.map((muscle) => _buildMuscleRow(muscle, allColumns)),
        if (_muscleEditable) _buildAddCustomMuscleRow(),
        _buildTotalRow(allColumns),
        _buildInitialsRow(allColumns),
      ],
    );
  }

  Widget _buildAddCustomMuscleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            widget.onRowsChanged(addCustomMuscleSlot(widget.muscleRows));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add muscle'),
        ),
      ),
    );
  }

  Widget _buildDateHeader(List<InjectionHistoryColumn> columns) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          _fixedCell(
            width: _muscleWidth,
            child: Text(
              'Muscle',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: _fontSize),
            ),
            align: TextAlign.left,
          ),
          for (var i = 0; i < columns.length; i++)
            _fixedCell(
              width: _cellWidth * 2,
              color: _columnTint(i),
              child: Text(
                formatDate(columns[i].date),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: _fontSize,
                  color: _columnColor(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideHeader(List<InjectionHistoryColumn> columns) {
    return Container(
      color: AppColors.surfaceMuted,
      child: Row(
        children: [
          _fixedCell(width: _muscleWidth, child: const SizedBox.shrink()),
          for (var i = 0; i < columns.length; i++) ...[
            _fixedCell(
              width: _cellWidth,
              color: _columnTint(i),
              child: Text(
                'Right',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: widget.compact ? 10 : 11,
                  color: _columnColor(i),
                ),
              ),
            ),
            _fixedCell(
              width: _cellWidth,
              color: _columnTint(i),
              child: Text(
                'Left',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: widget.compact ? 10 : 11,
                  color: _columnColor(i),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuscleRow(String muscle, List<InjectionHistoryColumn> columns) {
    final row = widget.muscleRows[muscle] ?? MuscleRowState();
    final isLast = columns.length - 1;
    final historyName = row.isCustom
        ? (row.customLabel?.trim().isNotEmpty == true
            ? row.customLabel!.trim()
            : '')
        : muscle;

    return Container(
      key: _muscleRowKeys.putIfAbsent(muscle, GlobalKey.new),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fixedCell(
            width: _muscleWidth,
            align: TextAlign.left,
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: widget.compact ? 2 : 4,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: widget.compact ? 28 : 32,
                  height: widget.compact ? 28 : 32,
                  child: _muscleEditable
                      ? Checkbox(
                          value: row.selected,
                          onChanged: (value) => _updateRow(
                            muscle,
                            row.copyWith(selected: value ?? false),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        )
                      : Icon(
                          _rowHasData(row)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: widget.compact ? 16 : 18,
                          color: _rowHasData(row)
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                ),
                Expanded(
                  child: row.isCustom && _muscleEditable
                      ? _CustomMuscleNameField(
                          key: ValueKey('name-$muscle'),
                          initialValue: row.customLabel ?? '',
                          fontSize: _fontSize,
                          bold: row.selected,
                          // Commit only on focus lost — parent setState on every
                          // keystroke rebuilds the form and dismisses the keyboard.
                          onCommitted: (value) {
                            _updateRow(
                              muscle,
                              row.copyWith(
                                customLabel: value,
                                selected: value.trim().isNotEmpty
                                    ? true
                                    : row.selected,
                              ),
                            );
                          },
                        )
                      : Text(
                          row.isCustom
                              ? (row.customLabel?.trim().isNotEmpty == true
                                  ? row.customLabel!.trim()
                                  : 'Custom muscle')
                              : muscle,
                          style: TextStyle(
                            fontSize: _fontSize,
                            fontWeight: row.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < columns.length; i++)
            if (i < isLast) ...[
              _historyValueCell(
                historyName.isEmpty
                    ? null
                    : columns[i].injectionFor(historyName)?.rightUnits,
              ),
              _historyValueCell(
                historyName.isEmpty
                    ? null
                    : columns[i].injectionFor(historyName)?.leftUnits,
              ),
            ] else ...[
              if (_muscleEditable) ...[
                _editableValueCell(
                  muscle: muscle,
                  side: _DoseSide.right,
                  row: row,
                ),
                _editableValueCell(
                  muscle: muscle,
                  side: _DoseSide.left,
                  row: row,
                ),
              ] else ...[
                _historyValueCell(row.rightUnits),
                _historyValueCell(row.leftUnits),
              ],
            ],
        ],
      ),
    );
  }

  bool _rowHasData([MuscleRowState? row]) {
    if (row == null) return false;
    return row.selected ||
        (row.rightUnits ?? 0) > 0 ||
        (row.leftUnits ?? 0) > 0;
  }

  Widget _buildTotalRow(List<InjectionHistoryColumn> columns) {
    return Container(
      color: AppColors.accent.withValues(alpha: 0.06),
      child: Row(
        children: [
          _fixedCell(
            width: _muscleWidth,
            align: TextAlign.left,
            child: const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          for (var i = 0; i < columns.length; i++)
            if (i < columns.length - 1) ...[
              _totalCell(columns[i].totalRight),
              _totalCell(columns[i].totalLeft),
            ] else ...[
              _totalCell(_sumRight()),
              _totalCell(_sumLeft()),
            ],
        ],
      ),
    );
  }

  Widget _buildInitialsRow(List<InjectionHistoryColumn> columns) {
    return Row(
      children: [
        _fixedCell(
          width: _muscleWidth,
          align: TextAlign.left,
          child: const Text(
            'Initials',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        for (var i = 0; i < columns.length; i++)
          if (i < columns.length - 1)
            _fixedCell(
              width: _cellWidth * 2,
              color: AppColors.surfaceMuted,
              child: Text(
                columns[i].initials?.isNotEmpty == true
                    ? columns[i].initials!
                    : '—',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            _fixedCell(
              width: _cellWidth * 2,
              padding: const EdgeInsets.all(6),
              child: TextField(
                controller: widget.initialsController,
                enabled: widget.editable,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Sign to lock',
                  filled: true,
                  fillColor:
                      widget.editable ? Colors.white : AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _fixedCell({
    required double width,
    required Widget child,
    TextAlign align = TextAlign.center,
    EdgeInsets? padding,
    Color? color,
  }) {
    final cellPadding = padding ??
        EdgeInsets.symmetric(
          vertical: _rowPaddingV,
          horizontal: widget.compact ? 4 : 6,
        );
    return Container(
      width: width,
      padding: cellPadding,
      alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: const Border(
          right: BorderSide(color: AppColors.border),
        ),
      ),
      child: child,
    );
  }

  Widget _historyValueCell(int? value) {
    return _fixedCell(
      width: _cellWidth,
      color: AppColors.surfaceMuted,
      child: Text(
        value != null && value > 0 ? '$value' : '—',
        style: TextStyle(
          fontSize: widget.compact ? 12 : 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _editableValueCell({
    required String muscle,
    required _DoseSide side,
    required MuscleRowState row,
  }) {
    final value = side == _DoseSide.right ? row.rightUnits : row.leftUnits;
    final isActive = _activeMuscle == muscle && _activeSide == side;

    return _fixedCell(
      width: _cellWidth,
      padding: EdgeInsets.all(widget.compact ? 2 : 4),
      child: _DoseInputCell(
        value: value,
        isActive: isActive,
        compact: widget.compact,
        onTap: () => _selectDoseCell(muscle, side, row),
      ),
    );
  }

  Widget _totalCell(int value) {
    return _fixedCell(
      width: _cellWidth,
      color: AppColors.accent.withValues(alpha: 0.08),
      child: Text(
        '$value',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          fontSize: 13,
        ),
      ),
    );
  }

  void _updateRow(String muscle, MuscleRowState row) {
    final updated = Map<String, MuscleRowState>.from(widget.muscleRows);
    updated[muscle] = row;
    widget.onRowsChanged(updated);
  }

  Color _columnColor(int index) =>
      index.isEven ? AppColors.primary : AppColors.accent;

  Color? _columnTint(int index) =>
      _columnColor(index).withValues(alpha: 0.06);

  int _sumRight() {
    var sum = 0;
    for (final row in widget.muscleRows.values) {
      if (row.selected) sum += row.rightUnits ?? 0;
    }
    return sum;
  }

  int _sumLeft() {
    var sum = 0;
    for (final row in widget.muscleRows.values) {
      if (row.selected) sum += row.leftUnits ?? 0;
    }
    return sum;
  }
}

class _DoseInputCell extends StatelessWidget {
  const _DoseInputCell({
    required this.value,
    required this.isActive,
    required this.onTap,
    this.compact = false,
  });

  final int? value;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final display = (value ?? 0) > 0 ? '$value' : '—';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            vertical: compact ? 6 : 10,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.border,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Text(
            display,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: (value ?? 0) > 0
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DoseKeypad extends StatelessWidget {
  const _DoseKeypad({
    required this.label,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onDone,
    this.compact = false,
  });

  final String label;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onDone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 11 : 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          _keypadRow(['1', '2', '3']),
          SizedBox(height: compact ? 4 : 8),
          _keypadRow(['4', '5', '6']),
          SizedBox(height: compact ? 4 : 8),
          _keypadRow(['7', '8', '9']),
          SizedBox(height: compact ? 4 : 8),
          Row(
            children: [
              Expanded(child: _key('C', onClear)),
              const SizedBox(width: 8),
              Expanded(child: _key('0', () => onDigit('0'))),
              const SizedBox(width: 8),
              Expanded(
                child: _keyIcon(Icons.backspace_outlined, onBackspace),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keypadRow(List<String> digits) {
    return Row(
      children: [
        for (var i = 0; i < digits.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _key(digits[i], () => onDigit(digits[i]))),
        ],
      ],
    );
  }

  Widget _key(String label, VoidCallback onPressed) {
    final height = compact ? 40.0 : 48.0;
    return SizedBox(
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.primary,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 18 : 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _keyIcon(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: compact ? 40 : 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _CustomMuscleNameField extends StatefulWidget {
  const _CustomMuscleNameField({
    super.key,
    required this.initialValue,
    required this.fontSize,
    required this.bold,
    required this.onCommitted,
  });

  final String initialValue;
  final double fontSize;
  final bool bold;
  final ValueChanged<String> onCommitted;

  @override
  State<_CustomMuscleNameField> createState() => _CustomMuscleNameFieldState();
}

class _CustomMuscleNameFieldState extends State<_CustomMuscleNameField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late String _lastCommitted;

  @override
  void initState() {
    super.initState();
    _lastCommitted = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _CustomMuscleNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt parent text when not editing (e.g. copy-from-previous).
    if (!_focusNode.hasFocus && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _lastCommitted = widget.initialValue;
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final value = _controller.text;
    if (value == _lastCommitted) return;
    _lastCommitted = value;
    widget.onCommitted(value);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontWeight: widget.bold ? FontWeight.w600 : FontWeight.w500,
      ),
      decoration: const InputDecoration(
        isDense: true,
        hintText: 'Custom muscle',
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
      textInputAction: TextInputAction.done,
      onEditingComplete: _commit,
      onSubmitted: (_) => _commit(),
    );
  }
}

enum _DoseSide { right, left }
