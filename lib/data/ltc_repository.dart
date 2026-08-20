import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/network/patients_api.dart';
import '../core/offline/connectivity_service.dart';
import '../core/offline/offline_cache.dart';
import '../core/offline/sync_queue.dart';
import '../data/muscle_constants.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_models.dart';
import '../models/assessment_session.dart';
import '../models/enums.dart';
import '../models/ltc_facility.dart';
import '../models/muscle.dart';
import '../models/patient.dart';
import '../models/spasticity_assessment.dart';
import '../models/spasticity_pattern_catalog.dart';

/// Loads and mutates LTC data from the live API with device-local offline support.
class LtcRepository extends ChangeNotifier {
  LtcRepository({
    required ApiClient apiClient,
    AuthRepository? auth,
    PatientsApi? patientsApi,
    ConnectivityService? connectivity,
    OfflineCache? cache,
    SyncQueue? syncQueue,
  })  : _api = apiClient,
        _auth = auth,
        _patientsApi = patientsApi ?? PatientsApi(),
        _ownsPatientsApi = patientsApi == null,
        _connectivity = connectivity ?? ConnectivityService(),
        _ownsConnectivity = connectivity == null,
        _cache = cache ?? OfflineCache(),
        _queue = syncQueue ?? SyncQueue();

  final ApiClient _api;
  final AuthRepository? _auth;
  final PatientsApi _patientsApi;
  final bool _ownsPatientsApi;
  final ConnectivityService _connectivity;
  final bool _ownsConnectivity;
  final OfflineCache _cache;
  final SyncQueue _queue;

  final List<LtcFacility> _facilities = [];
  final Map<String, List<Muscle>> _musclesByFacility = {};
  final Map<String, Set<String>> _sessionPatientIds = {};
  SpasticityPatternCatalog _limbPatternCatalog =
      const SpasticityPatternCatalog(regions: {});
  SpasticityPatternCatalog _neckJawPatternCatalog =
      SpasticityPatternCatalog.neckJawFallback;
  bool _neckJawCatalogLoaded = false;
  bool _loading = false;
  bool _syncing = false;
  bool _ready = false;
  String? _error;
  String? _syncMessage;

  List<LtcFacility> get facilities {
    final user = _auth?.user;
    if (user == null) return List.unmodifiable(_facilities);
    if (!user.canRead(AuthResource.facilities)) return const [];
    if (user.accessAllFacilities) return List.unmodifiable(_facilities);
    final allowed = user.ltcFacilityIds.toSet();
    return List.unmodifiable(
      _facilities.where((f) => allowed.contains(f.id)),
    );
  }

  /// Full facility list for admin user-assignment (ignores facility ACL filter).
  List<LtcFacility> get managedFacilities {
    if (_auth?.canRead(AuthResource.users) == true) {
      return List.unmodifiable(_facilities);
    }
    return facilities;
  }

  bool get isLoading => _loading;
  bool get isReady => _ready;
  bool get isOnline => _connectivity.isOnline;
  bool get isSyncing => _syncing;
  int get pendingSyncCount => _queue.pendingCount;
  String? get error => _error;
  String? get syncMessage => _syncMessage;

  bool _ensurePermission(
    AuthResource resource,
    AuthAction action, {
    String? facilityId,
  }) {
    final user = _auth?.user;
    if (user == null) return true;

    if (facilityId != null && !user.canAccessFacility(facilityId)) {
      _error = 'You do not have access to this facility.';
      notifyListeners();
      return false;
    }

    if (!user.can(resource, action)) {
      _error = 'You do not have permission to do that.';
      notifyListeners();
      return false;
    }
    return true;
  }

  List<Muscle> musclesFor(String facilityId) =>
      List.unmodifiable(_musclesByFacility[facilityId] ?? const []);

  List<String> muscleNamesFor(String facilityId) {
    final muscles = _musclesByFacility[facilityId];
    if (muscles == null || muscles.isEmpty) return kAvailableMuscles;
    return muscles.map((m) => m.name).toList();
  }

  Map<String, String> muscleIdsByNameFor(String facilityId) {
    final muscles = _musclesByFacility[facilityId] ?? const [];
    return {for (final muscle in muscles) muscle.name: muscle.id};
  }

  SpasticityPatternCatalog get patternCatalog =>
      _limbPatternCatalog.mergedWith(_neckJawPatternCatalog);

  Future<void> loadSpasticityPatterns({bool force = false}) async {
    if (!_ensurePermission(AuthResource.assessments, AuthAction.read)) {
      return;
    }

    await Future.wait([
      _loadLimbPatternCatalog(force: force),
      _loadNeckJawPatternCatalog(force: force),
    ]);
  }

  Future<void> _loadLimbPatternCatalog({required bool force}) async {
    if (!force && _limbPatternCatalog.hasLimbRegions) return;

    if (!_connectivity.isOnline) {
      final cached = await _cache.loadPatternCatalog();
      if (cached != null && !cached.isEmpty) {
        _limbPatternCatalog = cached;
        notifyListeners();
      }
      return;
    }

    try {
      final json = await _api.get(ApiEndpoints.spasticityPatterns);
      final catalog = SpasticityPatternCatalog.fromJson(json);
      if (!catalog.isEmpty) {
        _limbPatternCatalog = catalog;
        await _cache.savePatternCatalog(catalog);
        notifyListeners();
      }
    } on ApiException catch (error) {
      final cached = await _cache.loadPatternCatalog();
      if (cached != null && !cached.isEmpty) {
        _limbPatternCatalog = cached;
        notifyListeners();
      } else {
        _error = error.message;
        notifyListeners();
      }
    }
  }

  Future<void> _loadNeckJawPatternCatalog({required bool force}) async {
    if (!force && _neckJawCatalogLoaded) return;

    if (!_connectivity.isOnline) {
      final cached = await _cache.loadNeckJawPatternCatalog();
      if (cached != null && !cached.isEmpty) {
        _neckJawPatternCatalog = cached;
        notifyListeners();
      }
      return;
    }

    try {
      final json = await _api.get(ApiEndpoints.spasticityPatternsNeckJaw);
      final catalog = SpasticityPatternCatalog.fromJson(json);
      if (!catalog.isEmpty) {
        _neckJawPatternCatalog = catalog;
        await _cache.saveNeckJawPatternCatalog(catalog);
      }
      _neckJawCatalogLoaded = true;
      notifyListeners();
    } on ApiException {
      final cached = await _cache.loadNeckJawPatternCatalog();
      if (cached != null && !cached.isEmpty) {
        _neckJawPatternCatalog = cached;
      }
      _neckJawCatalogLoaded = true;
      notifyListeners();
    }
  }

  bool _isPersistedAssessmentId(String id) =>
      id.isNotEmpty && !id.startsWith('local-') && !id.startsWith('a-');

  Future<void> loadNeckJawPatterns({
    required String facilityId,
    required String sessionId,
    required String assessmentId,
  }) async {
    if (!_isPersistedAssessmentId(assessmentId)) return;
    if (!_ensurePermission(
      AuthResource.assessments,
      AuthAction.read,
      facilityId: facilityId,
    )) {
      return;
    }

    if (!_connectivity.isOnline) return;

    try {
      final json = await _api.get(
        ApiEndpoints.sessionAssessmentNeckJawPatterns(
          facilityId,
          sessionId,
          assessmentId,
        ),
      );
      final neckJaw = SpasticityPatterns.fromJson(json);
      _mergeNeckJawIntoAssessment(
        facilityId: facilityId,
        assessmentId: assessmentId,
        neck: neckJaw.neck,
        jaw: neckJaw.jaw,
      );
      notifyListeners();
    } on ApiException {
      // Limb assessment still loads; neck/jaw stay at cached values.
    }
  }

  Future<void> _saveNeckJawPatterns({
    required String facilityId,
    required String sessionId,
    required String assessmentId,
    required SpasticityPatterns patterns,
  }) async {
    if (!_isPersistedAssessmentId(assessmentId) || !_connectivity.isOnline) {
      return;
    }

    final json = await _api.put(
      ApiEndpoints.sessionAssessmentNeckJawPatterns(
        facilityId,
        sessionId,
        assessmentId,
      ),
      body: patterns.toNeckJawApiJson(),
    );
    final saved = SpasticityPatterns.fromJson(json);
    _mergeNeckJawIntoAssessment(
      facilityId: facilityId,
      assessmentId: assessmentId,
      neck: saved.neck,
      jaw: saved.jaw,
    );
  }

  void _mergeNeckJawIntoAssessment({
    required String facilityId,
    required String assessmentId,
    required List<String> neck,
    required List<String> jaw,
  }) {
    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return;
    final facility = _facilities[facilityIndex];

    var changed = false;
    final patients = facility.patients.map((patient) {
      final index = patient.assessments.indexWhere((a) => a.id == assessmentId);
      if (index == -1) return patient;
      changed = true;
      final assessments = List<SpasticityAssessment>.from(patient.assessments);
      final current = assessments[index];
      assessments[index] = current.copyWith(
        patterns: current.patterns.copyWith(neck: neck, jaw: jaw),
      );
      return patient.copyWith(assessments: assessments);
    }).toList();

    if (!changed) return;
    _facilities[facilityIndex] = facility.copyWith(patients: patients);
  }

  String _sessionKey(String facilityId, String sessionId) =>
      '$facilityId:$sessionId';

  String _localId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  bool _canEnrollInSession(String facilityId) {
    final user = _auth?.user;
    if (user == null) return true;
    if (!user.canAccessFacility(facilityId)) {
      _error = 'You do not have access to this facility.';
      notifyListeners();
      return false;
    }
    // Enrolling updates the session roster and creates empty assessments.
    if (user.canUpdate(AuthResource.sessions) ||
        user.canCreate(AuthResource.sessions) ||
        user.canCreate(AuthResource.assessments)) {
      return true;
    }
    _error = 'You do not have permission to add patients to sessions.';
    notifyListeners();
    return false;
  }

  Future<void> bootstrapOffline() async {
    await _connectivity.start();
    await _queue.load();
    await _restoreFromCache();
    final cachedPatterns = await _cache.loadPatternCatalog();
    if (cachedPatterns != null && !cachedPatterns.isEmpty) {
      _limbPatternCatalog = cachedPatterns;
    }
    final cachedNeckJaw = await _cache.loadNeckJawPatternCatalog();
    if (cachedNeckJaw != null && !cachedNeckJaw.isEmpty) {
      _neckJawPatternCatalog = cachedNeckJaw;
    }
    _ready = true;
    notifyListeners();

    _connectivity.addListener(_onConnectivityChanged);
    if (_connectivity.isOnline) {
      await syncPending();
      await loadSpasticityPatterns();
    }
  }

  void _onConnectivityChanged() {
    notifyListeners();
    if (_connectivity.isOnline) {
      syncPending();
    }
  }

  LtcFacility? getById(String id) {
    final user = _auth?.user;
    if (user != null) {
      if (!user.canRead(AuthResource.facilities) ||
          !user.canAccessFacility(id)) {
        return null;
      }
    }
    try {
      return _facilities.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  AssessmentSession? getSession(String facilityId, String sessionId) {
    final facility = getById(facilityId);
    if (facility == null) return null;
    try {
      return facility.sessions.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  List<AssessmentSession> getSortedSessions(String facilityId) {
    final facility = getById(facilityId);
    if (facility == null) return [];
    final sessions = List<AssessmentSession>.from(facility.sessions)
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return sessions;
  }

  Patient? getPatient(String facilityId, String patientId) {
    final facility = getById(facilityId);
    if (facility == null) return null;
    try {
      return facility.patients.firstWhere((p) => p.id == patientId);
    } catch (_) {
      return null;
    }
  }

  SpasticityAssessment? getAssessment(
    String facilityId,
    String patientId,
    String assessmentId,
  ) {
    final patient = getPatient(facilityId, patientId);
    if (patient == null) return null;
    try {
      return patient.assessments.firstWhere((a) => a.id == assessmentId);
    } catch (_) {
      return null;
    }
  }

  SpasticityAssessment? getPatientAssessmentInSession(
    String facilityId,
    String patientId,
    String sessionId,
  ) {
    final patient = getPatient(facilityId, patientId);
    if (patient == null) return null;
    try {
      return patient.assessments.firstWhere((a) => a.sessionId == sessionId);
    } catch (_) {
      return null;
    }
  }

  List<Patient> getPatientsInSession(String facilityId, String sessionId) {
    final facility = getById(facilityId);
    if (facility == null) return [];

    final roster = _sessionPatientIds[_sessionKey(facilityId, sessionId)];
    if (roster != null) {
      return facility.patients
          .where((p) => roster.contains(p.patientId) || roster.contains(p.id))
          .toList();
    }

    return facility.patients
        .where((p) => p.assessments.any((a) => a.sessionId == sessionId))
        .toList();
  }

  List<Patient> getPatientsNotInSession(String facilityId, String sessionId) {
    final facility = getById(facilityId);
    if (facility == null) return [];
    final inSession =
        getPatientsInSession(facilityId, sessionId).map((p) => p.id).toSet();
    return facility.patients
        .where((p) => !inSession.contains(p.id))
        .toList();
  }

  int getSessionPatientCount(String facilityId, String sessionId) {
    return getPatientsInSession(facilityId, sessionId).length;
  }

  Future<void> _persistCache() async {
    await _cache.saveSnapshot(
      facilities: _facilities,
      musclesByFacility: _musclesByFacility,
      sessionPatientIds: _sessionPatientIds,
    );
  }

  Future<bool> _restoreFromCache() async {
    final snapshot = await _cache.loadSnapshot();
    if (snapshot == null) return false;
    _facilities
      ..clear()
      ..addAll(snapshot.facilities);
    _musclesByFacility
      ..clear()
      ..addAll(snapshot.musclesByFacility);
    _sessionPatientIds
      ..clear()
      ..addAll(snapshot.sessionPatientIds);
    notifyListeners();
    return true;
  }

  bool _isNetworkError(Object error) {
    if (error is ApiException) {
      return error.statusCode == null ||
          error.message.contains('Unable to reach');
    }
    return true;
  }

  Future<void> loadFacilities() async {
    _loading = true;
    _error = null;
    notifyListeners();

    if (!_ensurePermission(AuthResource.facilities, AuthAction.read)) {
      _facilities.clear();
      _loading = false;
      notifyListeners();
      return;
    }

    if (!_connectivity.isOnline) {
      final ok = await _restoreFromCache();
      if (!ok) _error = 'You are offline and no cached facilities were found.';
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      await _pullFacilitiesFromApi(keepLocalDetails: true);
      await _persistCache();
    } catch (error) {
      final restored = await _restoreFromCache();
      _error = restored
          ? 'Showing cached facilities (offline/unavailable).'
          : (_isNetworkError(error)
              ? 'Unable to load facilities.'
              : error.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Discards the device cache and downloads facilities, patients, sessions,
  /// and assessments from the server.
  Future<bool> reloadFromDatabase() async {
    if (!_ensurePermission(AuthResource.facilities, AuthAction.read)) {
      return false;
    }

    if (!_connectivity.isOnline) {
      _error = 'Connect to the internet to reload from the database.';
      notifyListeners();
      return false;
    }

    if (_loading || _syncing) return false;

    _loading = true;
    _error = null;
    _syncMessage = 'Reloading from the database…';
    notifyListeners();

    try {
      if (_queue.hasPending) {
        await syncPending();
        if (_queue.hasPending) {
          _error = 'Sync unfinished changes before reloading from the database.';
          return false;
        }
      }

      await _cache.clear();
      _patientsApi.clearCache();
      _facilities.clear();
      _musclesByFacility.clear();
      _sessionPatientIds.clear();
      _limbPatternCatalog = const SpasticityPatternCatalog(regions: {});
      _neckJawPatternCatalog = SpasticityPatternCatalog.neckJawFallback;
      _neckJawCatalogLoaded = false;
      notifyListeners();

      await _pullFacilitiesFromApi(keepLocalDetails: false);
      await loadSpasticityPatterns(force: true);

      for (final facility in List<LtcFacility>.from(facilities)) {
        _syncMessage = 'Loading ${facility.name}…';
        notifyListeners();
        await _hydrateFacilityFromServer(facility.id);
      }

      await _persistCache();
      return true;
    } catch (error) {
      _error = _isNetworkError(error)
          ? 'Unable to reload from the database.'
          : error.toString();
      return false;
    } finally {
      _loading = false;
      _syncMessage = null;
      notifyListeners();
    }
  }

  Future<void> _pullFacilitiesFromApi({required bool keepLocalDetails}) async {
    final list = await _api.getList(ApiEndpoints.facilities);
    final remote = list
        .whereType<Map>()
        .map((item) => LtcFacility.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final previous = keepLocalDetails
        ? {for (final facility in _facilities) facility.id: facility}
        : const <String, LtcFacility>{};

    _facilities
      ..clear()
      ..addAll(
        remote.map((facility) {
          final prior = previous[facility.id];
          if (prior == null) return facility;
          return facility.copyWith(
            patients: prior.patients,
            sessions: prior.sessions.isNotEmpty
                ? prior.sessions
                : facility.sessions,
          );
        }),
      );
  }

  Future<void> _hydrateFacilityFromServer(String facilityId) async {
    await Future.wait([
      loadFacilityPatients(facilityId),
      loadFacilitySessions(facilityId),
      loadFacilityMuscles(facilityId),
    ]);

    final facility = getById(facilityId);
    if (facility == null) return;

    for (final session in facility.sessions.where(
      (session) => !session.id.startsWith('local-'),
    )) {
      await _mergeSessionAssessments(facilityId, session.id);
      await _loadSessionRoster(facilityId, session.id);

      final updated = getById(facilityId);
      if (updated == null) continue;
      for (final patient in updated.patients) {
        for (final assessment in patient.assessments.where(
          (item) => item.sessionId == session.id,
        )) {
          await loadNeckJawPatterns(
            facilityId: facilityId,
            sessionId: session.id,
            assessmentId: assessment.id,
          );
        }
      }
    }
  }

  Future<LtcFacility?> addFacility({
    required String name,
    required String address,
  }) async {
    if (!_ensurePermission(AuthResource.facilities, AuthAction.create)) {
      return null;
    }

    if (!_connectivity.isOnline) {
      final facility = LtcFacility(
        id: _localId('ltc'),
        name: name.trim(),
        address: address.trim(),
        patients: const [],
        sessions: const [],
        patientsCount: 0,
        sessionsCount: 0,
      );
      _facilities.add(facility);
      await _queue.enqueue(
        SyncMutation(
          id: _localId('m'),
          type: SyncMutationType.createFacility,
          payload: {
            'local_id': facility.id,
            'name': facility.name,
            'location': facility.address,
          },
        ),
      );
      await _persistCache();
      notifyListeners();
      return facility;
    }

    try {
      final json = await _api.post(
        ApiEndpoints.facilities,
        body: {
          'name': name.trim(),
          'location': address.trim(),
        },
      );
      final facility = LtcFacility.fromJson(json).copyWith(
        patients: const [],
        sessions: const [],
        patientsCount: 0,
        sessionsCount: 0,
      );
      _facilities.add(facility);
      await _persistCache();
      notifyListeners();
      return facility;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadFacilityPatients(String facilityId) async {
    if (!_ensurePermission(
      AuthResource.patients,
      AuthAction.read,
      facilityId: facilityId,
    )) {
      return;
    }

    final index = _facilities.indexWhere((f) => f.id == facilityId);
    if (index == -1) return;

    if (!_connectivity.isOnline) {
      notifyListeners();
      return;
    }

    try {
      final list =
          await _api.getList(ApiEndpoints.facilityPatients(facilityId));
      var patients = list
          .whereType<Map>()
          .map(
            (item) =>
                Patient.fromFacilityLinkJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      final existingById = {
        for (final patient in _facilities[index].patients)
          patient.id: patient,
      };
      patients = patients.map((patient) {
        final prior = existingById[patient.id];
        if (prior == null) return patient;
        return patient.copyWith(
          name: prior.name,
          ohipNumber: prior.ohipNumber,
          dateOfBirth: prior.dateOfBirth,
          address: prior.address,
          assessments: prior.assessments,
        );
      }).toList();

      patients = await _enrichPatients(patients);
      final facility = _facilities[index];
      _facilities[index] = facility.copyWith(
        patients: patients,
        patientsCount: patients.length,
      );
      await _persistCache();
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  Future<List<PatientProfile>> searchPatients(String query) {
    if (!_connectivity.isOnline) {
      throw ApiException(
        message:
            'Patient search requires internet. Cached facility patients are still available offline.',
      );
    }
    return _patientsApi.find(query);
  }

  Future<Patient?> addPatient({
    required String facilityId,
    required PatientProfile profile,
  }) async {
    if (!_ensurePermission(
      AuthResource.patients,
      AuthAction.create,
      facilityId: facilityId,
    )) {
      return null;
    }

    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return null;

    final facility = _facilities[facilityIndex];
    if (facility.patients.any((p) => p.patientId == profile.id)) {
      _error = 'This patient is already linked to the facility.';
      notifyListeners();
      return null;
    }

    final linked = Patient(
      id: profile.id,
      patientId: profile.id,
      name: profile.fullName,
      ohipNumber: profile.ohipDisplay,
      dateOfBirth: profile.dateOfBirth ?? DateTime(1900, 1, 1),
      address: profile.address,
      assessments: const [],
    );

    if (!_connectivity.isOnline) {
      final updatedPatients = [...facility.patients, linked];
      _facilities[facilityIndex] = facility.copyWith(
        patients: updatedPatients,
        patientsCount: updatedPatients.length,
      );
      await _queue.enqueue(
        SyncMutation(
          id: _localId('m'),
          type: SyncMutationType.addPatient,
          payload: {
            'facility_id': facilityId,
            'patient_id': profile.id,
            'name': profile.fullName,
            'ohip_number': profile.ohipDisplay,
            'date_of_birth': profile.dateOfBirth?.toIso8601String(),
            'address': profile.address,
          },
        ),
      );
      await _persistCache();
      notifyListeners();
      return linked;
    }

    try {
      final json = await _api.post(
        ApiEndpoints.facilityPatients(facilityId),
        body: {'patient_id': profile.id},
      );

      final created = Patient.fromFacilityLinkJson(json).copyWith(
        name: profile.fullName,
        ohipNumber: profile.ohipDisplay,
        dateOfBirth: profile.dateOfBirth ?? DateTime(1900, 1, 1),
        address: profile.address,
      );

      final updatedPatients = [...facility.patients, created];
      _facilities[facilityIndex] = facility.copyWith(
        patients: updatedPatients,
        patientsCount: updatedPatients.length,
      );
      await _persistCache();
      notifyListeners();
      return created;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadFacilitySessions(String facilityId) async {
    if (!_ensurePermission(
      AuthResource.sessions,
      AuthAction.read,
      facilityId: facilityId,
    )) {
      return;
    }

    final index = _facilities.indexWhere((f) => f.id == facilityId);
    if (index == -1) return;
    if (!_connectivity.isOnline) {
      notifyListeners();
      return;
    }

    try {
      final list =
          await _api.getList(ApiEndpoints.facilitySessions(facilityId));
      final sessions = list
          .whereType<Map>()
          .map(
            (item) =>
                AssessmentSession.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

      // Preserve any unsynced local sessions.
      final existing = _facilities[index].sessions;
      final localOnly = existing
          .where((session) => session.id.startsWith('local-'))
          .toList();
      final merged = [...sessions];
      for (final local in localOnly) {
        if (!merged.any((s) => s.id == local.id)) {
          merged.add(local);
        }
      }

      final facility = _facilities[index];
      _facilities[index] = facility.copyWith(
        sessions: merged,
        sessionsCount: merged.length,
      );
      await _persistCache();
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  Future<void> loadFacilityMuscles(String facilityId) async {
    if (!_ensurePermission(
      AuthResource.muscles,
      AuthAction.read,
      facilityId: facilityId,
    )) {
      return;
    }

    if (!_connectivity.isOnline) {
      notifyListeners();
      return;
    }

    try {
      final list =
          await _api.getList(ApiEndpoints.facilityMuscles(facilityId));
      _musclesByFacility[facilityId] = list
          .whereType<Map>()
          .map((item) => Muscle.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      await _persistCache();
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  /// Creates (or reuses) a facility muscle by name. Used for custom Botox rows.
  Future<Muscle?> ensureFacilityMuscle({
    required String facilityId,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    final existing = musclesFor(facilityId).where(
      (m) => m.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;

    if (!_ensurePermission(
      AuthResource.muscles,
      AuthAction.create,
      facilityId: facilityId,
    )) {
      return null;
    }

    if (!_connectivity.isOnline) {
      _error = 'Creating a custom muscle requires an internet connection.';
      notifyListeners();
      return null;
    }

    try {
      final json = await _api.post(
        ApiEndpoints.facilityMuscles(facilityId),
        body: {
          'name': trimmed,
          'is_custom': true,
        },
      );
      final muscle = Muscle.fromJson(json);
      final list = List<Muscle>.from(_musclesByFacility[facilityId] ?? const []);
      list.add(muscle);
      _musclesByFacility[facilityId] = list;
      await _persistCache();
      notifyListeners();
      return muscle;
    } on ApiException catch (error) {
      // If it already exists on the server, refresh and look it up.
      await loadFacilityMuscles(facilityId);
      final refreshed = musclesFor(facilityId).where(
        (m) => m.name.toLowerCase() == trimmed.toLowerCase(),
      );
      if (refreshed.isNotEmpty) return refreshed.first;
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<AssessmentSession?> addSession({
    required String facilityId,
    required DateTime sessionDate,
  }) async {
    if (!_ensurePermission(
      AuthResource.sessions,
      AuthAction.create,
      facilityId: facilityId,
    )) {
      return null;
    }

    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return null;

    final date =
        '${sessionDate.year.toString().padLeft(4, '0')}-'
        '${sessionDate.month.toString().padLeft(2, '0')}-'
        '${sessionDate.day.toString().padLeft(2, '0')}';

    if (!_connectivity.isOnline) {
      final session = AssessmentSession(
        id: _localId('s'),
        sessionDate: sessionDate,
        assessmentsCount: 0,
      );
      final facility = _facilities[facilityIndex];
      final sessions = [...facility.sessions, session];
      _facilities[facilityIndex] = facility.copyWith(
        sessions: sessions,
        sessionsCount: sessions.length,
      );
      _sessionPatientIds[_sessionKey(facilityId, session.id)] = <String>{};
      await _queue.enqueue(
        SyncMutation(
          id: _localId('m'),
          type: SyncMutationType.createSession,
          payload: {
            'facility_id': facilityId,
            'local_id': session.id,
            'session_date': date,
          },
        ),
      );
      await _persistCache();
      notifyListeners();
      return session;
    }

    try {
      final json = await _api.post(
        ApiEndpoints.facilitySessions(facilityId),
        body: {'session_date': date},
      );
      final session = AssessmentSession.fromJson(json);
      final facility = _facilities[facilityIndex];
      final sessions = [...facility.sessions, session];
      _facilities[facilityIndex] = facility.copyWith(
        sessions: sessions,
        sessionsCount: sessions.length,
      );
      await _persistCache();
      notifyListeners();
      return session;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadSessionDetail({
    required String facilityId,
    required String sessionId,
  }) async {
    if (!_ensurePermission(
      AuthResource.sessions,
      AuthAction.read,
      facilityId: facilityId,
    )) {
      return;
    }

    if (!_connectivity.isOnline) {
      notifyListeners();
      return;
    }

    await Future.wait([
      loadFacilityPatients(facilityId),
      loadFacilityMuscles(facilityId),
      loadFacilitySessions(facilityId),
    ]);

    await _mergeSessionAssessments(facilityId, sessionId);
    await _loadSessionRoster(facilityId, sessionId);

    final facility = getById(facilityId);
    if (facility != null) {
      await Future.wait(
        facility.sessions
            .where((session) => session.id != sessionId)
            .where((session) => !session.id.startsWith('local-'))
            .map(
              (session) => _mergeSessionAssessments(facilityId, session.id),
            ),
      );
    }
    await _persistCache();
  }

  Future<void> _loadSessionRoster(String facilityId, String sessionId) async {
    try {
      final json = await _api.get(
        ApiEndpoints.sessionPatients(facilityId, sessionId),
      );
      final ids = json['patient_ids'];
      final set = <String>{};
      if (ids is List) {
        for (final id in ids) {
          set.add(id.toString());
        }
      }
      _sessionPatientIds[_sessionKey(facilityId, sessionId)] = set;
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  Future<void> _mergeSessionAssessments(
    String facilityId,
    String sessionId,
  ) async {
    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return;

    try {
      final list = await _api.getList(
        ApiEndpoints.sessionAssessments(facilityId, sessionId),
      );
      final assessments = list
          .whereType<Map>()
          .map(
            (item) => SpasticityAssessment.fromJson(
              Map<String, dynamic>.from(item),
              fallbackSessionId: sessionId,
            ),
          )
          .toList();

      final facility = _facilities[facilityIndex];
      var patients = List<Patient>.from(facility.patients);

      for (final assessment in assessments) {
        final patientIndex =
            patients.indexWhere((p) => p.id == assessment.patientId);
        if (patientIndex == -1) {
          patients.add(
            Patient(
              id: assessment.patientId,
              patientId: assessment.patientId,
              name: 'Patient ${assessment.patientId}',
              ohipNumber: '—',
              dateOfBirth: DateTime(1900, 1, 1),
              assessments: [assessment],
            ),
          );
          continue;
        }

        final patient = patients[patientIndex];
        final existing = patient.assessments.where((a) => a.id == assessment.id);
        final resolved = existing.isEmpty
            ? assessment
            : assessment.copyWith(
                patterns: assessment.patterns.copyWith(
                  neck: existing.first.patterns.neck,
                  jaw: existing.first.patterns.jaw,
                ),
              );
        final withoutThis = patient.assessments
            .where((a) => a.id != assessment.id)
            .toList();
        patients[patientIndex] = patient.copyWith(
          assessments: [...withoutThis, resolved],
        );
      }

      patients = await _enrichPatients(patients);
      _facilities[facilityIndex] = facility.copyWith(patients: patients);
      notifyListeners();
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
    }
  }

  /// Copies the patient roster from [sourceSessionId] into [targetSessionId].
  ///
  /// Loads the source roster from the API when needed, then enrolls any
  /// patients not already on the target session (creates empty assessments).
  Future<int> copyPatientsFromSession({
    required String facilityId,
    required String sourceSessionId,
    required String targetSessionId,
    required DateTime targetSessionDate,
  }) async {
    if (sourceSessionId == targetSessionId) {
      _error = 'Choose a different session to copy from.';
      notifyListeners();
      return 0;
    }

    if (!_canEnrollInSession(facilityId)) return 0;

    await _loadSessionRoster(facilityId, sourceSessionId);
    final sourcePatients =
        getPatientsInSession(facilityId, sourceSessionId);
    if (sourcePatients.isEmpty) {
      _error = 'That session has no patients to copy.';
      notifyListeners();
      return 0;
    }

    final alreadyInTarget = getPatientsInSession(facilityId, targetSessionId)
        .map((p) => p.patientId)
        .toSet();

    final toEnroll = sourcePatients
        .where((p) => !alreadyInTarget.contains(p.patientId))
        .map((p) => p.patientId)
        .toList();

    if (toEnroll.isEmpty) {
      _error = 'All patients from that session are already in this one.';
      notifyListeners();
      return 0;
    }

    final ok = await enrollPatientsInSession(
      facilityId: facilityId,
      sessionId: targetSessionId,
      patientIds: toEnroll,
      sessionDate: targetSessionDate,
    );
    if (!ok) return 0;

    await loadSessionDetail(
      facilityId: facilityId,
      sessionId: targetSessionId,
    );
    return toEnroll.length;
  }

  Future<bool> enrollPatientsInSession({
    required String facilityId,
    required String sessionId,
    required List<String> patientIds,
    required DateTime sessionDate,
  }) async {
    if (patientIds.isEmpty) return true;

    if (!_canEnrollInSession(facilityId)) {
      return false;
    }

    // Always enroll by NeoClinic/LTC patient_id (numeric), not UI aliases.
    final normalizedIds = patientIds
        .map((id) {
          final patient = getPatient(facilityId, id);
          return patient?.patientId ?? id;
        })
        .toList();

    if (!_connectivity.isOnline) {
      final key = _sessionKey(facilityId, sessionId);
      final roster = _sessionPatientIds.putIfAbsent(key, () => <String>{});
      roster.addAll(normalizedIds);

      for (final patientId in normalizedIds) {
        final existing =
            getPatientAssessmentInSession(facilityId, patientId, sessionId);
        if (existing != null) continue;
        final patient = getPatient(facilityId, patientId);
        final type = (patient?.assessments.isEmpty ?? true)
            ? AssessmentType.initial
            : AssessmentType.followUp;
        _upsertPatientAssessment(
          facilityId: facilityId,
          patientId: patientId,
          assessment: SpasticityAssessment(
            id: _localId('a'),
            sessionId: sessionId,
            patientId: patientId,
            assessmentDate: sessionDate,
            bodyParts: const [],
            side: SideAffected.right,
            assessmentType: type,
            patterns: const SpasticityPatterns(),
            goals: const TreatmentGoals(),
            botoxInjections: const [],
          ),
        );
      }

      await _queue.enqueue(
        SyncMutation(
          id: _localId('m'),
          type: SyncMutationType.enrollPatients,
          payload: {
            'facility_id': facilityId,
            'session_id': sessionId,
            'patient_ids': normalizedIds,
          },
        ),
      );
      await _persistCache();
      notifyListeners();
      return true;
    }

    try {
      final json = await _api.post(
        ApiEndpoints.sessionPatients(facilityId, sessionId),
        body: {'patient_ids': normalizedIds},
      );

      final ids = json['patient_ids'];
      final set = <String>{};
      if (ids is List) {
        for (final id in ids) {
          set.add(id.toString());
        }
      } else {
        set.addAll(normalizedIds);
      }
      _sessionPatientIds[_sessionKey(facilityId, sessionId)] = set;

      await _mergeSessionAssessments(facilityId, sessionId);
      await _persistCache();
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<SpasticityAssessment?> saveAssessment({
    required String facilityId,
    required String patientId,
    required SpasticityAssessment assessment,
    required bool isEditing,
  }) async {
    if (!_ensurePermission(
      AuthResource.assessments,
      isEditing ? AuthAction.update : AuthAction.create,
      facilityId: facilityId,
    )) {
      return null;
    }

    if (!_connectivity.isOnline) {
      final local = assessment.id.startsWith('local-')
          ? assessment
          : (isEditing
              ? assessment
              : assessment.copyWith(id: _localId('a')));
      _upsertPatientAssessment(
        facilityId: facilityId,
        patientId: patientId,
        assessment: local,
      );
      final key = _sessionKey(facilityId, local.sessionId);
      _sessionPatientIds.putIfAbsent(key, () => <String>{}).add(patientId);

      await _queue.enqueue(
        SyncMutation(
          id: _localId('m'),
          type: SyncMutationType.saveAssessment,
          payload: {
            'facility_id': facilityId,
            'patient_id': patientId,
            'is_editing': isEditing && !local.id.startsWith('local-'),
            'assessment': local.toCacheJson(),
          },
        ),
      );
      await _persistCache();
      notifyListeners();
      return local;
    }

    try {
      final Map<String, dynamic> json;
      if (isEditing) {
        json = await _api.put(
          ApiEndpoints.sessionAssessment(
            facilityId,
            assessment.sessionId,
            assessment.id,
          ),
          body: assessment.toApiBody(),
        );
      } else {
        json = await _api.post(
          ApiEndpoints.sessionAssessments(facilityId, assessment.sessionId),
          body: assessment.toApiBody(includePatientId: true),
        );
      }

      final saved = SpasticityAssessment.fromJson(
        json,
        fallbackSessionId: assessment.sessionId,
      );
      final withNeckJaw = saved.copyWith(
        patterns: saved.patterns.copyWith(
          neck: assessment.patterns.neck,
          jaw: assessment.patterns.jaw,
        ),
      );

      _upsertPatientAssessment(
        facilityId: facilityId,
        patientId: patientId,
        assessment: withNeckJaw,
      );

      final key = _sessionKey(facilityId, assessment.sessionId);
      _sessionPatientIds.putIfAbsent(key, () => <String>{}).add(patientId);

      try {
        await _saveNeckJawPatterns(
          facilityId: facilityId,
          sessionId: withNeckJaw.sessionId,
          assessmentId: withNeckJaw.id,
          patterns: withNeckJaw.patterns,
        );
      } on ApiException catch (error) {
        _error = error.message;
      }

      await _persistCache();
      notifyListeners();
      return getAssessment(facilityId, patientId, withNeckJaw.id) ??
          withNeckJaw;
    } on ApiException catch (error) {
      _error = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> syncPending() async {
    if (!_connectivity.isOnline || _syncing || !_queue.hasPending) return;

    _syncing = true;
    _syncMessage = 'Syncing ${_queue.pendingCount} change(s)…';
    notifyListeners();

    try {
      while (_queue.hasPending && _connectivity.isOnline) {
        final mutation = _queue.items.first;
        await _applyMutation(mutation);
        await _queue.removeById(mutation.id);
      }
      await _persistCache();
      _syncMessage = _queue.hasPending ? null : 'All changes synced';
    } catch (error) {
      _syncMessage = error is ApiException
          ? 'Sync paused: ${error.message}'
          : 'Sync paused. Will retry when online.';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _applyMutation(SyncMutation mutation) async {
    final payload = mutation.payload;
    switch (mutation.type) {
      case SyncMutationType.createFacility:
        final json = await _api.post(
          ApiEndpoints.facilities,
          body: {
            'name': payload['name'],
            'location': payload['location'],
          },
        );
        final created = LtcFacility.fromJson(json);
        final localId = '${payload['local_id']}';
        final index = _facilities.indexWhere((f) => f.id == localId);
        if (index != -1) {
          final prior = _facilities[index];
          _facilities[index] = created.copyWith(
            patients: prior.patients,
            sessions: prior.sessions,
          );
          await _remapFacilityId(localId, created.id);
        }
      case SyncMutationType.addPatient:
        await _api.post(
          ApiEndpoints.facilityPatients('${payload['facility_id']}'),
          body: {'patient_id': '${payload['patient_id']}'},
        );
      case SyncMutationType.createSession:
        final facilityId = '${payload['facility_id']}';
        final localId = '${payload['local_id']}';
        final json = await _api.post(
          ApiEndpoints.facilitySessions(facilityId),
          body: {'session_date': payload['session_date']},
        );
        final created = AssessmentSession.fromJson(json);
        await _remapSessionId(facilityId, localId, created.id);
      case SyncMutationType.enrollPatients:
        final queuedIds = (payload['patient_ids'] as List?) ?? const [];
        await _api.post(
          ApiEndpoints.sessionPatients(
            '${payload['facility_id']}',
            '${payload['session_id']}',
          ),
          body: {
            'patient_ids': queuedIds.map((id) => '$id').toList(),
          },
        );
      case SyncMutationType.saveAssessment:
        final assessment = SpasticityAssessment.fromJson(
          Map<String, dynamic>.from(payload['assessment'] as Map),
        );
        final facilityId = '${payload['facility_id']}';
        final patientId = '${payload['patient_id']}';
        final isEditing = payload['is_editing'] == true;
        final Map<String, dynamic> json;
        if (isEditing && !assessment.id.startsWith('local-')) {
          json = await _api.put(
            ApiEndpoints.sessionAssessment(
              facilityId,
              assessment.sessionId,
              assessment.id,
            ),
            body: assessment.toApiBody(),
          );
        } else {
          json = await _api.post(
            ApiEndpoints.sessionAssessments(facilityId, assessment.sessionId),
            body: assessment.toApiBody(includePatientId: true),
          );
        }
        final saved = SpasticityAssessment.fromJson(
          json,
          fallbackSessionId: assessment.sessionId,
        );
        final withNeckJaw = saved.copyWith(
          patterns: saved.patterns.copyWith(
            neck: assessment.patterns.neck,
            jaw: assessment.patterns.jaw,
          ),
        );
        _upsertPatientAssessment(
          facilityId: facilityId,
          patientId: patientId,
          assessment: withNeckJaw,
        );
        // Drop the local temp assessment if ids differ.
        if (assessment.id != saved.id) {
          _replaceAssessmentId(
            facilityId: facilityId,
            patientId: patientId,
            oldId: assessment.id,
            assessment: withNeckJaw,
          );
        }
        try {
          await _saveNeckJawPatterns(
            facilityId: facilityId,
            sessionId: withNeckJaw.sessionId,
            assessmentId: withNeckJaw.id,
            patterns: withNeckJaw.patterns,
          );
        } on ApiException {
          // Assessment is already persisted; avoid re-POSTing on retry.
        }
    }
  }

  Future<void> _remapFacilityId(String localId, String serverId) async {
    final index = _facilities.indexWhere((f) => f.id == localId);
    if (index != -1) {
      // Already replaced in apply; ensure id consistency for any lingering refs.
    }
    for (final item in _queue.items) {
      if (item.payload['facility_id'] == localId) {
        item.payload['facility_id'] = serverId;
      }
    }
    await _queue.persist();
  }

  Future<void> _remapSessionId(
    String facilityId,
    String localId,
    String serverId,
  ) async {
    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex != -1) {
      final facility = _facilities[facilityIndex];
      final sessions = facility.sessions
          .map((s) => s.id == localId
              ? AssessmentSession(
                  id: serverId,
                  sessionDate: s.sessionDate,
                  assessmentsCount: s.assessmentsCount,
                )
              : s)
          .toList();
      final patients = facility.patients.map((patient) {
        final assessments = patient.assessments
            .map((a) =>
                a.sessionId == localId ? a.copyWith(sessionId: serverId) : a)
            .toList();
        return patient.copyWith(assessments: assessments);
      }).toList();
      _facilities[facilityIndex] = facility.copyWith(
        sessions: sessions,
        patients: patients,
      );
    }

    final oldKey = _sessionKey(facilityId, localId);
    final roster = _sessionPatientIds.remove(oldKey);
    if (roster != null) {
      _sessionPatientIds[_sessionKey(facilityId, serverId)] = roster;
    }

    for (final item in _queue.items) {
      if (item.payload['session_id'] == localId) {
        item.payload['session_id'] = serverId;
      }
      final assessment = item.payload['assessment'];
      if (assessment is Map &&
          assessment['assessment_session_id'] == localId) {
        assessment['assessment_session_id'] = serverId;
      }
    }
    await _queue.persist();
  }

  void _replaceAssessmentId({
    required String facilityId,
    required String patientId,
    required String oldId,
    required SpasticityAssessment assessment,
  }) {
    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return;
    final facility = _facilities[facilityIndex];
    final patientIndex =
        facility.patients.indexWhere((p) => p.id == patientId);
    if (patientIndex == -1) return;
    final patient = facility.patients[patientIndex];
    final assessments = patient.assessments
        .where((a) => a.id != oldId)
        .toList()
      ..add(assessment);
    final patients = List<Patient>.from(facility.patients);
    patients[patientIndex] = patient.copyWith(assessments: assessments);
    _facilities[facilityIndex] = facility.copyWith(patients: patients);
  }

  void _upsertPatientAssessment({
    required String facilityId,
    required String patientId,
    required SpasticityAssessment assessment,
  }) {
    final facilityIndex = _facilities.indexWhere((f) => f.id == facilityId);
    if (facilityIndex == -1) return;

    final facility = _facilities[facilityIndex];
    final patientIndex =
        facility.patients.indexWhere((p) => p.id == patientId);
    if (patientIndex == -1) return;

    final patient = facility.patients[patientIndex];
    final others =
        patient.assessments.where((a) => a.id != assessment.id).toList();
    final updatedPatients = List<Patient>.from(facility.patients);
    updatedPatients[patientIndex] = patient.copyWith(
      assessments: [...others, assessment],
    );

    _facilities[facilityIndex] =
        facility.copyWith(patients: updatedPatients);
  }

  Future<List<Patient>> _enrichPatients(List<Patient> patients) async {
    if (patients.isEmpty) return patients;
    try {
      final profiles =
          await _patientsApi.getMany(patients.map((p) => p.patientId));
      return patients.map((patient) {
        final profile = profiles[patient.patientId];
        if (profile == null) return patient;
        return patient.copyWith(
          name: profile.fullName,
          ohipNumber: profile.ohipDisplay,
          dateOfBirth: profile.dateOfBirth ?? patient.dateOfBirth,
          address: profile.address ?? patient.address,
        );
      }).toList();
    } catch (_) {
      return patients;
    }
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    if (_ownsConnectivity) _connectivity.dispose();
    if (_ownsPatientsApi) _patientsApi.dispose();
    super.dispose();
  }
}
