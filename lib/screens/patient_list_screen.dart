import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/enums.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../utils/patient_search.dart';
import '../widgets/app_shell.dart';
import '../widgets/loading_view.dart';
import '../widgets/patient_search_field.dart';
import '../widgets/section_card.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({
    super.key,
    required this.repository,
    required this.facilityId,
    this.facilityName,
  });

  final LtcRepository repository;
  final String facilityId;
  final String? facilityName;

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.repository.loadFacilityPatients(widget.facilityId);
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreatePatient(BuildContext context) async {
    final result = await Navigator.push<PatientFormResult>(
      context,
      MaterialPageRoute(
        builder: (context) => PatientFormScreen(
          repository: widget.repository,
          defaultFacilityId: widget.facilityId,
        ),
      ),
    );

    if (result != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PatientDetailScreen(
            repository: widget.repository,
            facilityId: result.facilityId,
            patientId: result.patientId,
            facilityName: widget.repository.getById(result.facilityId)?.name ?? '',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final facility = widget.repository.getById(widget.facilityId);
        if (facility == null) {
          return const AppShell(
            title: 'Not Found',
            body: Center(child: Text('Facility not found')),
          );
        }

        final filteredPatients = filterPatients(facility.patients, _searchQuery);

        if (_loading) {
          return AppShell(
            title: widget.facilityName ?? facility.name,
            subtitle: 'All Patients',
            body: const LoadingView(message: 'Loading patients…'),
          );
        }

        return AppShell(
          title: widget.facilityName ?? facility.name,
          subtitle: 'All Patients',
          body: facility.patients.isEmpty
              ? _EmptyPatients(
                  onAdd: AccessScope.of(context).canCreate(AuthResource.patients)
                      ? () => _openCreatePatient(context)
                      : null,
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.pagePadding,
                        AppSpacing.pagePadding,
                        0,
                      ),
                      child: PatientSearchField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredPatients.isEmpty
                          ? const Center(
                              child: Text(
                                'No patients match your search.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : PageContent(
                              header: PageBanner(
                                title: facility.name,
                                subtitle: _searchQuery.trim().isEmpty
                                    ? facility.address
                                    : 'Showing ${filteredPatients.length} of ${facility.patients.length} patients',
                                icon: Icons.people_outline,
                                stats: [
                                  StatBadge(
                                    label: 'Patients',
                                    value: '${filteredPatients.length}',
                                  ),
                                ],
                              ),
                              child: SliverLayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.crossAxisExtent;
                                  final crossAxisCount = width > 1100
                                      ? 3
                                      : width > 650
                                          ? 2
                                          : 1;

                                  return SliverGrid(
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: AppSpacing.sectionGap,
                                      crossAxisSpacing: AppSpacing.sectionGap,
                                      childAspectRatio:
                                          crossAxisCount == 1 ? 2.4 : 1.35,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final patient = filteredPatients[index];
                                        return _PatientCard(
                                          patient: patient,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute<void>(
                                                builder: (context) =>
                                                    PatientDetailScreen(
                                                  repository: widget.repository,
                                                  facilityId: widget.facilityId,
                                                  patientId: patient.id,
                                                  facilityName: facility.name,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      childCount: filteredPatients.length,
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
          floatingActionButton:
              AccessScope.of(context).canCreate(AuthResource.patients)
                  ? FloatingActionButton.extended(
                      onPressed: () => _openCreatePatient(context),
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('New Patient'),
                    )
                  : null,
        );
      },
    );
  }
}

class _EmptyPatients extends StatelessWidget {
  const _EmptyPatients({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              onAdd == null ? 'No patients available' : 'No patients yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              onAdd == null
                  ? 'You do not have permission to create patients for this facility.'
                  : 'Create a patient profile and assign them to this LTC facility.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Create Patient'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatefulWidget {
  const _PatientCard({required this.patient, required this.onTap});

  final Patient patient;
  final VoidCallback onTap;

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final assessment = widget.patient.latestAssessmentOrNull;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(
            color: _hovered ? AppColors.accent : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _hovered ? 0.1 : 0.04),
              blurRadius: _hovered ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                        child: Text(
                          patientInitials(widget.patient.name),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.patient.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'OHIP ${widget.patient.ohipNumber}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.patient.visitCount == 0
                              ? 'No visits'
                              : '${widget.patient.visitCount} visits',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (assessment != null)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...assessment.bodyParts.map(
                          (part) => StatusChip(
                            label: part.label,
                            color: AppColors.primary,
                          ),
                        ),
                        StatusChip(
                          label: assessment.side.label,
                          color: AppColors.accent,
                        ),
                        StatusChip(
                          label: assessment.assessmentType.label,
                          color: AppColors.textSecondary,
                        ),
                        if (assessment.outcome != null)
                          StatusChip(
                            label: assessment.outcome!.label,
                            color: assessment.outcome == Outcome.improved
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                      ],
                    )
                  else
                    const Text(
                      'No assessments yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  const Spacer(),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        assessment != null
                            ? 'Last: ${formatDate(assessment.assessmentDate)}'
                            : 'Age ${widget.patient.age}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Open patient',
                        style: TextStyle(
                          color:
                              _hovered ? AppColors.accent : AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _hovered ? AppColors.accent : AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
