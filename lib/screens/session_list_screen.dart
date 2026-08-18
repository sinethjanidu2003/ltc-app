import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/assessment_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/loading_view.dart';
import '../widgets/section_card.dart';
import 'patient_list_screen.dart';
import 'session_detail_screen.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({
    super.key,
    required this.repository,
    required this.facilityId,
  });

  final LtcRepository repository;
  final String facilityId;

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        widget.repository.loadFacilitySessions(widget.facilityId),
        widget.repository.loadFacilityPatients(widget.facilityId),
      ]);
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _createSession(BuildContext context) async {
    if (!AccessScope.of(context).canCreate(AuthResource.sessions)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to create sessions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var selectedDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New Assessment Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Each session is a visit date to this LTC. '
                  'Add existing patients to the session without creating new profiles.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Session Date'),
                  subtitle: Text(formatDate(selectedDate)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Create Session'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      final session = await widget.repository.addSession(
        facilityId: widget.facilityId,
        sessionDate: selectedDate,
      );
      if (!context.mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.repository.error ?? 'Could not create session',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session created for ${formatDate(selectedDate)}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
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

        final sessions =
            widget.repository.getSortedSessions(widget.facilityId);
        final canCreateSession =
            AccessScope.of(context).canCreate(AuthResource.sessions);

        if (_loading) {
          return AppShell(
            title: facility.name,
            subtitle: 'Assessment Sessions',
            body: const LoadingView(message: 'Loading sessions…'),
          );
        }

        return AppShell(
          title: facility.name,
          subtitle: 'Assessment Sessions',
          actions: [
            if (AccessScope.of(context).canRead(AuthResource.patients))
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => PatientListScreen(
                        repository: widget.repository,
                        facilityId: widget.facilityId,
                        facilityName: facility.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people_outline),
                tooltip: 'All patients',
              ),
          ],
          body: sessions.isEmpty
              ? _EmptySessions(
                  onCreate:
                      canCreateSession ? () => _createSession(context) : null,
                )
              : PageContent(
                  header: PageBanner(
                    title: facility.name,
                    subtitle: facility.address,
                    stats: [
                      StatBadge(
                        label: 'Sessions',
                        value: '${sessions.length}',
                      ),
                      StatBadge(
                        label: 'Patients',
                        value: '${facility.displayPatientCount}',
                      ),
                    ],
                  ),
                  child: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = sessions[index];
                        final patientCount = session.assessmentsCount ??
                            widget.repository.getSessionPatientCount(
                              widget.facilityId,
                              session.id,
                            );
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sectionGap,
                          ),
                          child: _SessionCard(
                            session: session,
                            patientCount: patientCount,
                            isLatest: index == 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (context) => SessionDetailScreen(
                                    repository: widget.repository,
                                    facilityId: widget.facilityId,
                                    sessionId: session.id,
                                    facilityName: facility.name,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: sessions.length,
                    ),
                  ),
                ),
          floatingActionButton: canCreateSession
              ? FloatingActionButton.extended(
                  onPressed: () => _createSession(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Session'),
                )
              : null,
        );
      },
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.session,
    required this.patientCount,
    required this.isLatest,
    required this.onTap,
  });

  final AssessmentSession session;
  final int patientCount;
  final bool isLatest;
  final VoidCallback onTap;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
            width: widget.isLatest ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: _hovered ? 0.1 : 0.04),
              blurRadius: _hovered ? 16 : 8,
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
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_outlined,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              formatDate(widget.session.sessionDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            if (widget.isLatest) ...[
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
                          widget.patientCount == 0
                              ? 'No patients assessed yet'
                              : '${widget.patientCount} patient${widget.patientCount == 1 ? '' : 's'} completed',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Open session',
                        style: TextStyle(
                          color: _hovered ? AppColors.accent : AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
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

class _EmptySessions extends StatelessWidget {
  const _EmptySessions({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              onCreate == null ? 'No sessions available' : 'No sessions yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              onCreate == null
                  ? 'You do not have permission to create sessions for this facility.'
                  : 'Create a session for each visit date to this LTC facility.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onCreate != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create First Session'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
