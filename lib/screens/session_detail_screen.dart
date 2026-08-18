import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/assessment_session.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../models/spasticity_assessment.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_card.dart';
import '../widgets/patient_picker_sheet.dart';
import 'assessment_form_screen.dart';
import 'assessment_screen.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({
    super.key,
    required this.repository,
    required this.facilityId,
    required this.sessionId,
    required this.facilityName,
  });

  final LtcRepository repository;
  final String facilityId;
  final String sessionId;
  final String facilityName;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _loading = true;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.repository.loadSessionDetail(
        facilityId: widget.facilityId,
        sessionId: widget.sessionId,
      );
      if (mounted) setState(() => _loading = false);
    });
  }

  SpasticityAssessment? _previousAssessment(Patient patient) {
    final others = patient.assessments
        .where((a) => a.sessionId != widget.sessionId)
        .toList()
      ..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
    return others.isEmpty ? null : others.first;
  }

  Future<void> _copyFromPastSession(BuildContext context) async {
    final sessions = widget.repository
        .getSortedSessions(widget.facilityId)
        .where((s) => s.id != widget.sessionId)
        .toList();

    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No earlier sessions available to copy from.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showDialog<AssessmentSession>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Copy patients from session'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final count = widget.repository.getSessionPatientCount(
                  widget.facilityId,
                  session.id,
                );
                return ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(formatDate(session.sessionDate)),
                  subtitle: Text(
                    count > 0
                        ? '$count patient${count == 1 ? '' : 's'}'
                        : 'Patients load when selected',
                  ),
                  onTap: () => Navigator.pop(context, session),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy all patients?'),
        content: Text(
          'Add every patient from ${formatDate(selected.sessionDate)} '
          'to this session? Existing patients already here will be skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy patients'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final session =
        widget.repository.getSession(widget.facilityId, widget.sessionId);
    if (session == null) return;

    setState(() => _copying = true);
    final added = await widget.repository.copyPatientsFromSession(
      facilityId: widget.facilityId,
      sourceSessionId: selected.id,
      targetSessionId: widget.sessionId,
      targetSessionDate: session.sessionDate,
    );
    if (!mounted) return;
    setState(() => _copying = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added > 0
              ? 'Added $added patient${added == 1 ? '' : 's'} from ${formatDate(selected.sessionDate)}'
              : (widget.repository.error ?? 'No patients were added'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: added > 0 ? AppColors.success : null,
      ),
    );
  }

  void _openAssessmentForm(
    BuildContext context, {
    required Patient patient,
    required DateTime sessionDate,
  }) {
    final existing = widget.repository.getPatientAssessmentInSession(
      widget.facilityId,
      patient.id,
      widget.sessionId,
    );
    final previous = _previousAssessment(patient);
    final type = existing?.assessmentType ??
        (previous != null ? AssessmentType.followUp : AssessmentType.initial);

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AssessmentFormScreen(
          repository: widget.repository,
          facilityId: widget.facilityId,
          patientId: patient.id,
          sessionId: widget.sessionId,
          facilityName: widget.facilityName,
          assessmentType: type,
          previousAssessment: previous,
          existingAssessment: existing,
          sessionDate: sessionDate,
        ),
      ),
    );
  }

  Future<void> _createPatient(
    BuildContext context,
    DateTime sessionDate,
  ) async {
    final result = await Navigator.push<PatientFormResult>(
      context,
      MaterialPageRoute(
        builder: (context) => PatientFormScreen(
          repository: widget.repository,
          defaultFacilityId: widget.facilityId,
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    final patient =
        widget.repository.getPatient(result.facilityId, result.patientId);
    if (patient == null) return;

    if (result.facilityId != widget.facilityId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${patient.name} was added to another facility. '
            'Open that facility\'s session to assess them.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final enrolled = await widget.repository.enrollPatientsInSession(
      facilityId: widget.facilityId,
      sessionId: widget.sessionId,
      patientIds: [patient.id],
      sessionDate: sessionDate,
    );
    if (!context.mounted) return;
    if (!enrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.repository.error ?? 'Could not add patient'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${patient.name} added to session'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _addPatient(BuildContext context) {
    if (!AccessScope.of(context).canUpdate(AuthResource.sessions) &&
        !AccessScope.of(context).canCreate(AuthResource.sessions) &&
        !AccessScope.of(context).canCreate(AuthResource.assessments)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to add patients.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final session =
        widget.repository.getSession(widget.facilityId, widget.sessionId);
    if (session == null) return;

    showPatientPickerSheet(
      context: context,
      repository: widget.repository,
      facilityId: widget.facilityId,
      sessionId: widget.sessionId,
      sessionDate: session.sessionDate,
      onOpenAssessment: (patient) => _openAssessmentForm(
        context,
        patient: patient,
        sessionDate: session.sessionDate,
      ),
      onCreatePatient: () => _createPatient(context, session.sessionDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final session =
            widget.repository.getSession(widget.facilityId, widget.sessionId);
        if (session == null) {
          return const AppShell(
            title: 'Not Found',
            body: Center(child: Text('Session not found')),
          );
        }

        if (_loading) {
          return AppShell(
            title: formatDate(session.sessionDate),
            subtitle: 'Session Patients',
            body: const LoadingView(message: 'Loading session patients…'),
          );
        }

        final patients = widget.repository.getPatientsInSession(
          widget.facilityId,
          widget.sessionId,
        );
        final canAddPatient =
            AccessScope.of(context).canUpdate(AuthResource.sessions) ||
                AccessScope.of(context).canCreate(AuthResource.sessions) ||
                AccessScope.of(context).canCreate(AuthResource.assessments);
        final canEditAssessment =
            AccessScope.of(context).canUpdate(AuthResource.assessments);
        final canCreateAssessment =
            AccessScope.of(context).canCreate(AuthResource.assessments);

        return AppShell(
          title: formatDate(session.sessionDate),
          subtitle: 'Session Patients',
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pagePadding,
                  24,
                  AppSpacing.pagePadding,
                  24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_available_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDate(session.sessionDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.facilityName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatBadge(
                      label: 'Completed',
                      value: '${patients.length}',
                    ),
                  ],
                ),
              ),
              if (canAddPatient)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _copying ? null : () => _addPatient(context),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Add Patient'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copying
                              ? null
                              : () => _copyFromPastSession(context),
                          icon: _copying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.copy_all_outlined),
                          label: Text(
                            _copying ? 'Copying…' : 'Copy from session',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: patients.isEmpty
                    ? Center(
                        child: Text(
                          canAddPatient
                              ? 'No patients in this session yet.\nTap "Add Patient" or "Copy from session".'
                              : 'No patients in this session yet.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.pagePadding,
                          0,
                          AppSpacing.pagePadding,
                          24,
                        ),
                        itemCount: patients.length,
                        itemBuilder: (context, index) {
                          final patient = patients[index];
                          final assessment = widget.repository
                              .getPatientAssessmentInSession(
                            widget.facilityId,
                            patient.id,
                            widget.sessionId,
                          );
                          if (assessment == null) {
                            return const SizedBox.shrink();
                          }
                          return _SessionPatientCard(
                            patient: patient,
                            assessment: assessment,
                            canEdit: canEditAssessment || canCreateAssessment,
                            onView: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => AssessmentScreen(
                                    repository: widget.repository,
                                    facilityId: widget.facilityId,
                                    patientId: patient.id,
                                    assessmentId: assessment.id,
                                    facilityName: widget.facilityName,
                                  ),
                                ),
                              );
                            },
                            onEdit: () {
                              if (assessment.isSigned ||
                                  !(canEditAssessment ||
                                      canCreateAssessment)) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (context) => AssessmentScreen(
                                      repository: widget.repository,
                                      facilityId: widget.facilityId,
                                      patientId: patient.id,
                                      assessmentId: assessment.id,
                                      facilityName: widget.facilityName,
                                    ),
                                  ),
                                );
                                return;
                              }
                              _openAssessmentForm(
                                context,
                                patient: patient,
                                sessionDate: session.sessionDate,
                              );
                            },
                            onProfile: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => PatientDetailScreen(
                                    repository: widget.repository,
                                    facilityId: widget.facilityId,
                                    patientId: patient.id,
                                    facilityName: widget.facilityName,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionPatientCard extends StatelessWidget {
  const _SessionPatientCard({
    required this.patient,
    required this.assessment,
    required this.canEdit,
    required this.onView,
    required this.onEdit,
    required this.onProfile,
  });

  final Patient patient;
  final SpasticityAssessment assessment;
  final bool canEdit;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: assessment.isSigned || !canEdit ? onView : onEdit,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                  child: Text(
                    patientInitials(patient.name),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'OHIP ${patient.ohipNumber} · ${assessment.assessmentType.label}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          ...assessment.bodyParts.map(
                            (part) => StatusChip(
                              label: part.label,
                              color: AppColors.primary,
                            ),
                          ),
                          if (assessment.isSigned)
                            const StatusChip(
                              label: 'Signed',
                              color: AppColors.warning,
                            ),
                          if (assessment.botoxInjections.isNotEmpty)
                            StatusChip(
                              label: '${assessment.totalBotoxUnits}u Botox',
                              color: AppColors.accent,
                            ),
                          if (assessment.outcome != null)
                            StatusChip(
                              label: assessment.outcome!.label,
                              color: assessment.outcome == Outcome.improved
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        onView();
                      case 'edit':
                        onEdit();
                      case 'profile':
                        onProfile();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View assessment'),
                    ),
                    if (!assessment.isSigned && canEdit)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit assessment'),
                      ),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Text('Patient profile & history'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
