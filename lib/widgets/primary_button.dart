import 'package:flutter/material.dart';

// Filled dark-green, full-width button. Styling comes from
// AppTheme.light's elevatedButtonTheme, so this widget just supplies
// the label and the tap handler, plus a subtle press-down scale for
// tactile feedback.
class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  // Listener (not GestureDetector) so this only observes raw pointer
  // events for the scale effect — it doesn't join the gesture arena and
  // so can't intercept or delay the button's own tap handling.
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
        child: ElevatedButton(
          onPressed: widget.onPressed,
          child: Text(widget.label),
        ),
      ),
    );
  }
}
