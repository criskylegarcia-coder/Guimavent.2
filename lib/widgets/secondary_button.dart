import 'package:flutter/material.dart';

// White background, green border, full-width button. Styling comes from
// AppTheme.light's outlinedButtonTheme, plus a subtle press-down scale for
// tactile feedback — same pattern as PrimaryButton.
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const SecondaryButton({super.key, required this.label, this.onPressed});

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: OutlinedButton(
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}
