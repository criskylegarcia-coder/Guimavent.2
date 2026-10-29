import 'package:flutter/material.dart';

// A password TextField with a "show password" eye-icon toggle, shared by
// every password input across both the tourist app and the admin portal
// (login, sign-up, confirm password) so the toggle behaves identically
// everywhere instead of being reimplemented per screen.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  // Screens use either style of label (login/register use hintText, the
  // admin login screen uses labelText) — both are supported so this widget
  // can drop into either without changing that screen's look.
  final String? hintText;
  final String? labelText;
  final ValueChanged<String>? onSubmitted;
  // Defaults to true so the admin portal's existing bordered-input look
  // (its other fields all set border: OutlineInputBorder() explicitly)
  // stays unchanged. The tourist app's screens pass false to inherit the
  // app-wide InputDecorationTheme's borderless filled style instead,
  // matching their own Email/Full Name fields.
  final bool showBorder;

  const PasswordField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.onSubmitted,
    this.showBorder = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  // Hidden by default, like every password field before this widget existed.
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        labelText: widget.labelText,
        border: widget.showBorder ? const OutlineInputBorder() : null,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
          ),
          tooltip: _obscureText ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}
