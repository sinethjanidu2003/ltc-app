import 'package:flutter/widgets.dart';

import 'data/auth_repository.dart';
import 'models/auth_models.dart';

/// Provides [AuthRepository] (roles/permissions) to the widget tree.
class AccessScope extends InheritedNotifier<AuthRepository> {
  const AccessScope({
    super.key,
    required AuthRepository auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthRepository of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AccessScope>();
    assert(scope != null, 'AccessScope not found in widget tree');
    return scope!.notifier!;
  }

  static AuthRepository? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AccessScope>()
        ?.notifier;
  }

  static AuthUser? userOf(BuildContext context) => of(context).user;

  static bool can(
    BuildContext context,
    AuthResource resource,
    AuthAction action,
  ) =>
      of(context).can(resource, action);

  static bool canAccessFacility(BuildContext context, String facilityId) =>
      of(context).canAccessFacility(facilityId);
}
