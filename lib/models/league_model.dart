import 'package:flutter/material.dart';

/// Repräsentiert eine Liga im Gamification-System.
///
/// Ligen werden **nicht** in Firestore gespeichert, sondern lokal aus dem
/// XP-Wert des Nutzers berechnet. Das vermeidet redundante Daten und
/// mögliche Inkonsistenzen zwischen gespeichertem Level und Liga.
///
/// Die Berechnung erfolgt via [LeagueModel.fromXp].
class LeagueModel {
  final String name;
  final String emoji;
  final Color color;
  final Color glowColor;
  final int minXp;
  final int maxXp; // -1 = unbegrenzt (höchste Liga)

  const LeagueModel({
    required this.name,
    required this.emoji,
    required this.color,
    required this.glowColor,
    required this.minXp,
    required this.maxXp,
  });

  /// Fortschritt innerhalb der aktuellen Liga (0.0 – 1.0).
  ///
  /// Bei der höchsten Liga (Diamant) immer 1.0.
  double progressInLeague(int xp) {
    if (maxXp == -1) return 1.0;
    final range = (maxXp - minXp).toDouble();
    if (range <= 0) return 1.0;
    return ((xp - minXp) / range).clamp(0.0, 1.0);
  }

  /// XP die noch bis zum Aufstieg fehlen.
  int xpToNextLeague(int xp) {
    if (maxXp == -1) return 0;
    return (maxXp - xp).clamp(0, maxXp);
  }

  // ── Alle Ligen (aufsteigend) ─────────────────────────────────────────────

  static const List<LeagueModel> all = [
    LeagueModel(
      name: 'Bronze',
      emoji: '🥉',
      color:  Color(0xFFCD7F32),
      glowColor: Color(0x40CD7F32),
      minXp: 0,
      maxXp: 999,
    ),
    LeagueModel(
      name: 'Silber',
      emoji: '🥈',
      color:  Color(0xFFC0C0C0),
      glowColor: Color(0x40C0C0C0),
      minXp: 1000,
      maxXp: 2999,
    ),
    LeagueModel(
      name: 'Gold',
      emoji: '🥇',
      color:  Color(0xFFEAB308),
      glowColor: Color(0x40EAB308),
      minXp: 3000,
      maxXp: 6999,
    ),
    LeagueModel(
      name: 'Platin',
      emoji: '🏅',
      color:  Color(0xFF22D3EE),
      glowColor: Color(0x4022D3EE),
      minXp: 7000,
      maxXp: 14999,
    ),
    LeagueModel(
      name: 'Diamant',
      emoji: '💎',
      color:  Color(0xFF6366F1),
      glowColor: Color(0x406366F1),
      minXp: 15000,
      maxXp: -1, // Höchste Liga — kein weiterer Aufstieg
    ),
  ];

  // ── Factory ──────────────────────────────────────────────────────────────

  /// Berechnet die aktuelle Liga aus einem XP-Wert.
  ///
  /// Beispiel: `LeagueModel.fromXp(1500)` → Silber
  static LeagueModel fromXp(int xp) {
    // Von höchster zu niedrigster Liga iterieren
    for (int i = all.length - 1; i >= 0; i--) {
      if (xp >= all[i].minXp) return all[i];
    }
    return all.first; // Fallback: Bronze
  }

  /// Gibt die nächsthöhere Liga zurück, oder null wenn bereits Diamant.
  LeagueModel? get nextLeague {
    final idx = all.indexOf(this);
    if (idx == -1 || idx >= all.length - 1) return null;
    return all[idx + 1];
  }
}
