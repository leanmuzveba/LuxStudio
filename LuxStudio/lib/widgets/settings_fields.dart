import 'package:flutter/material.dart';

import '../theme/lux_theme.dart';

/// Shared building blocks for the church-settings form, used by both the
/// mobile [SettingsScreen] and desktop [SettingsDesktopScreen] (Phase 31)
/// — kept public/shared rather than duplicated per screen.
class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LuxColors.surface,
        border: Border.all(color: LuxColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: LuxColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: LuxText.manrope(size: 14, weight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: LuxText.manrope(size: 11.5, color: LuxColors.textSecondary, height: 1.4)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String label;
  const FieldLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: LuxText.manrope(size: 9.5, weight: FontWeight.w700, color: LuxColors.textMuted, letterSpacing: 0.8),
      ),
    );
  }
}

class SettingsTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const SettingsTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: LuxText.manrope(size: 13, color: LuxColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: LuxColors.background,
        hintText: hint,
        hintStyle: LuxText.manrope(size: 13, color: LuxColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LuxColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LuxColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LuxColors.gold),
        ),
      ),
    );
  }
}

class LuxIconAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const LuxIconAddButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LuxColors.gold,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(width: 44, height: 44, child: Icon(Icons.add_rounded, color: LuxColors.background)),
      ),
    );
  }
}

class RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const RemovableChip({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: LuxColors.gold.withValues(alpha: 0.1),
        border: Border.all(color: LuxColors.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: LuxText.manrope(size: 11, weight: FontWeight.w600, color: LuxColors.gold)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 13, color: LuxColors.gold),
          ),
        ],
      ),
    );
  }
}

class TemplateSwatch extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const TemplateSwatch({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? LuxColors.gold : LuxColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              height: 32,
              decoration: BoxDecoration(
                gradient: LuxColors.goldGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('Aa', style: LuxText.sora(size: 14, weight: FontWeight.w800, color: LuxColors.background)),
            ),
            const SizedBox(height: 6),
            Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: LuxText.manrope(size: 10, weight: FontWeight.w600, color: LuxColors.textSecondary),
                ),
                if (selected)
                  const Positioned(
                    right: -4,
                    top: -18,
                    child: Icon(Icons.check_circle_rounded, size: 14, color: LuxColors.gold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
