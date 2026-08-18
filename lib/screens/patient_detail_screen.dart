import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../models/spasticity_assessment.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/section_card.dart';
import 'assessment_form_screen.dart';
import 'assessment_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  const PatientDetailScreen({
    super.key,
    required this.repository,
    required this.facilityId,
    required this.patientId,
    required this.facilityName,
  });

  final LtcRepository repository;
  final String facilityId;
  final String patientId;
  final String facilityName;

  List<SpasticityAssessment> _sortedAssessments(Patient patient) {
    return List<SpasticityAssessment>.from(patient.assessments)
      ..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
  }

  void _openEditForm(
    BuildContext context, {
    required SpasticityAssessment assessment,
    required Patient patient,
  }) {
    final others = patient.assessments
        .where((a) => a.id != assessment.id)
        .toList()
      ..sort((a, b) => b.assessmentDate.compareTo(a.assessmentDate));
    final previous = others.isEmpty ? null : others.first;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => AssessmentFormScreen(
          repository: repository,
          facilityId: facilityId,
          patientId: patientId,
          sessionId: assessment.sessionId,
          facilityName: facilityName,
          assessmentType: assessment.assessmentType,
          existingAssessment: assessment,
          previousAssessment: previous,
          sessionDate: assessment.assessmentDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        final patient = repository.getPatient(facilityId, patientId);
        if (patient == null) {
          return const AppShell(
            title: 'Not Found',
            body: Center(child: Text('Patient not found')),
          );
        }

        final visits = _sortedAssessments(patient);
        return _buildContent(context, patient, visits);
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Patient patient,
    List<SpasticityAssessment> visits,
  ) {
    return AppShell(
      title: patient.name,
      subtitle: 'Visit History',
      body: Column(
        children: [
          _PatientBanner(patient: patient, facilityName: facilityName),
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              20,
              AppSpacing.pagePadding,
              12,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'To add a new visit, go to the LTC facility and create or open a session. '
                    'The patient profile stays the same across all sessions.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
            child: Row(
              children: [
                Text(
                  'Visit History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${visits.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                0,
                AppSpacing.pagePadding,
                24,
              ),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final assessment = visits[index];
                final isLatest = index == 0;
                return _VisitCard(
                  assessment: assessment,
                  isLatest: isLatest,
                  onView: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => AssessmentScreen(
                          repository: repository,
                          facilityId: facilityId,
                          patientId: patientId,
                          assessmentId: assessment.id,
                          facilityName: facilityName,
                        ),
                      ),
                    );
                  },
                  onEdit: () => _openEditForm(
                    context,
                    assessment: assessment,
                    patient: patient,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientBanner extends StatelessWidget {
  const _PatientBanner({
    required this.patient,
    required this.facilityName,
  });

  final Patient patient;
  final String facilityName;

  @override
  Widget build(BuildContext context) {
    final latest = patient.latestAssessmentOrNull;

    return Container(
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
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              patientInitials(patient.name),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$facilityName · OHIP ${patient.ohipNumber} · Age ${patient.age}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (latest != null) ...[
                      _MiniChip(latest.assessmentType.label),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: latest.bodyParts
                            .map((part) => _MiniChip(part.label))
                            .toList(),
                      ),
                    ] else
                      const _MiniChip('No assessments yet'),
                    _MiniChip('${patient.visitCount} visits'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(
                color: _hovered ? widget.color : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: widget.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.assessment,
    required this.isLatest,
    required this.onView,
    required this.onEdit,
  });

  final SpasticityAssessment assessment;
  final bool isLatest;
  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: isLatest ? AppColors.accent : AppColors.border,
          width: isLatest ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onView,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: assessment.assessmentType == AssessmentType.initial
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    assessment.assessmentType == AssessmentType.initial
                        ? Icons.assignment_outlined
                        : Icons.update,
                    color: assessment.assessmentType == AssessmentType.initial
                        ? AppColors.primary
                        : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            formatDate(assessment.assessmentDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: 8),
                            const StatusChip(
                              label: 'Latest',
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${assessment.assessmentType.label} · ${formatBodyParts(assessment.bodyParts)} · ${assessment.side.label}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (assessment.botoxInjections.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${assessment.botoxInjections.length} muscles · ${assessment.totalBotoxUnits}u total',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit visit',
                  color: AppColors.textSecondary,
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
