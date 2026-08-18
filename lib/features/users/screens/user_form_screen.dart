import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/ltc_repository.dart';
import '../../../features/auth/models/auth_models.dart';
import '../../../theme/app_theme.dart';
import '../data/users_repository.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    required this.repository,
    required this.usersRepository,
    this.existing,
  });

  final LtcRepository repository;
  final UsersRepository usersRepository;
  final AuthUser? existing;

  bool get isEditing => existing != null;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TextEditingController _roleController;

  static const _roles = ['admin', 'clinician', 'viewer'];

  bool _isActive = true;
  bool _accessAllFacilities = false;
  bool _saving = false;
  final Set<String> _facilityIds = {};
  late Map<AuthResource, ResourceAccess> _permissions;

  String get _role => _roleController.text.trim();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      _emailController.text = existing.email;
      _roleController = TextEditingController(text: existing.role);
      _isActive = existing.isActive;
      _accessAllFacilities = existing.accessAllFacilities;
      _facilityIds.addAll(existing.ltcFacilityIds);
      _permissions = {
        for (final resource in AuthResource.values)
          resource: existing.permissions[resource] ?? const ResourceAccess(),
      };
    } else {
      _roleController = TextEditingController(text: 'clinician');
      _permissions = permissionTemplateForRole('clinician');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.repository.managedFacilities.isEmpty) {
        widget.repository.loadFacilities();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _applyRoleTemplate(String role) {
    setState(() {
      _roleController.text = role;
      _permissions = permissionTemplateForRole(role);
      if (role == 'admin') {
        _accessAllFacilities = true;
      }
    });
  }

  void _setPermission(
    AuthResource resource,
    AuthAction action,
    bool value,
  ) {
    final current = _permissions[resource] ?? const ResourceAccess();
    setState(() {
      _permissions[resource] = ResourceAccess(
        read: action == AuthAction.read ? value : current.read,
        create: action == AuthAction.create ? value : current.create,
        update: action == AuthAction.update ? value : current.update,
        delete: action == AuthAction.delete ? value : current.delete,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (!_accessAllFacilities && _facilityIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign at least one LTC facility, or enable all facilities.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await widget.usersRepository.updateUser(
          id: widget.existing!.id,
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text.trim().isEmpty
              ? null
              : _passwordController.text,
          role: _role,
          isActive: _isActive,
          accessAllFacilities: _accessAllFacilities,
          ltcFacilityIds:
              _accessAllFacilities ? const [] : _facilityIds.toList(),
          permissions: _permissions,
        );
      } else {
        await widget.usersRepository.createUser(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _role,
          isActive: _isActive,
          accessAllFacilities: _accessAllFacilities,
          ltcFacilityIds:
              _accessAllFacilities ? const [] : _facilityIds.toList(),
          permissions: _permissions,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save user.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final facilities = widget.repository.managedFacilities;
        final isWide = MediaQuery.sizeOf(context).width > 900;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(widget.isEditing ? 'Edit user' : 'Add user'),
            actions: [
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check, color: Colors.white),
                label: Text(
                  _saving ? 'Saving…' : 'Save',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              children: [
                _SectionCard(
                  title: 'Account',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Name is required'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: widget.isEditing
                              ? 'Password (leave blank to keep)'
                              : 'Password',
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (widget.isEditing) return null;
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Role template',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._roles.map((role) {
                            final selected = _role == role;
                            return ChoiceChip(
                              label: Text(role),
                              selected: selected,
                              onSelected: (_) => _applyRoleTemplate(role),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _roleController,
                        decoration: const InputDecoration(
                          labelText: 'Role value sent to API',
                          helperText:
                              'Choosing a template fills permissions; you can still edit the role string.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: _isActive,
                        onChanged: (value) =>
                            setState(() => _isActive = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Facility access',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Access all facilities'),
                        subtitle: const Text(
                          'When on, facility assignment below is ignored.',
                        ),
                        value: _accessAllFacilities,
                        onChanged: (value) =>
                            setState(() => _accessAllFacilities = value),
                      ),
                      if (!_accessAllFacilities) ...[
                        const SizedBox(height: 8),
                        if (facilities.isEmpty)
                          const Text(
                            'No facilities loaded yet. Open Facilities and refresh, then return.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...facilities.map(
                            (facility) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _facilityIds.contains(facility.id),
                              title: Text(facility.name),
                              subtitle: facility.address.isEmpty
                                  ? null
                                  : Text(facility.address),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _facilityIds.add(facility.id);
                                  } else {
                                    _facilityIds.remove(facility.id);
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Permissions',
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _permissionTable(
                                AuthResource.values.take(3),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _permissionTable(
                                AuthResource.values.skip(3),
                              ),
                            ),
                          ],
                        )
                      : _permissionTable(AuthResource.values),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save user'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _permissionTable(Iterable<AuthResource> resources) {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(flex: 2, child: SizedBox()),
            Expanded(child: Center(child: Text('Read'))),
            Expanded(child: Center(child: Text('Create'))),
            Expanded(child: Center(child: Text('Update'))),
            Expanded(child: Center(child: Text('Delete'))),
          ],
        ),
        const Divider(),
        ...resources.map((resource) {
          final access = _permissions[resource] ?? const ResourceAccess();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    resource.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Checkbox(
                    value: access.read,
                    onChanged: (v) =>
                        _setPermission(resource, AuthAction.read, v ?? false),
                  ),
                ),
                Expanded(
                  child: Checkbox(
                    value: access.create,
                    onChanged: (v) =>
                        _setPermission(resource, AuthAction.create, v ?? false),
                  ),
                ),
                Expanded(
                  child: Checkbox(
                    value: access.update,
                    onChanged: (v) =>
                        _setPermission(resource, AuthAction.update, v ?? false),
                  ),
                ),
                Expanded(
                  child: Checkbox(
                    value: access.delete,
                    onChanged: (v) =>
                        _setPermission(resource, AuthAction.delete, v ?? false),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
