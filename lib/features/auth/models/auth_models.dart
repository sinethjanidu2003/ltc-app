enum AuthResource {
  facilities,
  patients,
  sessions,
  assessments,
  muscles,
  users,
}

enum AuthAction { read, create, update, delete }

class ResourceAccess {
  const ResourceAccess({
    this.read = false,
    this.create = false,
    this.update = false,
    this.delete = false,
  });

  final bool read;
  final bool create;
  final bool update;
  final bool delete;

  factory ResourceAccess.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ResourceAccess();
    return ResourceAccess(
      read: json['read'] == true,
      create: json['create'] == true,
      update: json['update'] == true,
      delete: json['delete'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'read': read,
        'create': create,
        'update': update,
        'delete': delete,
      };

  bool allows(AuthAction action) {
    switch (action) {
      case AuthAction.read:
        return read;
      case AuthAction.create:
        return create;
      case AuthAction.update:
        return update;
      case AuthAction.delete:
        return delete;
    }
  }
}

class AuthFacilitySummary {
  const AuthFacilitySummary({
    required this.id,
    required this.name,
    this.location,
  });

  final String id;
  final String name;
  final String? location;

  factory AuthFacilitySummary.fromJson(Map<String, dynamic> json) {
    return AuthFacilitySummary(
      id: '${json['id']}',
      name: (json['name'] as String?)?.trim() ?? 'Facility',
      location: (json['location'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (location != null) 'location': location,
      };
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    required this.deviceName,
  });

  final String email;
  final String password;
  final String deviceName;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'device_name': deviceName,
      };
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.isActive = true,
    this.accessAllFacilities = false,
    this.permissions = const {},
    this.ltcFacilityIds = const [],
    this.ltcFacilities = const [],
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final bool accessAllFacilities;
  final Map<AuthResource, ResourceAccess> permissions;
  final List<String> ltcFacilityIds;
  final List<AuthFacilitySummary> ltcFacilities;

  bool can(AuthResource resource, AuthAction action) {
    if (!isActive) return false;
    return permissions[resource]?.allows(action) ?? false;
  }

  bool canRead(AuthResource resource) => can(resource, AuthAction.read);
  bool canCreate(AuthResource resource) => can(resource, AuthAction.create);
  bool canUpdate(AuthResource resource) => can(resource, AuthAction.update);
  bool canDelete(AuthResource resource) => can(resource, AuthAction.delete);

  bool canAccessFacility(String facilityId) {
    if (!isActive) return false;
    if (accessAllFacilities) return true;
    return ltcFacilityIds.contains(facilityId);
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final permissionsJson = json['permissions'];
    final Map<AuthResource, ResourceAccess> permissions = {};
    if (permissionsJson is Map) {
      for (final resource in AuthResource.values) {
        final key = resource.name;
        final value = permissionsJson[key];
        if (value is Map) {
          permissions[resource] =
              ResourceAccess.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }

    final idsJson = json['ltc_facility_ids'];
    final List<String> facilityIds = idsJson is List
        ? idsJson.map((id) => '$id').toList()
        : const [];

    final facilitiesJson = json['ltc_facilities'];
    final List<AuthFacilitySummary> facilities = facilitiesJson is List
        ? facilitiesJson
            .whereType<Map>()
            .map(
              (item) =>
                  AuthFacilitySummary.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
        : const [];

    // Prefer explicit ids; fall back to embedded facility list.
    final resolvedIds = facilityIds.isNotEmpty
        ? facilityIds
        : facilities.map((f) => f.id).toList();

    return AuthUser(
      id: '${json['id'] ?? ''}',
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : (json['email'] as String? ?? 'User'),
      email: json['email'] as String? ?? '',
      role: (json['role'] as String?)?.trim() ?? 'user',
      isActive: json['is_active'] != false,
      accessAllFacilities: json['access_all_facilities'] == true,
      permissions: permissions,
      ltcFacilityIds: resolvedIds,
      ltcFacilities: facilities,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'is_active': isActive,
        'access_all_facilities': accessAllFacilities,
        'permissions': {
          for (final entry in permissions.entries)
            entry.key.name: entry.value.toJson(),
        },
        'ltc_facility_ids': ltcFacilityIds,
        'ltc_facilities': ltcFacilities.map((f) => f.toJson()).toList(),
      };
}

class AuthSession {
  const AuthSession({
    required this.token,
    this.user,
  });

  final String token;
  final AuthUser? user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = (json['token'] ??
            json['access_token'] ??
            json['plainTextToken'] ??
            '')
        .toString();

    if (token.isEmpty) {
      throw const FormatException('Login response did not include a token');
    }

    final userJson = json['user'];
    final user = userJson is Map
        ? AuthUser.fromJson(Map<String, dynamic>.from(userJson))
        : null;

    if (user != null && !user.isActive) {
      throw const FormatException('This account is inactive.');
    }

    return AuthSession(token: token, user: user);
  }
}
