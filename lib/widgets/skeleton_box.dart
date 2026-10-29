import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// A pulsing gray placeholder box, shown wherever real content — event
// cards, images, detail-screen layouts — is still loading. Hand-rolled
// (a looping opacity pulse via AnimationController) instead of adding the
// `shimmer` package: the effect needed for this polish pass is a few lines
// and renders identically on every platform, including Flutter web's
// different renderers, which a gradient-sweep ShaderMask isn't guaranteed
// to.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.5,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.skeletonBase,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
