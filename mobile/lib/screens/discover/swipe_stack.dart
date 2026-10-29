import 'package:material_ui/material_ui.dart';

import '../../models/deck.dart';
import '../../models/user.dart';
import '../../ui/ui.dart';
import 'profile_card.dart';

/// The top two cards of the deck. Drag the top card past the threshold (or
/// fling it) to swipe; [SwipeStackState.swipe] does the same for buttons and keys.
class SwipeStack extends StatefulWidget {
  const SwipeStack({
    super.key,
    required this.cards,
    required this.seen,
    required this.total,
    required this.onSwiped,
  });

  /// The deck, best fit first.
  final List<User> cards;

  /// How many cards were swiped before [cards] and how many there were in all,
  /// for the "3 of 18" counter.
  final int seen;
  final int total;

  /// Called once the card has flown off screen.
  final void Function(User person, SwipeDirection direction) onSwiped;

  @override
  State<SwipeStack> createState() => SwipeStackState();
}

class SwipeStackState extends State<SwipeStack> with SingleTickerProviderStateMixin {
  static const _threshold = 110.0;
  static const _flingSpeed = 900.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(_follow);

  /// Where the top card is, relative to its resting place.
  var _offset = Offset.zero;
  Animation<Offset>? _motion;
  var _flying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Throws the top card off screen, as if it had been dragged.
  void swipe(SwipeDirection direction) {
    if (!_flying && widget.cards.isNotEmpty) _flyOut(direction);
  }

  void _follow() {
    final motion = _motion;
    if (motion != null) setState(() => _offset = motion.value);
  }

  TickerFuture _animateTo(Offset target, Curve curve) {
    _motion = _controller.drive(
      Tween(begin: _offset, end: target).chain(CurveTween(curve: curve)),
    );
    return _controller.forward(from: 0);
  }

  void _onDragStart(DragStartDetails _) {
    if (_flying) return;
    _controller.stop();
    _motion = null;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_flying) setState(() => _offset += details.delta);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_flying) return;
    final speed = details.velocity.pixelsPerSecond.dx;
    if (_offset.dx > _threshold || speed > _flingSpeed) {
      _flyOut(SwipeDirection.right);
    } else if (_offset.dx < -_threshold || speed < -_flingSpeed) {
      _flyOut(SwipeDirection.left);
    } else {
      _animateTo(Offset.zero, Curves.easeOutBack);
    }
  }

  Future<void> _flyOut(SwipeDirection direction) async {
    _flying = true;
    final width = context.size?.width ?? 400;
    final side = direction == SwipeDirection.right ? 1 : -1;
    await _animateTo(Offset(side * width * 1.4, _offset.dy + 40), Curves.easeIn);
    if (!mounted) return;
    final person = widget.cards.first;
    setState(() {
      _motion = null;
      _offset = Offset.zero;
      _flying = false;
    });
    widget.onSwiped(person, direction);
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards.take(2).toList();
    final pull = (_offset.dx / _threshold).clamp(-1.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onDragStart,
      onPanUpdate: _onDragUpdate,
      onPanEnd: _onDragEnd,
      child: Stack(
        children: [
          // The next card waits behind, growing as the top card leaves.
          for (final (i, person) in cards.indexed.toList().reversed)
            _CardSlot(
              key: ValueKey(person.id),
              person: person,
              position: '${widget.seen + i + 1} of ${widget.total}',
              offset: i == 0 ? _offset : Offset(0, 12 * (1 - pull.abs())),
              angle: i == 0 ? _offset.dx * 0.001 : 0,
              scale: i == 0 ? 1 : 0.95 + 0.05 * pull.abs(),
              like: i == 0 ? pull.clamp(0.0, 1.0) : 0,
              pass: i == 0 ? (-pull).clamp(0.0, 1.0) : 0,
            ),
        ],
      ),
    );
  }
}

/// One card in the stack, with its LIKE / PASS stamps. Every card is built
/// the same way so the next card keeps its state when it moves to the top.
class _CardSlot extends StatelessWidget {
  const _CardSlot({
    super.key,
    required this.person,
    required this.position,
    required this.offset,
    required this.angle,
    required this.scale,
    required this.like,
    required this.pass,
  });

  final User person;
  final String position;
  final Offset offset;
  final double angle;
  final double scale;
  final double like;
  final double pass;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(child: ProfileCard(person: person, position: position)),
                  Positioned(
                    top: 18,
                    left: 14,
                    child: _Stamp('Like', color: Palette.blue, angle: -0.2, opacity: like),
                  ),
                  Positioned(
                    top: 18,
                    right: 14,
                    child: _Stamp('Pass', color: Palette.pink, angle: 0.2, opacity: pass),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Stamp extends StatelessWidget {
  const _Stamp(this.text, {required this.color, required this.angle, required this.opacity});

  final String text;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: angle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Palette.ink, width: 2.5),
              ),
              child: Text(text.toUpperCase(), style: AppType.title(size: 30)),
            ),
          ),
        ),
      );
}
