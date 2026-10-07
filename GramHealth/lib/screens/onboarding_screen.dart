import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../widgets/language_selector_modal.dart';
import '../widgets/slide_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final List<String> _quoteKeys = [
    'quote_1',
    'quote_2',
    'quote_3',
    'quote_4',
    'quote_5',
  ];

  int _quoteIndex = 0;
  late AnimationController _floatCtrl;
  late AnimationController _blob1Ctrl;
  late AnimationController _blob2Ctrl;
  late AnimationController _introCtrl;
  late Animation<double> _floatY;
  late Animation<double> _floatRotate;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _blob1Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _blob2Ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _floatY = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _floatRotate = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Cycle quotes every 5 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      setState(() => _quoteIndex = (_quoteIndex + 1) % _quoteKeys.length);
      return true;
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _blob1Ctrl.dispose();
    _blob2Ctrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isCompact = size.width < 360 || size.height < 640;
    final horizontalPad = isCompact ? 22.0 : 32.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // Animated blobs
          _buildBlobs(),

          // Plus decorative icon
          Positioned(
            top: 70,
            left: 40,
            child: Opacity(
              opacity: 0.3,
              child: const Icon(Icons.add, size: 24, color: AppColors.medicalGreen),
            ),
          ),

          Column(
            children: [
              // Top section with floating quote
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                    child: _reveal(
                      const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
                      offsetY: 0.06,
                      scaleFrom: 0.96,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildFloatingQuote(size),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom card
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _introCtrl,
                  curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
                )),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xF7FFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14143628),
                        blurRadius: 24,
                        offset: Offset(0, -8),
                      )
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    isCompact ? 14 : 18,
                    horizontalPad,
                    (isCompact ? 20 : 28) + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreenPale,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(height: isCompact ? 18 : 24),
                          _reveal(
                            const Interval(0.3, 0.75, curve: Curves.easeOutCubic),
                            child: Text(
                              context.tr('care_made_simple'),
                              style: TextStyle(
                                fontSize: isCompact ? 23 : 27,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.2,
                                color: AppColors.darkNavy,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _reveal(
                            const Interval(0.38, 0.82, curve: Curves.easeOutCubic),
                            child: Text(
                              context.tr('onboarding_desc'),
                              style: TextStyle(
                                fontSize: isCompact ? 14 : 15,
                                color: AppColors.textMuted,
                                height: 1.55,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: isCompact ? 24 : 32),
                          _reveal(
                            const Interval(0.46, 0.92, curve: Curves.easeOutCubic),
                            child: SlideButton(
                              title: context.tr('get_started'),
                              onComplete: () => context.go('/login'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Language selector button at top right
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _introCtrl,
                    curve: const Interval(0.2, 0.6),
                  ),
                  child: _buildLanguageButton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fades and lifts [child] in during the intro, within [interval].
  Widget _reveal(
    Interval interval, {
    required Widget child,
    double offsetY = 0.25,
    double scaleFrom = 1,
  }) {
    final anim = CurvedAnimation(parent: _introCtrl, curve: interval);
    Widget result = SlideTransition(
      position: Tween<Offset>(begin: Offset(0, offsetY), end: Offset.zero)
          .animate(anim),
      child: child,
    );
    if (scaleFrom != 1) {
      result = ScaleTransition(
        scale: Tween<double>(begin: scaleFrom, end: 1).animate(anim),
        child: result,
      );
    }
    return FadeTransition(opacity: anim, child: result);
  }

  Widget _buildLanguageButton() {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => showLanguageSelector(context),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 18, color: AppColors.primaryAccent),
                const SizedBox(width: 6),
                Text(
                  context.currentLanguage.nativeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingQuote(Size size) {
    final cardWidth = (size.width * 0.82).clamp(260.0, 420.0);
    final currentKey = ValueKey('$_quoteIndex-${context.currentLanguage.code}');

    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _floatY.value),
        child: Transform.rotate(
          angle: _floatRotate.value,
          child: child,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Quote card
          Container(
            width: cardWidth,
            constraints: const BoxConstraints(minHeight: 200),
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.medicalGreen.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.leafGreenDeep.withValues(alpha: 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.leafGreenPale,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.format_quote_rounded,
                    size: 22,
                    color: AppColors.leafGreenPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 650),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.center,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, anim) {
                      final incoming = child.key == currentKey;
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(incoming ? 0.12 : -0.12, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.97, end: 1).animate(anim),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      context.tr(_quoteKeys[_quoteIndex]),
                      key: currentKey,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkNavy,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _buildQuoteIndicator(),
              ],
            ),
          ),
          // Floating icons
          Positioned(
            top: -22,
            right: -14,
            child: _floatingIcon(Icons.favorite),
          ),
          Positioned(
            bottom: -18,
            left: -18,
            child: _floatingIcon(Icons.show_chart, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteIndicator() {
    return Semantics(
      label: 'Quote ${_quoteIndex + 1} of ${_quoteKeys.length}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_quoteKeys.length, (i) {
          final active = i == _quoteIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.medicalGreen : AppColors.lightGreenAccent,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  Widget _floatingIcon(IconData icon, {double size = 24}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Icon(icon, size: size, color: AppColors.medicalGreen),
    );
  }

  Widget _buildBlobs() {
    return AnimatedBuilder(
      animation: Listenable.merge([_blob1Ctrl, _blob2Ctrl]),
      builder: (_, __) {
        final b1x = -20 + 40 * _blob1Ctrl.value;
        final b1y = 0 + 30 * _blob1Ctrl.value;
        final b2x = 30 - 40 * _blob2Ctrl.value;
        final b2y = -20 + 30 * _blob2Ctrl.value;
        return Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.1 + b1y,
              left: -MediaQuery.of(context).size.width * 0.1 + b1x,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1FADD).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(150),
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.2 + b2y,
              right: -MediaQuery.of(context).size.width * 0.1 + b2x,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E6FF).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
