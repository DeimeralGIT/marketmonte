import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../models/exchange_models.dart';
import '../providers/exchange_provider.dart';

class SettingsDrawer extends ConsumerWidget {
  const SettingsDrawer({super.key});

  static const _supportedLocales = [
    _LocaleOption(Locale('en'), 'English', '🇺🇸'),
    _LocaleOption(Locale('ru'), 'Русский', '🇷🇺'),
    _LocaleOption(Locale('es'), 'Español', '🇪🇸'),
    _LocaleOption(Locale('fr'), 'Français', '🇫🇷'),
    _LocaleOption(Locale('pt'), 'Português', '🇧🇷'),
    _LocaleOption(Locale('it'), 'Italiano', '🇮🇹'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLocale = context.locale;
    final selectedExchange = ref.watch(exchangeProvider);

    return Drawer(
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Icon(LucideIcons.settings, size: 20, color: AppColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('settings.title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.foreground,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: AppColors.mutedForeground,
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            Divider(color: AppColors.border, height: 24),

            // ── Appearance section ──
            _SectionHeader(label: tr('settings.appearance')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ThemeToggle(
                isDark: isDark,
                onToggle: () => ref.read(themeProvider.notifier).toggle(),
              ),
            ),

            const SizedBox(height: 24),

            // ── Exchange section ──
            _SectionHeader(label: tr('settings.exchange')),
            const SizedBox(height: 8),
            ...Exchange.values.map((exchange) {
              final isSelected = selectedExchange == exchange;
              return _ExchangeTile(
                exchange: exchange,
                isSelected: isSelected,
                onTap: () =>
                    ref.read(exchangeProvider.notifier).setExchange(exchange),
              );
            }),

            const SizedBox(height: 24),

            // ── Language section ──
            _SectionHeader(label: tr('settings.language')),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _supportedLocales.map((option) {
                  final isSelected =
                      currentLocale.languageCode == option.locale.languageCode;
                  return _FlagChip(
                    option: option,
                    isSelected: isSelected,
                    onTap: () => context.setLocale(option.locale),
                  );
                }).toList(),
              ),
            ),

            const Spacer(),

            // ── Version footer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                tr('settings.versionFooter'),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

class _LocaleOption {
  final Locale locale;
  final String label;
  final String flag;
  const _LocaleOption(this.locale, this.label, this.flag);
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _ThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) =>
                      RotationTransition(turns: anim, child: child),
                  child: Icon(
                    isDark ? LucideIcons.moon : LucideIcons.sun,
                    key: ValueKey(isDark),
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDark ? tr('settings.darkMode') : tr('settings.lightMode'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.foreground,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: isDark
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : AppColors.muted,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    alignment: isDark
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? AppColors.accent
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final _LocaleOption option;
  final bool isSelected;
  final VoidCallback onTap;
  const _FlagChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.15)
                : AppColors.secondary,
            border: Border.all(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(option.flag, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

class _ExchangeTile extends StatelessWidget {
  final Exchange exchange;
  final bool isSelected;
  final VoidCallback onTap;
  const _ExchangeTile({
    required this.exchange,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (exchange) {
      case Exchange.binance:
        return LucideIcons.diamond;
      case Exchange.coinbase:
        return LucideIcons.circle;
      case Exchange.mexc:
        return LucideIcons.hexagon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exchange.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.foreground,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(LucideIcons.check, size: 16, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
