import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A premium-styled password text field with animated neon glow.
/// - Cyan glow when focused.
/// - Red glow when [hasError] is true (also triggers a shake animation).
class SentryTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool obscureText;
  final int maxLines;

  const SentryTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.hasError = false,
    this.onChanged,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
  });

  @override
  State<SentryTextField> createState() => _SentryTextFieldState();
}

class _SentryTextFieldState extends State<SentryTextField>
    with SingleTickerProviderStateMixin {
  late bool _obscureText;
  bool _isFocused = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(SentryTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Color get _glowColor =>
      widget.hasError ? const Color(0xFFFF4D4D) : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final shake = math.sin(_shakeAnimation.value * math.pi * 6) * 8;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: (_isFocused || widget.hasError)
              ? [
                  BoxShadow(
                    color: _glowColor.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscureText,
            maxLines: widget.maxLines,
            onChanged: widget.onChanged,
            validator: widget.validator,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: _isFocused ? _glowColor : Colors.white38,
                size: 20,
              ),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _isFocused ? _glowColor : Colors.white38,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _glowColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF4D4D),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF4D4D),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
