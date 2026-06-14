import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 72, color: AppColors.textMuted),
            const SizedBox(height: 24),
            Text(title,
                style: GoogleFonts.lexend(fontSize: 22, color: Colors.white,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Kommt bald.',
                style: GoogleFonts.lexend(fontSize: 14, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
