import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/models/auth_models.dart';

/// Admin CRUD against `/api/users`.
class UsersRepository {
  UsersRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<AuthUser>> listUsers() async {
    final list = await _api.getList(ApiEndpoints.users);
    return list
        .whereType<Map>()
        .map((item) => AuthUser.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<AuthUser> getUser(String id) async {
    final json = await _api.get(ApiEndpoints.userById(id));
    return AuthUser.fromJson(json);
  }

  Future<AuthUser> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required List<String> ltcFacilityIds,
    required Map<AuthResource, ResourceAccess> permissions,
    bool accessAllFacilities = false,
    bool isActive = true,
  }) async {
    final json = await _api.post(
      ApiEndpoints.users,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role.trim(),
        'is_active': isActive,
        'access_all_facilities': accessAllFacilities,
        'ltc_facility_ids': ltcFacilityIds
            .map((id) => int.tryParse(id) ?? id)
            .toList(),
        'permissions': {
          for (final resource in AuthResource.values)
            resource.name: (permissions[resource] ?? const ResourceAccess())
                .toJson(),
        },
      },
    );
    return AuthUser.fromJson(_unwrapUser(json));
  }

  Future<AuthUser> updateUser({
    required String id,
    String? name,
    String? email,
    String? password,
    String? role,
    bool? isActive,
    bool? accessAllFacilities,
    List<String>? ltcFacilityIds,
    Map<AuthResource, ResourceAccess>? permissions,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (email != null) body['email'] = email.trim();
    if (password != null && password.isNotEmpty) body['password'] = password;
    if (role != null) body['role'] = role.trim();
    if (isActive != null) body['is_active'] = isActive;
    if (accessAllFacilities != null) {
      body['access_all_facilities'] = accessAllFacilities;
    }
    if (ltcFacilityIds != null) {
      body['ltc_facility_ids'] =
          ltcFacilityIds.map((id) => int.tryParse(id) ?? id).toList();
    }
    if (permissions != null) {
      body['permissions'] = {
        for (final resource in AuthResource.values)
          resource.name:
              (permissions[resource] ?? const ResourceAccess()).toJson(),
      };
    }

    final json = await _api.put(ApiEndpoints.userById(id), body: body);
    return AuthUser.fromJson(_unwrapUser(json));
  }

  Future<void> deleteUser(String id) async {
    await _api.delete(ApiEndpoints.userById(id));
  }

  Map<String, dynamic> _unwrapUser(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map) return Map<String, dynamic>.from(user);
    if (json.containsKey('id') || json.containsKey('email')) return json;
    throw const ApiException(message: 'Unexpected user response from API.');
  }
}

/// Common role permission templates for the admin form.
Map<AuthResource, ResourceAccess> permissionTemplateForRole(String role) {
  switch (role.trim().toLowerCase()) {
    case 'admin':
      return {
        for (final resource in AuthResource.values)
          resource: const ResourceAccess(
            read: true,
            create: true,
            update: true,
            delete: true,
          ),
      };
    case 'viewer':
      return {
        for (final resource in AuthResource.values)
          resource: ResourceAccess(
            read: resource != AuthResource.users,
            create: false,
            update: false,
            delete: false,
          ),
      };
    case 'clinician':
    default:
      return {
        AuthResource.facilities: const ResourceAccess(read: true),
        AuthResource.patients: const ResourceAccess(
          read: true,
          create: true,
          update: true,
        ),
        AuthResource.sessions: const ResourceAccess(
          read: true,
          create: true,
          update: true,
        ),
        AuthResource.assessments: const ResourceAccess(
          read: true,
          create: true,
          update: true,
          delete: true,
        ),
        AuthResource.muscles: const ResourceAccess(
          read: true,
          create: true,
        ),
        AuthResource.users: const ResourceAccess(),
      };
  }
}
