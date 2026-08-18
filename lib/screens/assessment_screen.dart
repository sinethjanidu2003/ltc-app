import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/enums.dart';
import '../models/muscle_row_state.dart';
import '../models/patient.dart';
import '../models/spasticity_assessment.dart';
import '../models/spasticity_pattern_catalog.dart';
import '../theme/app_theme.dart';
import '../utils/clinical_address.dart';
import '../utils/muscle_injection_utils.dart';
import '../widgets/app_shell.dart';
import '../widgets/muscle_injection_grid.dart';
import '../widgets/section_card.dart';
import 'assessment_form_screen.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({
    super.key,
    required this.repository,
    required this.facilityId,
    required this.patientId,
    required this.assessmentId,
    required this.facilityName,
  });

  final LtcRepository repository;
  final String facilityId;
  final String patientId;
  final String assessmentId;
  final String facilityName;

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.loadSpasticityPatterns();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final patient =
            widget.repository.getPatient(widget.facilityId, widget.patientId);
        final assessment = widget.repository.getAssessment(
          widget.facilityId,
          widget.patientId,
          widget.assessmentId,
        );

        if (patient == null || assessment == null) {
          return const AppShell(
            title: 'Not Found',
            body: Center(child: Text('Assessment not found')),
          );
        }

        final catalog = widget.repository.patternCatalog;

        return AppShell(
          title: patient.name,
          subtitle:
              '${assessment.assessmentType.label} · ${formatDate(assessment.assessmentDate)}',
          actions: [
            if (!assessment.isSigned &&
                AccessScope.of(context).canUpdate(AuthResource.assessments))
              IconButton(
                onPressed: () {
                  final patientRecord = widget.repository.getPatient(
                    widget.facilityId,
                    widget.patientId,
                  );
                  SpasticityAssessment? previous;
                  if (patientRecord != null) {
                    final others = patientRecord.assessments
                        .where((a) => a.id != assessment.id)
                        .toList()
                      ..sort(
                        (a, b) =>
                            b.assessmentDate.compareTo(a.assessmentDate),
                      );
                    previous = others.isEmpty ? null : others.first;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => AssessmentFormScreen(
                        repository: widget.repository,
                        facilityId: widget.facilityId,
                        patientId: widget.patientId,
                        sessionId: assessment.sessionId,
                        facilityName: widget.facilityName,
                        assessmentType: assessment.assessmentType,
                        existingAssessment: assessment,
                        previousAssessment: previous,
                        sessionDate: assessment.assessmentDate,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit assessment',
              ),
          ],
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _PatientHeaderBanner(
                      patient: patient,
                      facilityName: widget.facilityName,
                      assessment: assessment,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                      40,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: isWide
                          ? _WideLayout(
                              repository: widget.repository,
                              facilityId: widget.facilityId,
                              assessment: assessment,
                              patient: patient,
                              catalog: catalog,
                            )
                          : _NarrowLayout(
                              repository: widget.repository,
                              facilityId: widget.facilityId,
                              assessment: assessment,
                              patient: patient,
                              catalog: catalog,
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PatientHeaderBanner extends StatelessWidget {
  const _PatientHeaderBanner({
    required this.patient,
    required this.facilityName,
    required this.assessment,
  });

  final Patient patient;
  final String facilityName;
  final SpasticityAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        28,
        AppSpacing.pagePadding,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(
                  patientInitials(patient.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      facilityName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (assessment.outcome != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (assessment.outcome == Outcome.improved
                            ? AppColors.success
                            : AppColors.warning)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    assessment.outcome!.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final clinicalAddress = parseClinicalAddress(patient.address);
              final tiles = <Widget>[
                _HeaderTile(label: 'OHIP', value: patient.ohipNumber),
                _HeaderTile(
                  label: 'Date of Birth',
                  value: formatDate(patient.dateOfBirth),
                ),
                _HeaderTile(label: 'Age', value: '${patient.age} years'),
                _HeaderTile(
                  label: 'Assessment Date',
                  value: formatDate(assessment.assessmentDate),
                ),
                if (clinicalAddress.isParsed) ...[
                  _HeaderTile(
                    label: 'Date of Admission',
                    value: clinicalAddress.dateOfAdmission!,
                  ),
                  _HeaderTile(
                    label: 'Condition',
                    value: clinicalAddress.condition!,
                  ),
                ] else
                  _HeaderTile(
                    label: 'Address',
                    value: (clinicalAddress.rawAddress != null &&
                            clinicalAddress.rawAddress!.isNotEmpty)
                        ? clinicalAddress.rawAddress!
                        : '—',
                  ),
              ];

              if (isWide && tiles.length <= 5) {
                return Row(
                  children: tiles
                      .map(
                        (t) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: t,
                          ),
                        ),
                      )
                      .toList(),
                );
              }

              final columns = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;
              final tileWidth =
                  (constraints.maxWidth - (12 * (columns - 1))) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tiles
                    .map(
                      (t) => SizedBox(
                        width: tileWidth,
                        child: t,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderTile extends StatelessWidget {
  const _HeaderTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.repository,
    required this.facilityId,
    required this.assessment,
    required this.patient,
    required this.catalog,
  });

  final LtcRepository repository;
  final String facilityId;
  final SpasticityAssessment assessment;
  final Patient patient;
  final SpasticityPatternCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _OverviewSection(assessment: assessment),
              const SizedBox(height: AppSpacing.sectionGap),
              _PatternsSection(
                patterns: assessment.patterns,
                catalog: catalog,
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              _GoalsSection(goals: assessment.goals),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sectionGap),
        Expanded(
          child: Column(
            children: [
              _BotoxGridSection(
                repository: repository,
                facilityId: facilityId,
                patient: patient,
                assessment: assessment,
              ),
              if (assessment.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sectionGap),
                _NotesSection(notes: assessment.notes),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.repository,
    required this.facilityId,
    required this.assessment,
    required this.patient,
    required this.catalog,
  });

  final LtcRepository repository;
  final String facilityId;
  final SpasticityAssessment assessment;
  final Patient patient;
  final SpasticityPatternCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OverviewSection(assessment: assessment),
        const SizedBox(height: AppSpacing.sectionGap),
        _PatternsSection(
          patterns: assessment.patterns,
          catalog: catalog,
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        _GoalsSection(goals: assessment.goals),
        const SizedBox(height: AppSpacing.sectionGap),
        _BotoxGridSection(
          repository: repository,
          facilityId: facilityId,
          patient: patient,
          assessment: assessment,
        ),
        if (assessment.notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          _NotesSection(notes: assessment.notes),
        ],
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.assessment});

  final SpasticityAssessment assessment;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Assessment Overview',
      subtitle: 'Clinical classification',
      icon: Icons.assignment_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 400;
          final tiles = [
            InfoTile(
              label: 'Type',
              value: assessment.assessmentType.label,
              icon: Icons.category_outlined,
            ),
            InfoTile(
              label: 'Body Parts',
              value: formatBodyParts(assessment.bodyParts),
              icon: Icons.accessibility_new_outlined,
            ),
            InfoTile(
              label: 'Side',
              value: assessment.side.label,
              icon: Icons.swap_horiz,
            ),
            if (assessment.outcome != null)
              InfoTile(
                label: 'Outcome',
                value: assessment.outcome!.label,
                icon: Icons.trending_up,
                highlight: assessment.outcome == Outcome.improved
                    ? AppColors.success
                    : AppColors.warning,
              ),
          ];

          if (isWide) {
            return Column(
              children: [
                Row(
                  children: tiles
                      .take(2)
                      .map(
                        (t) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: 12,
                              bottom: 12,
                            ),
                            child: t,
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (tiles.length > 2)
                  Row(
                    children: tiles
                        .skip(2)
                        .map(
                          (t) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: t,
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            );
          }

          return Column(
            children: tiles
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: t,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _PatternsSection extends StatelessWidget {
  const _PatternsSection({
    required this.patterns,
    required this.catalog,
  });

  final SpasticityPatterns patterns;
  final SpasticityPatternCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<String, String>>[];

    void addRegion(String regionKey, List<String> keys) {
      if (keys.isEmpty) return;
      final label = catalog.isEmpty
          ? (regionKey.isEmpty
              ? regionKey
              : regionKey[0].toUpperCase() + regionKey.substring(1))
          : catalog.regionLabel(regionKey);
      final values = keys
          .map((key) => catalog.isEmpty
              ? key.replaceAll('_', ' ')
              : catalog.optionLabel(regionKey, key))
          .join(', ');
      entries.add(MapEntry(label, values));
    }

    if (!catalog.isEmpty) {
      for (final region in catalog.orderedRegions) {
        addRegion(region.key, patterns.keysFor(region.key));
      }
      for (final entry in patterns.byRegion.entries) {
        if (catalog.regions.containsKey(entry.key)) continue;
        addRegion(entry.key, entry.value);
      }
    } else {
      for (final entry in patterns.byRegion.entries) {
        addRegion(entry.key, entry.value);
      }
    }

    return SectionCard(
      title: 'Spasticity Pattern',
      subtitle: 'Observed tone distribution',
      icon: Icons.analytics_outlined,
      child: entries.isEmpty
          ? const Text(
              'No patterns recorded',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              children: entries.map((e) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.goals});

  final TreatmentGoals goals;

  @override
  Widget build(BuildContext context) {
    final active = goals.activeGoals;

    return SectionCard(
      title: 'Treatment Goals',
      subtitle: '${active.length} goal${active.length == 1 ? '' : 's'} selected',
      icon: Icons.flag_outlined,
      child: active.isEmpty
          ? const Text(
              'No goals selected',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: active
                  .map(
                    (goal) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            goal,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _BotoxGridSection extends StatefulWidget {
  const _BotoxGridSection({
    required this.repository,
    required this.facilityId,
    required this.patient,
    required this.assessment,
  });

  final LtcRepository repository;
  final String facilityId;
  final Patient patient;
  final SpasticityAssessment assessment;

  @override
  State<_BotoxGridSection> createState() => _BotoxGridSectionState();
}

class _BotoxGridSectionState extends State<_BotoxGridSection> {
  late final TextEditingController _initialsController;

  @override
  void initState() {
    super.initState();
    _initialsController = TextEditingController(
      text: widget.assessment.initials ?? '',
    );
  }

  @override
  void dispose() {
    _initialsController.dispose();
    super.dispose();
  }

  List<InjectionHistoryColumn> _historyColumns() {
    final assessments = List<SpasticityAssessment>.from(widget.patient.assessments)
      ..sort((a, b) => a.assessmentDate.compareTo(b.assessmentDate));

    return assessments
        .where((a) => a.id != widget.assessment.id)
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

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Botox Injection Record',
      subtitle: widget.assessment.isSigned
          ? 'Signed record · read only'
          : 'Muscle doses by visit date',
      icon: Icons.medical_services_outlined,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Total: ${widget.assessment.totalBotoxUnits}u',
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
      child: SizedBox(
        height: 520,
        child: MuscleInjectionGrid(
          historyColumns: _historyColumns(),
          currentDate: widget.assessment.assessmentDate,
          muscles: widget.repository.muscleNamesFor(widget.facilityId),
          muscleRows: muscleRowsFromInjections(
            widget.assessment.botoxInjections,
            muscles: widget.repository.muscleNamesFor(widget.facilityId),
          ),
          initialsController: _initialsController,
          editable: false,
          onRowsChanged: (_) {},
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Clinical Notes',
      icon: Icons.notes_outlined,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          notes,
          style: const TextStyle(
            height: 1.6,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
