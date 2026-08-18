import 'package:flutter/material.dart';

import '../features/auth/access_scope.dart';
import '../features/auth/models/auth_models.dart';
import '../theme/app_theme.dart';

enum AppDrawerDestination { facilities, users }

/// Shared navigation drawer for Facilities / Users / Sign out.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.current,
    required this.onFacilities,
    this.onUsers,
  });

  final AppDrawerDestination current;
  final VoidCallback onFacilities;
  final VoidCallback? onUsers;

  @override
  Widget build(BuildContext context) {
    final auth = AccessScope.of(context);
    final user = auth.user;
    final canManageUsers =
        onUsers != null && auth.canRead(AuthResource.users);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LTC Assessment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user?.email.isNotEmpty == true)
                    Text(
                      user!.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  if (user?.role.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        user!.role,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Facilities'),
              selected: current == AppDrawerDestination.facilities,
              onTap: () {
                Navigator.pop(context);
                onFacilities();
              },
            ),
            if (canManageUsers)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: const Text('Users'),
                selected: current == AppDrawerDestination.users,
                onTap: () {
                  Navigator.pop(context);
                  onUsers!();
                },
              ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out'),
                    content: const Text(
                      'Sign out of this account on this device?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await AccessScope.of(context).logout();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
