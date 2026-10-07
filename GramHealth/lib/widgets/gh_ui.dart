import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import 'language_selector_modal.dart';

/// Shared visual tokens + small building blocks used by the Splash, Login /
/// Registration and Home screens. Kept separate from the app-wide widgets so
/// restyling these screens never affects any other screen.
class GhTokens {
  GhTokens._();

  static const Color border = Color(0xFFDDE8E1);
  static const Color surface = Colors.white;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0D143628), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x14143628), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

class GhLogoMark extends StatelessWidget {
  final double size;
  const GhLogoMark({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.leafGreenPrimary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.leafGreenPrimary.withValues(alpha: 0.25),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(Icons.favorite_rounded,
          size: size * 0.5, color: Colors.white),
    );
  }
}

class GhPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? trailingIcon;

  const GhPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.leafGreenPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.leafGreenPrimary.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GhTokens.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, size: 20),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class GhTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? helperText;
  final TextEditingController controller;
  final IconData? icon;
  final bool isPassword;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const GhTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helperText,
    this.icon,
    this.isPassword = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<GhTextField> createState() => _GhTextFieldState();
}

class _GhTextFieldState extends State<GhTextField> {
  bool _obscured = true;

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(GhTokens.radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            obscureText: widget.isPassword && _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            autofillHints: widget.autofillHints,
            cursorColor: AppColors.leafGreenPrimary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
              helperText: widget.helperText,
              helperStyle:
                  const TextStyle(fontSize: 12, color: AppColors.textMuted),
              filled: true,
              fillColor: widget.enabled
                  ? GhTokens.surface
                  : AppColors.secondaryBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              prefixIcon: widget.icon == null
                  ? null
                  : Icon(widget.icon, size: 20, color: AppColors.textMuted),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _obscured = !_obscured),
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                    )
                  : null,
              border: _border(GhTokens.border),
              enabledBorder: _border(GhTokens.border),
              disabledBorder: _border(GhTokens.border),
              focusedBorder: _border(AppColors.leafGreenPrimary, 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class GhLanguageChip extends StatelessWidget {
  final bool onDark;
  const GhLanguageChip({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.textDark;
    return Material(
      color: onDark ? Colors.white.withValues(alpha: 0.12) : GhTokens.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: onDark ? Colors.white.withValues(alpha: 0.2) : GhTokens.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showLanguageSelector(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.translate_rounded, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                context.currentLanguage.nativeName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GhSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  const GhSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.leafGreenPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel!),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
      ],
    );
  }
}
