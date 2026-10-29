import 'package:flutter/material.dart';

// The search bar used at the top of both Home and Events. Owns its own
// TextEditingController, seeded from initialValue, so a screen can
// pre-populate it — e.g. EventsShellScreen showing the query Home's search
// handed off via the /events?q=... route (see HomeShellScreen's
// AppSearchField and app_router.dart's '/events' route).
class AppSearchField extends StatefulWidget {
  final String hintText;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppSearchField({
    super.key,
    required this.hintText,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
  }
}
