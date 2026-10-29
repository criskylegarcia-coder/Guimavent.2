import 'package:flutter/material.dart';

// Wraps a list item so it fades and slides up into place with a small
// per-index delay when it first appears — e.g. Home's event cards, the
// Events grid. Each instance owns its own AnimationController, started
// once in initState with a Future.delayed offset based on `index`; it
// never restarts on rebuild, so scrolling or an unrelated parent rebuild
// doesn't replay it — only a genuinely new instance (e.g. after a
// pull-to-refresh swaps in a fresh list) does. A single package-free,
// vanilla-Flutter approach rather than a full staggered-animation package,
// since this is a one-shot entrance effect on typically small lists.
class StaggeredFadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredFadeSlideIn({
    super.key,
    required this.index,
    required this.child,
  });

  @override
  State<StaggeredFadeSlideIn> createState() => _StaggeredFadeSlideInState();
}

class _StaggeredFadeSlideInState extends State<StaggeredFadeSlideIn>
    with SingleTickerProviderStateMixin {
  static const _staggerPerItem = Duration(milliseconds: 50);
  static const _itemDuration = Duration(milliseconds: 300);
  // Caps the stagger so a long grid's later items don't wait several
  // seconds — everything past the first 10 starts together instead of the
  // delay stretching out indefinitely.
  static const _maxStaggeredIndex = 10;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _itemDuration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    final delay = _staggerPerItem * widget.index.clamp(0, _maxStaggeredIndex);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
