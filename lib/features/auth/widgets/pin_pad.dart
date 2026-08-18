import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_theme.dart';
import '../data/auth_storage.dart';

/// Shared 4-digit PIN entry UI with an on-screen keypad.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxLength = AuthStorage.pinLength,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool enabled;
  final int maxLength;

  void _append(String digit) {
    if (!enabled || value.length >= maxLength) return;
    HapticFeedback.selectionClick();
    onChanged(value + digit);
  }

  void _backspace() {
    if (!enabled || value.isEmpty) return;
    HapticFeedback.selectionClick();
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(maxLength, (index) {
            final filled = index < value.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 36),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 76, height: 76);
                }
                if (key == 'del') {
                  return _KeyButton(
                    onTap: enabled ? _backspace : null,
                    child: const Icon(
                      Icons.backspace_outlined,
                      color: AppColors.textPrimary,
                    ),
                  );
                }
                return _KeyButton(
                  onTap: enabled ? () => _append(key) : null,
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 76,
            height: 76,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
