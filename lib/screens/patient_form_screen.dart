import 'package:flutter/material.dart';

import '../core/network/patients_api.dart';
import '../data/ltc_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/section_card.dart';

class PatientFormResult {
  const PatientFormResult({
    required this.facilityId,
    required this.patientId,
  });

  final String facilityId;
  final String patientId;
}

class PatientFormScreen extends StatefulWidget {
  const PatientFormScreen({
    super.key,
    required this.repository,
    this.defaultFacilityId,
    this.title = 'Add Patient',
  });

  final LtcRepository repository;
  final String? defaultFacilityId;
  final String title;

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late String? _selectedFacilityId;
  List<PatientProfile> _results = const [];
  PatientProfile? _selected;
  bool _searching = false;
  bool _saving = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    final facilities = widget.repository.facilities;
    _selectedFacilityId = widget.defaultFacilityId ??
        (facilities.length == 1 ? facilities.first.id : null);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _searchError = null;
      _selected = null;
    });

    try {
      final results = await widget.repository.searchPatients(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) {
          _searchError = 'No patients found';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = const [];
        _searchError = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final facilityId = _selectedFacilityId;
    final profile = _selected;
    if (facilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an LTC facility'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search and select a patient'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final patient = await widget.repository.addPatient(
      facilityId: facilityId,
      profile: profile,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.repository.error ?? 'Could not add patient'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final facility = widget.repository.getById(facilityId)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${patient.name} added to ${facility.name}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pop(
      context,
      PatientFormResult(facilityId: facilityId, patientId: patient.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilities = widget.repository.facilities;

    return AppShell(
      title: widget.title,
      subtitle: 'Search NeoClinic and link to an LTC facility',
      actions: [
        TextButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.check, color: Colors.white),
          label: const Text(
            'Save',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
      ],
      body: facilities.isEmpty
          ? const Center(
              child: Text(
                'Add an LTC facility before creating patients.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionCard(
                      title: 'Find Patient',
                      icon: Icons.search_outlined,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _searchController,
                                  textInputAction: TextInputAction.search,
                                  onFieldSubmitted: (_) => _search(),
                                  decoration: const InputDecoration(
                                    labelText: 'Search patients',
                                    hintText: 'Name, phone, or email',
                                    prefixIcon: Icon(Icons.person_search_outlined),
                                  ),
                                  validator: (_) => _selected == null
                                      ? 'Select a patient from search results'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _searching ? null : _search,
                                  child: _searching
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Search'),
                                ),
                              ),
                            ],
                          ),
                          if (_searchError != null) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _searchError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                          if (_results.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ..._results.map((profile) {
                              final selected = _selected?.id == profile.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.06)
                                      : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () =>
                                        setState(() => _selected = profile),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            selected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.textSecondary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  profile.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  [
                                                    if (profile.dateOfBirth !=
                                                        null)
                                                      formatDate(
                                                        profile.dateOfBirth!,
                                                      ),
                                                    if (profile
                                                            .healthCardLast4 !=
                                                        null)
                                                      '••••${profile.healthCardLast4}',
                                                    'ID ${profile.id}',
                                                  ].join(' · '),
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                          if (_selected != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Selected: ${_selected!.fullName}',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    SectionCard(
                      title: 'LTC Assignment',
                      subtitle: 'Which facility is this patient at?',
                      icon: Icons.local_hospital_outlined,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedFacilityId),
                        initialValue: _selectedFacilityId,
                        decoration: const InputDecoration(
                          labelText: 'LTC Facility',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: facilities
                            .map(
                              (facility) => DropdownMenuItem(
                                value: facility.id,
                                child: Text(facility.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedFacilityId = value),
                        validator: (value) =>
                            value == null ? 'Select an LTC facility' : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.person_add_outlined),
                        label: Text(_saving ? 'Saving…' : 'Add Patient'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
