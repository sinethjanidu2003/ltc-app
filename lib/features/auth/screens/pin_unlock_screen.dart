import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../data/auth_storage.dart';
import '../widgets/pin_pad.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _onChanged(String value) async {
    if (_busy) return;

    setState(() {
      _pin = value;
      _error = null;
    });

    if (value.length < AuthStorage.pinLength) return;

    setState(() => _busy = true);
    final ok = await widget.auth.unlockWithPin(value);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _pin = '';
        _error = widget.auth.lastError;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.auth.user?.email ?? widget.auth.user?.name;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter your PIN',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Welcome back${account != null && account.isNotEmpty ? '' : '.'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (account != null && account.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      account,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 36),
                  PinPad(
                    value: _pin,
                    errorText: _error,
                    enabled: !_busy,
                    onChanged: _onChanged,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => widget.auth.usePasswordInstead(),
                    child: const Text('Use email & password instead'),
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
