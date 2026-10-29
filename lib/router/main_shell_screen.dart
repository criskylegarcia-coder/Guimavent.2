import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/itinerary/my_itinerary_shell_screen.dart';
import '../theme/app_theme.dart';

// Lets MainShellScreen reach MyItineraryShellScreen's State directly to
// force a refetch when the Itinerary tab is (re)selected — see _onTap.
// Defined here (not in app_router.dart) so both this file and
// app_router.dart (which attaches it as that route's widget key) can share
// it without a circular import.
final GlobalKey<MyItineraryShellScreenState> itineraryScreenKey =
    GlobalKey<MyItineraryShellScreenState>();

class _NavTab {
  final IconData icon;
  final String label;
  const _NavTab(this.icon, this.label);
}

// One per bottom-nav branch, in the same order as app_router.dart's
// StatefulShellRoute branches: Home, Events, Itinerary, Map, Profile.
const List<_NavTab> _navTabs = [
  _NavTab(Icons.home_rounded, 'Home'),
  _NavTab(Icons.event_rounded, 'Events'),
  _NavTab(Icons.checklist_rounded, 'Itinerary'),
  _NavTab(Icons.map_rounded, 'Map'),
  _NavTab(Icons.person_rounded, 'Profile'),
];

// The Scaffold that wraps every tab: the current tab's screen on top, a
// floating "bump" pill nav bar underneath (see _BumpNavBar) — the active
// tab's icon pops up out of a notch cut into the bar, and slides smoothly
// to the newly selected tab. go_router calls this once and swaps out
// `navigationShell`'s body whenever the selected tab changes.
class MainShellScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with SingleTickerProviderStateMixin {
  // Index of the Itinerary tab among the shell's branches.
  static const int _itineraryBranchIndex = 2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  // Tracks the bump's animated position as a fractional tab index (e.g.
  // 1.6 = 60% of the way from tab 1 to tab 2) — starts stationary at
  // whichever tab is current on first build, only becomes a real Tween
  // once the user actually switches tabs (see didUpdateWidget).
  late Animation<double> _indexAnimation = AlwaysStoppedAnimation(
    widget.navigationShell.currentIndex.toDouble(),
  );

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIndex = oldWidget.navigationShell.currentIndex;
    final newIndex = widget.navigationShell.currentIndex;
    if (oldIndex != newIndex) {
      _indexAnimation =
          Tween<double>(begin: oldIndex.toDouble(), end: newIndex.toDouble())
              .animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
              );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    // Tapping the tab you're already on takes you back to its first route
    // instead of doing nothing.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    if (index == _itineraryBranchIndex) {
      // StatefulShellRoute keeps MyItineraryShellScreen's State alive across
      // tab switches, so its own initState() never runs again on its own —
      // force a refetch every time this tab is selected so changes made
      // elsewhere (e.g. "+ Add to Itinerary" on Activity/Event Details) show
      // up without needing a full app restart.
      itineraryScreenKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: _BumpNavBar(
        indexAnimation: _indexAnimation,
        onTap: _onTap,
      ),
    );
  }
}

// The floating pill itself: a dark rounded bar with a circular notch cut
// into its top edge, and a green filled circle — holding the active tab's
// icon — poking up out of that notch. Both the notch and the circle slide
// together, driven by indexAnimation.
class _BumpNavBar extends StatelessWidget {
  final Animation<double> indexAnimation;
  final ValueChanged<int> onTap;

  const _BumpNavBar({required this.indexAnimation, required this.onTap});

  static const double _barHeight = 64;
  static const double _bumpDiameter = 52;
  // Just a few px larger than the bump circle's own radius — a snug cutout
  // the circle sits directly into, not a loose ring with a gap of bar
  // color showing around it.
  static const double _notchRadius = _bumpDiameter / 2 + 4;
  static const double _horizontalMargin = 16;
  static const double _bottomMargin = 16;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: _bottomMargin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalMargin),
        child: SizedBox(
          // Extra headroom above the bar for the bump circle to poke into.
          height: _barHeight + _bumpDiameter / 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              final slotWidth = barWidth / _navTabs.length;
              return AnimatedBuilder(
                animation: indexAnimation,
                builder: (context, _) {
                  final animatedIndex = indexAnimation.value;
                  final notchX = (animatedIndex + 0.5) * slotWidth;
                  final activeTabIndex = animatedIndex.round().clamp(
                    0,
                    _navTabs.length - 1,
                  );
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _barHeight,
                        child: CustomPaint(
                          size: Size(barWidth, _barHeight),
                          painter: _BumpBarPainter(
                            notchX: notchX,
                            notchRadius: _notchRadius,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _barHeight,
                        child: Row(
                          children: [
                            for (var i = 0; i < _navTabs.length; i++)
                              Expanded(
                                child: _NavTabContent(
                                  icon: _navTabs[i].icon,
                                  label: _navTabs[i].label,
                                  // 1 exactly when tab i is the (settled or
                                  // mid-slide) active one. Fades the icon
                                  // out (it lives in the bump instead) and
                                  // brightens the label as the bump
                                  // arrives over this tab; reverses as it
                                  // leaves — a crossfade, not an abrupt
                                  // swap.
                                  activeAmount: (1 - (animatedIndex - i).abs())
                                      .clamp(0.0, 1.0),
                                  onTap: () => onTap(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: notchX - _bumpDiameter / 2,
                        top: 0,
                        child: _BumpCircle(
                          icon: _navTabs[activeTabIndex].icon,
                          diameter: _bumpDiameter,
                          onTap: () => onTap(activeTabIndex),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Draws the dark pill (full bar rect, fully rounded ends) with a circular
// bite cut out of its top edge at notchX, via Path.combine's difference
// operation — the standard technique for a "notched" bar shape.
class _BumpBarPainter extends CustomPainter {
  final double notchX;
  final double notchRadius;

  _BumpBarPainter({required this.notchX, required this.notchRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final barPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    final notchPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(notchX, 0), radius: notchRadius),
      );
    final barWithNotch = Path.combine(
      PathOperation.difference,
      barPath,
      notchPath,
    );

    // The shadow is cast from the plain (un-notched) pill outline, not
    // barWithNotch — drawShadow traces a path's full outline, including
    // concave edges, so shadowing the notched path put a visible shadow
    // arc *inside* the cutout itself (on top of the bump circle's own
    // separate shadow), reading as a stray "ghost" ring behind the bump
    // instead of one clean shape. This way there's a single ordinary
    // floating-pill shadow, and the cutout itself casts none.
    canvas.drawShadow(barPath, Colors.black54, 8, false);
    canvas.drawPath(barWithNotch, Paint()..color = AppColors.navBarDark);
  }

  @override
  bool shouldRepaint(covariant _BumpBarPainter oldDelegate) =>
      oldDelegate.notchX != notchX || oldDelegate.notchRadius != notchRadius;
}

// One tab slot's content: icon + label, stacked. The icon fades out as the
// bump arrives (its real icon lives in the floating circle instead), but
// the label stays put in the same spot the whole time — for the active
// tab this reads as the label belonging to the bump popped up above it.
class _NavTabContent extends StatelessWidget {
  final IconData icon;
  final String label;
  final double activeAmount;
  final VoidCallback onTap;

  const _NavTabContent({
    required this.icon,
    required this.label,
    required this.activeAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = Color.lerp(Colors.white60, AppColors.white, activeAmount)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: (1 - activeAmount).clamp(0.0, 1.0),
              child: Icon(icon, color: Colors.white60, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: activeAmount > 0.5 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The floating green circle holding the active tab's icon, popping up out
// of the bar's notch.
class _BumpCircle extends StatelessWidget {
  final IconData icon;
  final double diameter;
  final VoidCallback onTap;

  const _BumpCircle({
    required this.icon,
    required this.diameter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          // One subtle, tight shadow directly under the circle — now that
          // the bar itself no longer casts a shadow around the notch (see
          // _BumpBarPainter), this is the only shadow near the bump, so it
          // reads as a clean single shape instead of doubled/ghosted.
          boxShadow: [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppColors.white, size: 24),
      ),
    );
  }
}
