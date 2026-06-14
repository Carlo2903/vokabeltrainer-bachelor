import 'dart:convert';
import 'package:flutter/material.dart';

/// Zeigt ein Profilbild an – unterstützt Base64-Strings (aus Firestore),
/// echte Netzwerk-URLs (z.B. Google-Login) und einen Initialien-Fallback.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Color fallbackBackground;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.radius = 40,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.fallbackBackground = const Color(0xFF1E293B),
  });

  @override
  Widget build(BuildContext context) {
    final border = borderWidth > 0
        ? Border.all(color: borderColor, width: borderWidth)
        : null;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
        color: fallbackBackground,
      ),
      child: ClipOval(child: _buildImage()),
    );
  }

  Widget _buildImage() {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return _initials();
    }

    // Base64-Daten-URI: "data:image/jpeg;base64,/9j/..."
    if (photoUrl!.startsWith('data:')) {
      try {
        final base64Str = photoUrl!.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        );
      } catch (_) {
        return _initials();
      }
    }

    // Normale URL (Google Sign-In photoURL etc.)
    return Image.network(
      photoUrl!,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _initials(),
    );
  }

  Widget _initials() {
    final parts = displayName.trim().split(' ');
    final text = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : '?';
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: radius * 0.65,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
