import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Shared animation helpers. Every one of them goes still when the phone
/// asks for reduced motion.
abstract final class Motion {
  /// Material 3 emphasized curves: things decelerate into place as they
  /// arrive and speed up as they leave. [standard] is for state changes.
  static const ease = Easing.emphasizedDecelerate;
  static const exit = Easing.emphasizedAccelerate;
  static const standard = Easing.standard;

  /// Widget tests switch this off so screens settle without waiting on
  /// looping or delayed animations.
  static bool enabled = true;

  /// Whether animations should run in this context.
  static bool on(BuildContext context) =>
      enabled && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// [duration], or zero when animations are turned off.
  static Duration of(BuildContext context, Duration duration) =>
      on(context) ? duration : Duration.zero;

  /// The stagger for the [index]th item of a list, capped so long lists
  /// don't keep the bottom rows waiting.
  static Duration stagger(int index, {int stepMs = 60}) =>
      Duration(milliseconds: stepMs * index.clamp(0, 8));
}

/// Runs a 0→1 animation once, after a delay, and builds from its value.
/// Starts finished when animations are off. The delay timer is cancelled if
/// the widget goes away first.
class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.delay,
    required this.duration,
    required this.curve,
    required this.builder,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Widget Function(double t, Widget child) builder;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _t = CurvedAnimation(parent: _c, curve: widget.curve);
  Timer? _timer;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!Motion.on(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) => widget.builder(_t.value, child!),
      );
}

/// Fades its child in while it slides up a few pixels, after [delay].
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.delay = Duration.zero, this.offset = 14});

  final Widget child;
  final Duration delay;

  /// How far it travels; negative drops it in from above.
  final double offset;

  @override
  Widget build(BuildContext context) => _Entrance(
        delay: delay,
        duration: const Duration(milliseconds: 450),
        curve: Motion.ease,
        builder: (t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, offset * (1 - t)), child: child),
        ),
        child: child,
      );
}

/// Fades its child in while it slides in from the right, after [delay]:
/// list rows arriving one after another.
class SlideIn extends StatelessWidget {
  const SlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => _Entrance(
        delay: delay,
        duration: const Duration(milliseconds: 450),
        curve: Motion.ease,
        builder: (t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(28 * (1 - t), 0), child: child),
        ),
        child: child,
      );
}

/// Scales its child up from small with a little overshoot, after [delay].
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => _Entrance(
        delay: delay,
        duration: const Duration(milliseconds: 520),
        curve: Curves.elasticOut,
        builder: (t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: t, child: child),
        ),
        child: child,
      );
}

/// Grows its child up from the bottom edge, like a podium block rising.
class GrowUp extends StatelessWidget {
  const GrowUp({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => _Entrance(
        delay: delay,
        duration: const Duration(milliseconds: 700),
        curve: Motion.ease,
        builder: (t, child) => ClipRect(
          child: Align(alignment: Alignment.bottomCenter, heightFactor: t, child: child),
        ),
        child: child,
      );
}

/// Animates its own size as its child grows or shrinks. With animations off
/// it just takes the new size (AnimatedSize can't run at zero duration).
class SmoothSize extends StatelessWidget {
  const SmoothSize({super.key, required this.child, this.duration = const Duration(milliseconds: 350)});

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) => Motion.on(context)
      ? AnimatedSize(duration: duration, curve: Motion.ease, alignment: Alignment.topCenter, child: child)
      : child;
}

/// Floats its child gently up and down on a loop, after [delay].
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.delay = Duration.zero, this.distance = 6});

  final Widget child;
  final Duration delay;
  final double distance;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.on(context)) {
      _timer?.cancel();
      _c.stop();
    } else if (!_c.isAnimating && _timer == null) {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -widget.distance * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
      );
}

/// Gently breathes its child (scale and opacity) on a loop: LIVE dots, the
/// Like button.
class Pulse extends StatefulWidget {
  const Pulse({
    super.key,
    required this.child,
    this.minScale = 0.8,
    this.period = const Duration(milliseconds: 1400),
  });

  final Widget child;
  final double minScale;
  final Duration period;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.on(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Opacity(
            opacity: 1 - 0.45 * t,
            child: Transform.scale(scale: 1 - (1 - widget.minScale) * t, child: child),
          );
        },
      );
}

/// Counts a number up from zero when it appears (crew points).
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, required this.style, this.prefix = '', this.suffix = ''});

  final int value;
  final TextStyle style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: Motion.on(context) ? 0 : value.toDouble(), end: value.toDouble()),
        duration: Motion.of(context, const Duration(milliseconds: 900)),
        curve: Motion.ease,
        builder: (context, v, _) => Text('$prefix${v.round()}$suffix', style: style),
      );
}
