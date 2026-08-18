import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/ltc_repository.dart';
import '../../../features/auth/access_scope.dart';
import '../../../features/auth/models/auth_models.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_shell.dart';
import '../../../widgets/loading_view.dart';
import '../../../screens/ltc_list_screen.dart';
import '../data/users_repository.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({
    super.key,
    required this.repository,
  });

  final LtcRepository repository;

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  UsersRepository? _users;
  List<AuthUser> _items = const [];
  bool _loading = true;
  String? _error;

  UsersRepository get users {
    return _users ??=
        UsersRepository(apiClient: AccessScope.of(context).apiClient);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!AccessScope.of(context).canRead(AuthResource.users)) {
      setState(() {
        _loading = false;
        _error = 'You do not have permission to manage users.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await users.listUsers();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load users.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({AuthUser? user}) async {
    final auth = AccessScope.of(context);
    if (user == null && !auth.canCreate(AuthResource.users)) return;
    if (user != null && !auth.canUpdate(AuthResource.users)) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          repository: widget.repository,
          usersRepository: users,
          existing: user,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _delete(AuthUser user) async {
    if (!AccessScope.of(context).canDelete(AuthResource.users)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user'),
        content:
            Text('Delete ${user.name} (${user.email})? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await users.deleteUser(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _goFacilities() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LtcListScreen(repository: widget.repository),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AccessScope.of(context);
    final canCreate = auth.canCreate(AuthResource.users);
    final canUpdate = auth.canUpdate(AuthResource.users);
    final canDelete = auth.canDelete(AuthResource.users);

    return AppShell(
      title: 'Users',
      subtitle: 'Roles, facilities & permissions',
      drawer: AppDrawer(
        current: AppDrawerDestination.users,
        onFacilities: _goFacilities,
        onUsers: () {},
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add user'),
            )
          : null,
      body: _loading
          ? const LoadingView(message: 'Loading users…')
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No users yet.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.pagePadding,
                        AppSpacing.pagePadding,
                        AppSpacing.pagePadding,
                        100,
                      ),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final user = _items[index];
                        return Material(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.cardRadius),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.cardRadius),
                            onTap:
                                canUpdate ? () => _openForm(user: user) : null,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      _initials(user.name),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user.email,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _Chip(
                                              label: user.role,
                                              color: AppColors.accent,
                                            ),
                                            _Chip(
                                              label: user.isActive
                                                  ? 'Active'
                                                  : 'Inactive',
                                              color: user.isActive
                                                  ? AppColors.success
                                                  : AppColors.warning,
                                            ),
                                            _Chip(
                                              label: user.accessAllFacilities
                                                  ? 'All facilities'
                                                  : '${user.ltcFacilityIds.length} LTC(s)',
                                              color: AppColors.primary,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canUpdate || canDelete)
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _openForm(user: user);
                                        } else if (value == 'delete') {
                                          _delete(user);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (canUpdate)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                        if (canDelete)
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
