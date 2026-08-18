import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/enums.dart';
import '../models/muscle_row_state.dart';
import '../models/patient.dart';
import '../models/spasticity_assessment.dart';
import '../theme/app_theme.dart';
import '../utils/muscle_injection_utils.dart';
import '../widgets/muscle_injection_grid.dart';
import '../widgets/previous_visit_summary.dart';
import '../widgets/section_card.dart';

class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({
    super.key,
    required this.repository,
    required this.facilityId,
    required this.patientId,
    required this.sessionId,
    required this.facilityName,
    required this.assessmentType,
    required this.sessionDate,
    this.existingAssessment,
    this.previousAssessment,
  });

  final LtcRepository repository;
  final String facilityId;
  final String patientId;
  final String sessionId;
  final String facilityName;
  final AssessmentType assessmentType;
  final DateTime sessionDate;
  final SpasticityAssessment? existingAssessment;
  final SpasticityAssessment? previousAssessment;

  bool get isEditing => existingAssessment != null;

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _assessmentDate;
  late Set<BodyPartAffected> _bodyParts;
  late SideAffected _side;
  Outcome? _outcome;
  late SpasticityPatterns _patterns;
  late TreatmentGoals _goals;
  late String _notes;
  late Map<String, MuscleRowState> _muscleRows;
  late String _initials;
  late bool _isPersistentlyLocked;
  bool _copiedFromPrevious = false;
  bool _saving = false;
  late bool _editingOverview;
  late bool _editingGoals;
  List<String> _muscles = const [];

  final _notesController = TextEditingController();
  final _initialsController = TextEditingController();
  final _customGoal1Controller = TextEditingController();
  final _customGoal2Controller = TextEditingController();

  bool get _hasPreviousVisit => widget.previousAssessment != null;

  bool get _isFollowUp =>
      widget.assessmentType == AssessmentType.followUp;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _muscles = widget.repository.muscleNamesFor(widget.facilityId);

    // Follow-ups start in view mode (history-selected values) until Edit.
    final startEditable = !_isFollowUp || widget.previousAssessment == null;
    _editingOverview = startEditable;
    _editingGoals = startEditable;

    final source = widget.existingAssessment;
    if (source != null) {
      _assessmentDate = source.assessmentDate;
      _bodyParts = _bodyPartsForFollowUp(source.bodyParts);
      _side = source.side;
      if (source.bodyParts.isEmpty) {
        final initialSide = _initialAssessment()?.side;
        if (initialSide != null) {
          _side = initialSide;
        }
      }
      _outcome = source.outcome;
      _patterns = _patternsForFollowUp(source.patterns);
      _goals = _goalsForFollowUp(source.goals);
      _notes = source.notes;
      _muscleRows = muscleRowsFromInjections(
        source.botoxInjections,
        muscles: _muscles,
      );
      _initials = source.initials ?? '';
      _isPersistentlyLocked = source.isSigned;
    } else {
      _assessmentDate = widget.sessionDate;
      final previous = widget.previousAssessment;
      if (_isFollowUp && previous != null) {
        _bodyParts = previous.bodyParts.isNotEmpty
            ? Set.from(previous.bodyParts)
            : {BodyPartAffected.upperLimb};
        _side = previous.side;
        _patterns = _patternsForFollowUp(const SpasticityPatterns());
        _goals = _goalsForFollowUp(const TreatmentGoals());
        _notes = previous.notes;
        _muscleRows = muscleRowsFromInjections(
          previous.botoxInjections,
          muscles: _muscles,
        );
        _outcome = null;
        _copiedFromPrevious = true;
      } else {
        final initial = _initialAssessment();
        if (_isFollowUp &&
            initial != null &&
            initial.bodyParts.isNotEmpty) {
          _bodyParts = Set.from(initial.bodyParts);
          _side = initial.side;
        } else {
          _bodyParts = {BodyPartAffected.upperLimb};
          _side = SideAffected.right;
        }
        _outcome = null;
        _patterns = _patternsForFollowUp(const SpasticityPatterns());
        _goals = _goalsForFollowUp(const TreatmentGoals());
        _notes = '';
        _muscleRows = createEmptyMuscleRows(_muscles);
      }
      _initials = '';
      _isPersistentlyLocked = false;
    }

    _notesController.text = _notes;
    _initialsController.text = _initials;
    _customGoal1Controller.text = _goals.customGoal1 ?? '';
    _customGoal2Controller.text = _goals.customGoal2 ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        widget.repository.loadFacilityMuscles(widget.facilityId),
        widget.repository.loadSpasticityPatterns(),
      ]);
      if (!mounted) return;
      setState(() {
        _muscles = widget.repository.muscleNamesFor(widget.facilityId);
        _muscleRows = muscleRowsFromInjections(
          injectionsFromMuscleRows(
            _muscleRows,
            muscleIdsByName:
                widget.repository.muscleIdsByNameFor(widget.facilityId),
          ),
          muscles: _muscles,
        );
      });
    });

    _initialsController.addListener(_onInitialsChanged);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Ignore mid-animation ticks so the app bar doesn't flicker while switching.
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  bool get _isBotoxTab => _tabController.index == 1;

  void _onInitialsChanged() => setState(() {});

  bool get _isLocallySigned => _initialsController.text.trim().isNotEmpty;

  bool get _isGridLocked => _isPersistentlyLocked || _isLocallySigned;

  SpasticityAssessment? _initialAssessment() {
    final patient = widget.repository.getPatient(
      widget.facilityId,
      widget.patientId,
    );
    return patient?.initialAssessmentOrNull;
  }

  Set<BodyPartAffected> _bodyPartsForFollowUp(List<BodyPartAffected> current) {
    if (current.isNotEmpty) return Set.from(current);
    if (widget.assessmentType != AssessmentType.followUp) {
      return Set.from(current);
    }

    final initial = _initialAssessment();
    if (initial != null && initial.bodyParts.isNotEmpty) {
      return Set.from(initial.bodyParts);
    }
    return Set.from(current);
  }

  SpasticityPatterns _patternsForFollowUp(SpasticityPatterns current) {
    if (current.hasAny) return current;
    if (!_isFollowUp) return current;

    final initial = _initialAssessment();
    if (initial != null && initial.patterns.hasAny) {
      return initial.patterns;
    }
    return current;
  }

  TreatmentGoals _goalsForFollowUp(TreatmentGoals current) {
    if (current.activeGoals.isNotEmpty) return current;
    if (!_isFollowUp) return current;

    final initial = _initialAssessment();
    if (initial != null && initial.goals.activeGoals.isNotEmpty) {
      return initial.goals;
    }
    return current;
  }

  @override
  void dispose() {
    _initialsController.removeListener(_onInitialsChanged);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _notesController.dispose();
    _initialsController.dispose();
    _customGoal1Controller.dispose();
    _customGoal2Controller.dispose();
    super.dispose();
  }

  void _copyMuscleFromPreviousRecord() {
    final patient = widget.repository.getPatient(
      widget.facilityId,
      widget.patientId,
    );
    if (patient == null) return;

    final history = _historyColumns(patient);
    final source = history.isNotEmpty
        ? history.last.injections
        : widget.previousAssessment?.botoxInjections;

    if (source == null || source.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous muscle injection record to copy'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(
      () => _muscleRows = muscleRowsFromInjections(
        source,
        muscles: _muscles,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied muscle doses from previous record'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
      ),
    );
  }

  bool _canCopyMuscleRecord(Patient? patient) {
    if (_isGridLocked) return false;
    if (patient == null) return false;
    return _historyColumns(patient).isNotEmpty ||
        widget.previousAssessment != null;
  }

  int get _totalUnits => totalUnitsForRows(_muscleRows);

  int get _selectedMuscleCount =>
      _muscleRows.values.where((row) => row.selected).length;

  List<InjectionHistoryColumn> _historyColumns(Patient patient) {
    final assessments = List<SpasticityAssessment>.from(patient.assessments)
      ..sort((a, b) => a.assessmentDate.compareTo(b.assessmentDate));

    return assessments
        .where((a) => a.sessionId != widget.sessionId)
        .map(
          (a) => InjectionHistoryColumn(
            assessmentId: a.id,
            date: a.assessmentDate,
            injections: a.botoxInjections,
            initials: a.initials,
            isSigned: a.isSigned,
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    if (_saving) return;

    final auth = AccessScope.of(context);
    final allowed = widget.isEditing
        ? auth.canUpdate(AuthResource.assessments)
        : auth.canCreate(AuthResource.assessments);
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to save assessments.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_bodyParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one body part affected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _tabController.animateTo(0);
      return;
    }

    final patient = widget.repository.getPatient(
      widget.facilityId,
      widget.patientId,
    );
    if (patient == null) return;

    final goals = _goals.copyWith(
      customGoal1: _customGoal1Controller.text.trim().isEmpty
          ? null
          : _customGoal1Controller.text.trim(),
      customGoal2: _customGoal2Controller.text.trim().isEmpty
          ? null
          : _customGoal2Controller.text.trim(),
    );

    setState(() => _saving = true);

    // Ensure custom muscles exist on the facility so injections include muscle_id.
    final muscleIds = Map<String, String>.from(
      widget.repository.muscleIdsByNameFor(widget.facilityId),
    );
    for (final entry in _muscleRows.entries) {
      final row = entry.value;
      if (!row.selected) continue;
      final hasUnits =
          (row.rightUnits ?? 0) > 0 || (row.leftUnits ?? 0) > 0;
      if (!hasUnits) continue;

      final name = row.isCustom
          ? (row.customLabel?.trim() ?? '')
          : entry.key;
      if (name.isEmpty) continue;
      if (muscleIds.containsKey(name)) continue;

      final created = await widget.repository.ensureFacilityMuscle(
        facilityId: widget.facilityId,
        name: name,
      );
      if (created == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.repository.error ??
                  'Could not create custom muscle "$name". '
                      'Check muscles.create permission.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      muscleIds[created.name] = created.id;
      if (created.name != name) muscleIds[name] = created.id;
    }

    final assessment = SpasticityAssessment(
      id: widget.existingAssessment?.id ??
          'a-${DateTime.now().millisecondsSinceEpoch}',
      sessionId: widget.sessionId,
      patientId: widget.patientId,
      assessmentDate: _assessmentDate,
      bodyParts: _bodyParts.toList(),
      side: _side,
      assessmentType: widget.assessmentType,
      outcome: _outcome,
      patterns: _patterns,
      goals: goals,
      notes: _notesController.text.trim(),
      botoxInjections: injectionsFromMuscleRows(
        _muscleRows,
        muscleIdsByName: muscleIds,
      ),
      initials: _initialsController.text.trim().isEmpty
          ? null
          : _initialsController.text.trim(),
    );

    final saved = await widget.repository.saveAssessment(
      facilityId: widget.facilityId,
      patientId: widget.patientId,
      assessment: assessment,
      isEditing: widget.isEditing,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.repository.error ?? 'Could not save assessment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing ? 'Assessment updated' : 'Assessment saved',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_isPersistentlyLocked) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _assessmentDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final patient = widget.repository.getPatient(
      widget.facilityId,
      widget.patientId,
    );
    final title = widget.isEditing
        ? 'Edit ${widget.assessmentType.label}'
        : 'New ${widget.assessmentType.label}';
    final history = patient != null ? _historyColumns(patient) : <InjectionHistoryColumn>[];
    final canCopyMuscles = _canCopyMuscleRecord(patient);
    final auth = AccessScope.of(context);
    final canSave = !_isPersistentlyLocked &&
        (widget.isEditing
            ? auth.canUpdate(AuthResource.assessments)
            : auth.canCreate(AuthResource.assessments));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: _isBotoxTab ? 44 : kToolbarHeight,
        titleSpacing: _isBotoxTab ? 12 : null,
        title: _isBotoxTab
            ? Text(
                patient?.name ?? title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (patient != null)
                    Text(
                      patient.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
        actions: [
          if (canSave)
            _isBotoxTab
                ? IconButton(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    tooltip: 'Save',
                  )
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          SizedBox(width: _isBotoxTab ? 4 : 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isBotoxTab ? 38 : 48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(
              fontSize: _isBotoxTab ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
            labelPadding: EdgeInsets.symmetric(
              horizontal: _isBotoxTab ? 8 : 12,
            ),
            tabs: [
              Tab(
                height: _isBotoxTab ? 34 : null,
                icon: Icon(Icons.info_outline, size: _isBotoxTab ? 18 : 20),
                text: _isBotoxTab ? null : 'Overview',
              ),
              Tab(
                height: _isBotoxTab ? 34 : null,
                icon: Icon(
                  Icons.medical_services_outlined,
                  size: _isBotoxTab ? 18 : 20,
                ),
                text: _isBotoxTab ? null : 'Botox',
              ),
              Tab(
                height: _isBotoxTab ? 34 : null,
                icon: Icon(Icons.flag_outlined, size: _isBotoxTab ? 18 : 20),
                text: _isBotoxTab ? null : 'Goals',
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOverviewTab(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _isBotoxTab ? 6 : AppSpacing.pagePadding,
                    _isBotoxTab ? 4 : AppSpacing.pagePadding,
                    _isBotoxTab ? 6 : AppSpacing.pagePadding,
                    _isBotoxTab ? 4 : AppSpacing.pagePadding,
                  ),
                  child: MuscleInjectionGrid(
                    compact: _isBotoxTab,
                    historyColumns: history,
                    currentDate: _assessmentDate,
                    muscleRows: _muscleRows,
                    muscles: _muscles,
                    initialsController: _initialsController,
                    editable: !_isPersistentlyLocked && !_saving,
                    muscleEditable: !_isGridLocked && !_saving,
                    showCopyButton: canCopyMuscles,
                    onCopyFromPrevious: _copyMuscleFromPreviousRecord,
                    onRowsChanged: (rows) => setState(() => _muscleRows = rows),
                  ),
                ),
                _buildGoalsTab(),
              ],
            ),
          ),
          _BottomBar(
            totalUnits: _totalUnits,
            muscleCount: _selectedMuscleCount,
            onSave: canSave ? _save : null,
            isLocked: _isPersistentlyLocked,
            compact: _isBotoxTab,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final catalog = widget.repository.patternCatalog;
        final canEditOverview =
            !_isPersistentlyLocked && (_editingOverview || !_isFollowUp);

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            if (_isPersistentlyLocked)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpacing.sectionGap),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This assessment is signed and locked.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_hasPreviousVisit) ...[
              PreviousVisitSummary(
                assessment: widget.previousAssessment!,
                catalog: catalog,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _copiedFromPrevious
                          ? 'This follow-up visit (from history)'
                          : 'This follow-up visit',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                  if (_overviewEditTrailing() case final editBtn?) editBtn,
                ],
              ),
              const SizedBox(height: 12),
            ],
            SectionCard(
              title: 'Visit Details',
              icon: Icons.calendar_today_outlined,
              child: Column(
                children: [
                  _FormTile(
                    label: 'Assessment Date',
                    child: InkWell(
                      onTap: canEditOverview ? _pickDate : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Text(
                              formatDate(_assessmentDate),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (canEditOverview) ...[
                              const Spacer(),
                              const Icon(Icons.edit,
                                  size: 16, color: AppColors.accent),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormTile(
                    label: 'Assessment Type',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.assessmentType.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SectionCard(
              title: 'Clinical Classification',
              icon: Icons.category_outlined,
              child: canEditOverview
                  ? Column(
                      children: [
                        _FormTile(
                          label: 'Body Parts Affected',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: BodyPartAffected.values.map((part) {
                              final selected = _bodyParts.contains(part);
                              return FilterChip(
                                label: Text(part.label),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _bodyParts.add(part);
                                    } else {
                                      _bodyParts.remove(part);
                                    }
                                  });
                                },
                                selectedColor:
                                    AppColors.primary.withValues(alpha: 0.15),
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                                side: BorderSide(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DropdownTile<SideAffected>(
                          label: 'Side Affected',
                          value: _side,
                          items: SideAffected.values,
                          labelBuilder: (v) => v.label,
                          onChanged: (v) => setState(() => _side = v!),
                        ),
                        const SizedBox(height: 12),
                        _DropdownTile<Outcome?>(
                          label: 'Outcome',
                          value: _outcome,
                          items: const [
                            null,
                            Outcome.improved,
                            Outcome.notImproved,
                          ],
                          labelBuilder: (v) =>
                              v == null ? 'Not yet assessed' : v.label,
                          onChanged: (v) => setState(() => _outcome = v),
                        ),
                      ],
                    )
                  : _overviewClassificationSummary(),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            SectionCard(
              title: 'Spasticity Pattern',
              icon: Icons.analytics_outlined,
              child: canEditOverview
                  ? _buildSpasticityPatternEditor(editable: true)
                  : _buildSpasticityPatternSummary(),
            ),
          ],
        );
      },
    );
  }

  Widget? _overviewEditTrailing() {
    if (_isPersistentlyLocked || !_isFollowUp || !_hasPreviousVisit) {
      return null;
    }
    return TextButton.icon(
      onPressed: () => setState(() => _editingOverview = !_editingOverview),
      icon: Icon(_editingOverview ? Icons.visibility_outlined : Icons.edit_outlined),
      label: Text(_editingOverview ? 'Done' : 'Edit'),
    );
  }

  Widget _overviewClassificationSummary() {
    return Column(
      children: [
        InfoTile(
          label: 'Body Parts',
          value: formatBodyParts(_bodyParts),
          icon: Icons.accessibility_new_outlined,
        ),
        const SizedBox(height: 10),
        InfoTile(
          label: 'Side',
          value: _side.label,
          icon: Icons.swap_horiz,
        ),
        const SizedBox(height: 10),
        InfoTile(
          label: 'Outcome',
          value: _outcome?.label ?? 'Not yet assessed',
          icon: Icons.trending_up,
        ),
      ],
    );
  }

  Widget _buildSpasticityPatternSummary() {
    final catalog = widget.repository.patternCatalog;
    if (!_patterns.hasAny) {
      return const Text(
        'No patterns selected',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    final rows = <Widget>[];
    final regions = catalog.isEmpty
        ? _patterns.byRegion.entries
        : [
            ...catalog.orderedRegions.map(
              (entry) => MapEntry(entry.key, _patterns.keysFor(entry.key)),
            ),
          ];

    for (final entry in regions) {
      if (entry.value.isEmpty) continue;
      final label = catalog.isEmpty
          ? entry.key
          : catalog.regionLabel(entry.key);
      final values = entry.value
          .map(
            (key) => catalog.isEmpty
                ? key.replaceAll('_', ' ')
                : catalog.optionLabel(entry.key, key),
          )
          .join(', ');
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(child: Text(values)),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildSpasticityPatternEditor({bool editable = true}) {
    final catalog = widget.repository.patternCatalog;
    if (catalog.isEmpty) {
      return const Text(
        'Pattern options are not available yet. Check your connection and reopen this chart.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      );
    }

    return Column(
      children: catalog.orderedRegions.map((entry) {
        final regionKey = entry.key;
        final options = entry.value;
        final selected = _patterns.keysFor(regionKey).toSet();

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _FormTile(
            label: catalog.regionLabel(regionKey),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selected.contains(option.key);
                return FilterChip(
                  label: Text(option.label),
                  selected: isSelected,
                  onSelected: !editable || _isPersistentlyLocked
                      ? null
                      : (value) {
                          setState(() {
                            final next = Set<String>.from(selected);
                            if (value) {
                              next.add(option.key);
                            } else {
                              next.remove(option.key);
                            }
                            _patterns = _patterns.withRegion(
                              regionKey,
                              next.toList(),
                            );
                          });
                        },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalsTab() {
    final canEditGoals =
        !_isPersistentlyLocked && (_editingGoals || !_isFollowUp);
    final catalog = widget.repository.patternCatalog;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      children: [
        if (_hasPreviousVisit) ...[
          PreviousVisitSummary(
            assessment: widget.previousAssessment!,
            catalog: catalog,
            title: 'Previous visit',
            initiallyExpanded: false,
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Row(
            children: [
              Expanded(
                child: Text(
                  'This follow-up visit',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
              ),
              if (!_isPersistentlyLocked && _isFollowUp && _hasPreviousVisit)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _editingGoals = !_editingGoals),
                  icon: Icon(
                    _editingGoals
                        ? Icons.visibility_outlined
                        : Icons.edit_outlined,
                  ),
                  label: Text(_editingGoals ? 'Done' : 'Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SectionCard(
          title: 'Treatment Goals',
          icon: Icons.flag_outlined,
          child: canEditGoals
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GoalChip(
                      'Spasm',
                      _goals.spasm,
                      (v) => setState(() => _goals = _goals.copyWith(spasm: v)),
                    ),
                    _GoalChip(
                      'Pain',
                      _goals.pain,
                      (v) => setState(() => _goals = _goals.copyWith(pain: v)),
                    ),
                    _GoalChip(
                      'Positioning',
                      _goals.positioning,
                      (v) => setState(
                        () => _goals = _goals.copyWith(positioning: v),
                      ),
                    ),
                    _GoalChip(
                      'Contracture',
                      _goals.contracture,
                      (v) => setState(
                        () => _goals = _goals.copyWith(contracture: v),
                      ),
                    ),
                    _GoalChip(
                      'Deformity',
                      _goals.deformity,
                      (v) =>
                          setState(() => _goals = _goals.copyWith(deformity: v)),
                    ),
                    _GoalChip(
                      'Pressure Sore',
                      _goals.pressureSore,
                      (v) => setState(
                        () => _goals = _goals.copyWith(pressureSore: v),
                      ),
                    ),
                    _GoalChip(
                      'Poor Sleep',
                      _goals.poorSleep,
                      (v) =>
                          setState(() => _goals = _goals.copyWith(poorSleep: v)),
                    ),
                    _GoalChip(
                      'Reduced Mobility',
                      _goals.reducedMobility,
                      (v) => setState(
                        () => _goals = _goals.copyWith(reducedMobility: v),
                      ),
                    ),
                    _GoalChip(
                      'Reduced Hygiene',
                      _goals.reducedHygiene,
                      (v) => setState(
                        () => _goals = _goals.copyWith(reducedHygiene: v),
                      ),
                    ),
                    _GoalChip(
                      'Carer Burden',
                      _goals.carerBurden,
                      (v) => setState(
                        () => _goals = _goals.copyWith(carerBurden: v),
                      ),
                    ),
                  ],
                )
              : (_goals.activeGoals.isEmpty
                  ? const Text(
                      'No goals selected',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _goals.activeGoals
                          .map(
                            (goal) => Chip(
                              label: Text(goal),
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.08),
                              side: BorderSide(
                                color: AppColors.accent.withValues(alpha: 0.2),
                              ),
                            ),
                          )
                          .toList(),
                    )),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionCard(
          title: 'Custom Goals',
          icon: Icons.edit_note_outlined,
          child: canEditGoals
              ? Column(
                  children: [
                    TextField(
                      controller: _customGoal1Controller,
                      decoration: const InputDecoration(
                        labelText: 'Custom Goal 1',
                        hintText: 'Enter a custom treatment goal',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customGoal2Controller,
                      decoration: const InputDecoration(
                        labelText: 'Custom Goal 2',
                        hintText: 'Enter another custom goal',
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customGoal1Controller.text.trim().isEmpty
                          ? 'Custom Goal 1: —'
                          : 'Custom Goal 1: ${_customGoal1Controller.text.trim()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _customGoal2Controller.text.trim().isEmpty
                          ? 'Custom Goal 2: —'
                          : 'Custom Goal 2: ${_customGoal2Controller.text.trim()}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        SectionCard(
          title: 'Clinical Notes',
          icon: Icons.notes_outlined,
          child: canEditGoals
              ? TextField(
                  controller: _notesController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Enter clinical notes for this visit...',
                    alignLabelWithHint: true,
                  ),
                )
              : Text(
                  _notesController.text.trim().isEmpty
                      ? 'No clinical notes'
                      : _notesController.text.trim(),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _notesController.text.trim().isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.totalUnits,
    required this.muscleCount,
    required this.onSave,
    this.isLocked = false,
    this.compact = false,
  });

  final int totalUnits;
  final int muscleCount;
  final VoidCallback? onSave;
  final bool isLocked;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 8 : 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: Row(
        children: [
          Text(
            '$muscleCount muscles · $totalUnits units',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 13 : 15,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isLocked
                    ? 'Signed record is locked'
                    : 'Sign with initials on Botox tab to lock',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (onSave != null)
            compact
                ? IconButton.filled(
                    onPressed: onSave,
                    icon: const Icon(Icons.check, size: 20),
                    tooltip: 'Save assessment',
                  )
                : FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Assessment'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

class _FormTile extends StatelessWidget {
  const _FormTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  const _DropdownTile({
    required this.label,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _FormTile(
      label: label,
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(labelBuilder(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip(this.label, this.selected, this.onChanged);

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      selectedColor: AppColors.accent.withValues(alpha: 0.15),
      checkmarkColor: AppColors.accent,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? AppColors.accent : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
    );
  }
}
