import 'package:flutter/material.dart';

import '../data/ltc_repository.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../utils/patient_search.dart';
import 'patient_search_field.dart';
import 'section_card.dart';

typedef PatientPickerAction = void Function(Patient patient);

class PatientPickerSheet extends StatefulWidget {
  const PatientPickerSheet({
    super.key,
    required this.repository,
    required this.facilityId,
    required this.sessionId,
    required this.sessionDate,
    required this.onOpenAssessment,
    required this.onCreatePatient,
  });

  final LtcRepository repository;
  final String facilityId;
  final String sessionId;
  final DateTime sessionDate;
  final PatientPickerAction onOpenAssessment;
  final VoidCallback onCreatePatient;

  @override
  State<PatientPickerSheet> createState() => _PatientPickerSheetState();
}

class _PatientPickerSheetState extends State<PatientPickerSheet> {
  final _searchController = TextEditingController();
  final _selectedIds = <String>{};
  String _searchQuery = '';
  bool _enrolling = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Patient> _availablePatients() {
    return widget.repository.getPatientsNotInSession(
      widget.facilityId,
      widget.sessionId,
    );
  }

  List<Patient> _filteredPatients(List<Patient> patients) {
    return filterPatients(patients, _searchQuery);
  }

  bool get _allFilteredSelected {
    final filtered = _filteredPatients(_availablePatients());
    return filtered.isNotEmpty &&
        filtered.every((patient) => _selectedIds.contains(patient.id));
  }

  bool? get _selectAllValue {
    final filtered = _filteredPatients(_availablePatients());
    if (filtered.isEmpty) return false;
    final selectedCount =
        filtered.where((patient) => _selectedIds.contains(patient.id)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == filtered.length) return true;
    return null;
  }

  void _toggleSelectAll() {
    final filtered = _filteredPatients(_availablePatients());
    setState(() {
      if (_allFilteredSelected) {
        for (final patient in filtered) {
          _selectedIds.remove(patient.id);
        }
      } else {
        for (final patient in filtered) {
          _selectedIds.add(patient.id);
        }
      }
    });
  }

  void _togglePatient(String patientId) {
    setState(() {
      if (_selectedIds.contains(patientId)) {
        _selectedIds.remove(patientId);
      } else {
        _selectedIds.add(patientId);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selectedIds.isEmpty || _enrolling) return;

    final selectedPatients = _availablePatients()
        .where((patient) => _selectedIds.contains(patient.id))
        .toList();

    setState(() => _enrolling = true);
    final ok = await widget.repository.enrollPatientsInSession(
      facilityId: widget.facilityId,
      sessionId: widget.sessionId,
      patientIds: selectedPatients.map((patient) => patient.id).toList(),
      sessionDate: widget.sessionDate,
    );

    if (!mounted) return;
    setState(() => _enrolling = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.repository.error ?? 'Could not add patients'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context);

    final count = selectedPatients.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? '${selectedPatients.first.name} added to session'
              : '$count patients added to session',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final available = _availablePatients();
        final filtered = _filteredPatients(available);

        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    const Text(
                      'Add Patients to Session',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Search, select one or many, then add to this session',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PatientSearchField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCreatePatient();
                    },
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Create New Patient'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (available.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: CheckboxListTile(
                    value: _selectAllValue,
                    tristate: true,
                    onChanged: filtered.isEmpty ? null : (_) => _toggleSelectAll(),
                    title: Text(
                      _searchQuery.trim().isEmpty
                          ? 'Select all patients'
                          : 'Select all search results (${filtered.length})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: _selectedIds.isEmpty
                        ? null
                        : Text('${_selectedIds.length} selected'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: available.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'All patients at this facility are already in this session.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No patients match your search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final patient = filtered[index];
                              final selected = _selectedIds.contains(patient.id);
                              final hasHistory = patient.assessments.isNotEmpty;

                              return CheckboxListTile(
                                value: selected,
                                onChanged: (_) => _togglePatient(patient.id),
                                secondary: CircleAvatar(
                                  backgroundColor:
                                      AppColors.accent.withValues(alpha: 0.12),
                                  child: Text(
                                    patientInitials(patient.name),
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  patient.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  hasHistory
                                      ? 'OHIP ${patient.ohipNumber} · ${patient.visitCount} previous visits'
                                      : 'OHIP ${patient.ohipNumber}',
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                              );
                            },
                          ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedIds.isEmpty
                            ? 'Select patients to add'
                            : '${_selectedIds.length} patient${_selectedIds.length == 1 ? '' : 's'} selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _selectedIds.isEmpty || _enrolling
                          ? null
                          : _addSelected,
                      icon: _enrolling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.group_add_outlined),
                      label: Text(
                        _enrolling
                            ? 'Adding…'
                            : _selectedIds.length <= 1
                                ? 'Add Patient'
                                : 'Add ${_selectedIds.length} Patients',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void showPatientPickerSheet({
  required BuildContext context,
  required LtcRepository repository,
  required String facilityId,
  required String sessionId,
  required DateTime sessionDate,
  required PatientPickerAction onOpenAssessment,
  required VoidCallback onCreatePatient,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: PatientPickerSheet(
          repository: repository,
          facilityId: facilityId,
          sessionId: sessionId,
          sessionDate: sessionDate,
          onOpenAssessment: onOpenAssessment,
          onCreatePatient: onCreatePatient,
        ),
      );
    },
  );
}
