import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Logo
                Image.asset(
                  'assets/icon/app_icon.png',
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                // Title
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: AppColors.foreground,
                          height: 1.2,
                        ),
                        children: [
                          TextSpan(text: tr('header.market')),
                          TextSpan(
                            text: tr('header.monte'),
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      tr('app.subtitle'),
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.mutedForeground,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Settings button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        LucideIcons.menu,
                        size: 18,
                        color: AppColors.mutedForeground,
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
