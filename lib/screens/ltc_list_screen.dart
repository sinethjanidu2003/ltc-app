import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../models/ltc_facility.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/loading_view.dart';
import 'patient_form_screen.dart';
import 'session_list_screen.dart';
import '../features/users/screens/users_list_screen.dart';
import '../widgets/app_drawer.dart';

class LtcListScreen extends StatefulWidget {
  const LtcListScreen({super.key, required this.repository});

  final LtcRepository repository;

  @override
  State<LtcListScreen> createState() => _LtcListScreenState();
}

class _LtcListScreenState extends State<LtcListScreen> {
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.loadFacilities();
    });
  }

  Future<void> _showAddLtcDialog() async {
    final result = await showDialog<AddLtcResult>(
      context: context,
      builder: (context) => const _AddLtcDialog(),
    );

    if (result != null) {
      final facility = await widget.repository.addFacility(
        name: result.name,
        address: result.address,
      );
      if (!mounted) return;
      if (facility == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.repository.error ?? 'Could not create facility',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showAddPatient() async {
    if (widget.repository.facilities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add an LTC facility first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.push<PatientFormResult>(
      context,
      MaterialPageRoute(
        builder: (context) => PatientFormScreen(
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _reloadFromDatabase() async {
    if (!widget.repository.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connect to the internet to reload from the database.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final pending = widget.repository.pendingSyncCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reload from database'),
        content: Text(
          pending > 0
              ? 'This will sync $pending pending change(s), then discard the local cache and download all facilities, patients, sessions, and assessments from the server.'
              : 'This will discard the local cache and download all facilities, patients, sessions, and assessments from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reloading = true);
    final ok = await widget.repository.reloadFromDatabase();
    if (!mounted) return;
    setState(() => _reloading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Loaded latest data from the database.'
              : (widget.repository.error ??
                  'Could not reload from the database.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AccessScope.of(context);
    final canCreateFacility = auth.canCreate(AuthResource.facilities);
    final canCreatePatient = auth.canCreate(AuthResource.patients);
    final facilities = widget.repository.facilities;
    final totalPatients = facilities.fold<int>(
      0,
      (sum, f) => sum + f.displayPatientCount,
    );
    final loading =
        _reloading || (widget.repository.isLoading && facilities.isEmpty);

    return AppShell(
      title: 'LTC Spasticity Assessment',
      subtitle: auth.user?.role.isNotEmpty == true
          ? 'Signed in as ${auth.user!.name} · ${auth.user!.role}'
          : 'Long-Term Care Management',
      drawer: AppDrawer(
        current: AppDrawerDestination.facilities,
        onFacilities: () {},
        onUsers: auth.canRead(AuthResource.users)
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        UsersListScreen(repository: widget.repository),
                  ),
                );
              }
            : null,
      ),
      actions: [
        IconButton(
          onPressed: _reloading
              ? null
              : () => widget.repository.loadFacilities(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
        IconButton(
          onPressed: _reloading ? null : _reloadFromDatabase,
          icon: const Icon(Icons.cloud_download_outlined),
          tooltip: 'Reload from database',
        ),
        if (canCreatePatient)
          IconButton(
            onPressed: _reloading ? null : _showAddPatient,
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add patient',
          ),
        const SizedBox(width: 8),
      ],
      body: Column(
        children: [
          if (!kIsWeb &&
              (!widget.repository.isOnline ||
                  widget.repository.pendingSyncCount > 0))
            Material(
              color: widget.repository.isOnline
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : const Color(0xFFFEF3C7),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      widget.repository.isOnline
                          ? Icons.cloud_sync_outlined
                          : Icons.cloud_off_outlined,
                      size: 18,
                      color: widget.repository.isOnline
                          ? AppColors.accent
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        !widget.repository.isOnline
                            ? 'Offline — changes are saved on this device'
                            : widget.repository.isSyncing
                                ? (widget.repository.syncMessage ??
                                    'Syncing…')
                                : '${widget.repository.pendingSyncCount} change(s) waiting to sync',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.repository.isOnline
                              ? AppColors.accent
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    if (widget.repository.isOnline &&
                        widget.repository.pendingSyncCount > 0)
                      TextButton(
                        onPressed: widget.repository.isSyncing
                            ? null
                            : () => widget.repository.syncPending(),
                        child: const Text('Sync now'),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: loading
                ? LoadingView(
                    message: _reloading
                        ? (widget.repository.syncMessage ??
                            'Reloading from the database…')
                        : 'Loading facilities…',
                  )
                : facilities.isEmpty
                    ? _EmptyState(
                        onAdd: canCreateFacility ? _showAddLtcDialog : null,
                      )
                    : PageContent(
                        header: PageBanner(
                          title: 'Facilities',
                          subtitle:
                              'Select a long-term care facility to manage assessment sessions',
                          stats: [
                            StatBadge(
                              label: 'Facilities',
                              value: '${facilities.length}',
                            ),
                            StatBadge(
                              label: 'Patients',
                              value: '$totalPatients',
                            ),
                          ],
                        ),
                        child: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final crossAxisCount = width > 1200
                                ? 3
                                : width > 700
                                    ? 2
                                    : 1;

                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: AppSpacing.sectionGap,
                                crossAxisSpacing: AppSpacing.sectionGap,
                                mainAxisExtent:
                                    crossAxisCount == 1 ? 156 : 192,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final facility = facilities[index];
                                  return _LtcCard(
                                    facility: facility,
                                    onTap: () => _openFacility(facility),
                                  );
                                },
                                childCount: facilities.length,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: canCreateFacility
          ? FloatingActionButton.extended(
              onPressed: _reloading ? null : _showAddLtcDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add LTC'),
            )
          : null,
    );
  }

  void _openFacility(LtcFacility facility) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SessionListScreen(
          repository: widget.repository,
          facilityId: facility.id,
        ),
      ),
    );
  }
}

class _LtcCard extends StatefulWidget {
  const _LtcCard({required this.facility, required this.onTap});

  final LtcFacility facility;
  final VoidCallback onTap;

  @override
  State<_LtcCard> createState() => _LtcCardState();
}

class _LtcCardState extends State<_LtcCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sessionCount = widget.facility.displaySessionCount;

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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_hospital_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$sessionCount sessions',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.facility.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 16,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.facility.address,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'View sessions',
                              style: TextStyle(
                                color: _hovered
                                    ? AppColors.accent
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color:
                                  _hovered ? AppColors.accent : AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class AddLtcResult {
  const AddLtcResult({required this.name, required this.address});

  final String name;
  final String address;
}

class _AddLtcDialog extends StatefulWidget {
  const _AddLtcDialog();

  @override
  State<_AddLtcDialog> createState() => _AddLtcDialogState();
}

class _AddLtcDialogState extends State<_AddLtcDialog> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      AddLtcResult(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add LTC Facility'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Facility Name',
                  hintText: 'e.g. Sunrise Manor LTC',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'Street, City, Province',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Address is required'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add Facility'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              onAdd == null
                  ? 'No facilities available'
                  : 'No facilities yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              onAdd == null
                  ? 'Your account does not currently have access to any LTC facilities.'
                  : 'Add your first long-term care facility to begin managing spasticity assessments.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add LTC Facility'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
