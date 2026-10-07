import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// SlideButton replicates the React Native SlideButton component.
/// The user drags the thumb right to confirm; if released past 80% it
/// triggers [onComplete], otherwise it snaps back.
class SlideButton extends StatefulWidget {
  final String title;
  final VoidCallback onComplete;

  const SlideButton({
    super.key,
    required this.title,
    required this.onComplete,
  });

  @override
  State<SlideButton> createState() => _SlideButtonState();
}

class _SlideButtonState extends State<SlideButton>
    with TickerProviderStateMixin {
  static const double _buttonHeight = 64;
  static const double _thumbSize = 52;
  static const double _inset = 6;
  static const double _completeThreshold = 0.8;

  double _thumbX = 0;
  double _maxX = 1;
  bool _completed = false;
  bool _pressed = false;

  late final AnimationController _snapController;
  late final AnimationController _hintController;
  Animation<double>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    // A single listener reads whichever tween is current, so repeated snaps
    // never stack stale listeners on the controller.
    _snapController = AnimationController(vsync: this)
      ..addListener(() {
        final anim = _snapAnimation;
        if (anim != null) setState(() => _thumbX = anim.value);
      });
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _snapController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  TickerFuture _animateTo(
    double target, {
    Curve curve = Curves.easeOutCubic,
    Duration duration = const Duration(milliseconds: 320),
  }) {
    _snapController.duration = duration;
    _snapAnimation = Tween<double>(begin: _thumbX, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: curve),
    );
    return _snapController.forward(from: 0);
  }

  void _complete() {
    if (_completed) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _completed = true;
      _pressed = false;
    });
    _hintController.stop();
    _animateTo(_maxX, duration: const Duration(milliseconds: 220));
    Future.delayed(const Duration(milliseconds: 420), widget.onComplete);
  }

  // A tap nudges the thumb to teach the slide gesture without completing it.
  Future<void> _nudge() async {
    if (_completed || _snapController.isAnimating) return;
    HapticFeedback.selectionClick();
    await _animateTo(_maxX * 0.16, duration: const Duration(milliseconds: 220));
    if (!mounted || _completed) return;
    await _animateTo(0, duration: const Duration(milliseconds: 380));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        _maxX = (width - _thumbSize - _inset * 2).clamp(1.0, double.infinity);
        final progress = (_thumbX / _maxX).clamp(0.0, 1.0);

        return Semantics(
          button: true,
          label: widget.title,
          hint: 'Slide right to continue',
          onTap: _complete,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _nudge,
            onTapDown: (_) {
              if (!_completed) setState(() => _pressed = true);
            },
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onHorizontalDragStart: (_) {
              if (_completed) return;
              _snapController.stop();
              setState(() => _pressed = true);
            },
            onHorizontalDragUpdate: (d) {
              if (_completed) return;
              setState(() {
                _thumbX = (_thumbX + d.delta.dx).clamp(0.0, _maxX);
              });
            },
            onHorizontalDragEnd: (_) {
              if (_completed) return;
              setState(() => _pressed = false);
              if (_thumbX > _maxX * _completeThreshold) {
                _complete();
              } else {
                _animateTo(0, duration: const Duration(milliseconds: 420));
              }
            },
            child: SizedBox(
              width: width,
              height: _buttonHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.darkNavy,
                  borderRadius: BorderRadius.circular(_buttonHeight / 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkNavy.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      _buildProgressFill(progress),
                      _buildLabel(progress),
                      _buildTrailingChevrons(progress),
                      _buildThumb(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressFill(double progress) {
    return Container(
      width: _thumbX + _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(
        color: AppColors.medicalGreen
            .withValues(alpha: 0.14 + 0.18 * progress),
        borderRadius: BorderRadius.circular(_thumbSize / 2),
      ),
    );
  }

  Widget _buildLabel(double progress) {
    final opacity = (1 - progress * 1.8).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(left: _thumbSize + 8, right: 36),
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(progress * 24, 0),
            child: AnimatedBuilder(
              animation: _hintController,
              builder: (_, child) {
                final t = _hintController.value;
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => LinearGradient(
                    colors: const [
                      Color(0xB3FFFFFF),
                      Colors.white,
                      Color(0xB3FFFFFF),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    begin: Alignment(-2.5 + t * 5, 0),
                    end: Alignment(-1.5 + t * 5, 0),
                  ).createShader(rect),
                  child: child,
                );
              },
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingChevrons(double progress) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Opacity(
          opacity: (0.45 * (1 - progress * 1.5)).clamp(0.0, 1.0),
          child: const Icon(
            Icons.keyboard_double_arrow_right_rounded,
            size: 22,
            color: AppColors.lightGreenAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    final idle = _thumbX == 0 && !_pressed && !_completed;
    return Transform.translate(
      offset: Offset(_thumbX, 0),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          width: _thumbSize,
          height: _thumbSize,
          decoration: BoxDecoration(
            color: _completed ? AppColors.lightGreenAccent : AppColors.medicalGreen,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _completed
                ? const Icon(
                    Icons.check_rounded,
                    key: ValueKey('done'),
                    color: AppColors.darkNavy,
                    size: 26,
                  )
                : AnimatedBuilder(
                    key: const ValueKey('arrow'),
                    animation: _hintController,
                    builder: (_, child) {
                      final v = _hintController.value;
                      final t = Curves.easeInOut
                          .transform(v < 0.5 ? v * 2 : 2 - v * 2);
                      return Transform.translate(
                        offset: Offset(idle ? 3 * t : 0, 0),
                        child: child,
                      );
                    },
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.darkNavy,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
