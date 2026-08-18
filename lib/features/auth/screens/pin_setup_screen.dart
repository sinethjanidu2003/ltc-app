import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../data/auth_storage.dart';
import '../widgets/pin_pad.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String? _firstPin;
  String? _error;

  bool get _confirming => _firstPin != null;

  Future<void> _onChanged(String value) async {
    setState(() {
      _pin = value;
      _error = null;
    });

    if (value.length < AuthStorage.pinLength) return;

    if (!_confirming) {
      setState(() {
        _firstPin = value;
        _pin = '';
      });
      return;
    }

    if (value != _firstPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _firstPin = null;
        _pin = '';
      });
      return;
    }

    final ok = await widget.auth.setupPin(value);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = widget.auth.lastError ?? 'Could not save PIN.';
        _firstPin = null;
        _pin = '';
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
                      Icons.pin_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _confirming ? 'Confirm your PIN' : 'Create a PIN',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _confirming
                        ? 'Enter the same ${AuthStorage.pinLength}-digit PIN again.'
                        : 'Use this PIN for quick access on this device.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (account != null && account.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                    onChanged: _onChanged,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => widget.auth.skipPinSetup(),
                    child: const Text('Skip for now'),
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
