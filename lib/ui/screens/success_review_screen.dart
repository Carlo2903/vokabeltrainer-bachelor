import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/badge_model.dart';
import '../widgets/user_avatar.dart';

class SuccessReviewScreen extends StatelessWidget {
  final bool showBackButton;
  
  const SuccessReviewScreen({
    Key? key,
    this.showBackButton = false,
  }) : super(key: key);

  // XP-Meilensteine
  static const List<int> _milestones = [50, 100, 250, 500, 1000, 2500, 5000, 10000];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gamification = context.watch<GamificationProvider>();

    if (gamification.isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF13ec5b))),
      );
    }

    final user = gamification.userProfile;
    if (user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: Text('Kein Profil gefunden.')),
      );
    }

    final xpForNext = gamification.xpForNextLevel;
    final xpForCurrent = gamification.getXpRequiredForLevel(user.level);

    double progress = 0.0;
    if (xpForNext > xpForCurrent) {
      progress = (user.xp - xpForCurrent) / (xpForNext - xpForCurrent);
      progress = progress.clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Kein AppBar mit Zurück-Pfeil – Screen ist Tab, kein pushed Route
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: showBackButton, // Pfeil nur anzeigen, wenn requested
        leading: showBackButton 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text('Erfolge', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        // Share-Button entfernt
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                // --- Profile Section ---
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Profilbild – unterstützt Base64, URL und Initialen
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          UserAvatar(
                            photoUrl: context.watch<AuthProvider>().photoUrl ?? user.photoUrl,
                            displayName: user.displayName,
                            radius: 60,
                            borderColor: const Color(0xFF13ec5b).withOpacity(0.3),
                            borderWidth: 4,
                            fallbackBackground: theme.cardColor,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13ec5b),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                            ),
                            child: Text(
                              'LVL ${user.level}',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName.isEmpty ? 'Benutzer' : user.displayName,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'VOKABEL-ENTDECKER',
                        style: TextStyle(
                          color: Color(0xFF13ec5b),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 200,
                        height: 8,
                        decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(4)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(color: const Color(0xFF13ec5b), borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${xpForNext - user.xp} XP bis Level ${user.level + 1}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // --- Stats Row ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildStatCard(theme,
                          value: gamification.allBadges.where((b) => b.isUnlocked).length.toString(),
                          label: 'ABZEICHEN',
                          valueColor: const Color(0xFF13ec5b)),
                      const SizedBox(width: 8),
                      _buildStatCard(theme, value: '${user.xp}', label: 'GESAMT XP'),
                      const SizedBox(width: 8),
                      _buildStatCard(theme,
                          value: '${user.currentStreak}',
                          label: 'SERIE',
                          icon: Icons.local_fire_department,
                          iconColor: Colors.orange),
                    ],
                  ),
                ),

                // --- XP-Meilensteine Button ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: GestureDetector(
                    onTap: () => _showMilestonesSheet(context, user.xp),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF13ec5b).withOpacity(0.15),
                            const Color(0xFF13ec5b).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF13ec5b).withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13ec5b).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF13ec5b), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('XP-Meilensteine',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(
                                  '${_milestones.where((m) => user.xp >= m).length} / ${_milestones.length} erreicht',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF13ec5b)),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- Badges Grid Title ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Deine Sammlung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Alle ansehen',
                            style: TextStyle(color: Color(0xFF13ec5b), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- Badges Grid ---
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75, // slightly more vertical space for text
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final badge = gamification.allBadges[index];
                  return _buildBadgeTapWrapper(context, badge);
                },
                childCount: gamification.allBadges.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMilestonesSheet(BuildContext context, int currentXp) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Color(0xFF13ec5b)),
                    SizedBox(width: 10),
                    Text('XP-Meilensteine',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _milestones.length,
                  itemBuilder: (context, index) {
                    return _buildMilestoneRow(currentXp, _milestones[index], theme);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestoneRow(int currentXp, int milestone, ThemeData theme) {
    final bool reached = currentXp >= milestone;
    final Color color = reached ? const Color(0xFF13ec5b) : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: reached ? const Color(0xFF13ec5b).withOpacity(0.08) : theme.cardColor.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reached ? const Color(0xFF13ec5b).withOpacity(0.4) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$milestone XP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: reached ? Colors.white : Colors.grey.shade400,
                  ),
                ),
                Text(
                  _milestoneLabel(milestone),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          if (reached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF13ec5b),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Erreicht',
                style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            )
          else
            Text(
              '${currentXp}/$milestone',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
        ],
      ),
    );
  }

  String _milestoneLabel(int milestone) {
    switch (milestone) {
      case 50:   return 'Willkommen in der Welt der Wörter!';
      case 100:  return 'Erster Schritt zum Meister!';
      case 250:  return 'Fleißig dabei!';
      case 500:  return 'Halbzeit zum nächsten Level!';
      case 1000: return 'Vierstellige XP – beeindruckend!';
      case 2500: return 'Echter Vokabel-Fan!';
      case 5000: return 'Elitelerner – Top 10%!';
      case 10000: return 'Legendärer Status erreicht!';
      default:   return '$milestone XP Meilenstein';
    }
  }

  Widget _buildStatCard(ThemeData theme,
      {required String value, required String label, IconData? icon, Color? iconColor, Color? valueColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, color: iconColor, size: 20), const SizedBox(width: 4)],
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTapWrapper(BuildContext context, BadgeModel badge) {
    return GestureDetector(
      onTap: () => _showBadgeDetails(context, badge),
      child: badge.isUnlocked ? _buildUnlockedBadge(badge) : _buildLockedBadgeImproved(badge),
    );
  }

  void _showBadgeDetails(BuildContext context, BadgeModel badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            if (badge.isUnlocked)
              _buildUnlockedBadge(badge)
            else
              _buildLockedBadgeImproved(badge),
            const SizedBox(height: 16),
            Text(badge.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 16),
            if (badge.isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF13ec5b).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Freigeschaltet', style: TextStyle(color: Color(0xFF13ec5b), fontWeight: FontWeight.bold, fontSize: 12)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Noch nicht freigeschaltet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Verstanden', style: TextStyle(color: Color(0xFF13ec5b), fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildUnlockedBadge(BadgeModel badge) {
    Color baseColor = const Color(0xFF13ec5b);
    if (badge.colorHex.toLowerCase() == 'fb923c' || badge.colorHex.toLowerCase().contains('orange')) {
      baseColor = Colors.orange;
    } else if (badge.colorHex.toLowerCase() == '60a5fa' || badge.colorHex.toLowerCase().contains('blue')) {
      baseColor = Colors.blue;
    } else if (badge.colorHex.toLowerCase() == 'eab308' || badge.colorHex.toLowerCase().contains('yellow')) {
      baseColor = Colors.yellow;
    } else if (badge.colorHex.toLowerCase() == 'a855f7' || badge.colorHex.toLowerCase().contains('purple')) {
      baseColor = Colors.purple;
    } else if (badge.colorHex.toLowerCase() == 'f43f5e' || badge.colorHex.toLowerCase().contains('red') || badge.colorHex.toLowerCase().contains('rose')) {
      baseColor = Colors.pink;
    } else if (badge.colorHex.toLowerCase() == '14b8a6' || badge.colorHex.toLowerCase().contains('teal')) {
      baseColor = Colors.teal;
    }

    IconData icon = Icons.military_tech;
    if (badge.iconName.contains('fire')) icon = Icons.local_fire_department;
    else if (badge.iconName.contains('language')) icon = Icons.language;
    else if (badge.iconName.contains('menu_book')) icon = Icons.menu_book;
    else if (badge.iconName.contains('bolt')) icon = Icons.bolt;
    else if (badge.iconName.contains('psychology')) icon = Icons.psychology;
    else if (badge.iconName.contains('groups')) icon = Icons.groups;
    else if (badge.iconName.contains('history_edu')) icon = Icons.history_edu;

    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withOpacity(0.15),
            border: Border.all(color: baseColor, width: 2),
            boxShadow: [BoxShadow(color: baseColor.withOpacity(0.2), blurRadius: 10)],
          ),
          child: Center(child: Icon(icon, color: baseColor, size: 36)),
        ),
        const SizedBox(height: 8),
        Text(badge.name,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildLockedBadgeImproved(BadgeModel badge) {
    IconData icon = Icons.military_tech;
    if (badge.iconName.contains('fire')) icon = Icons.local_fire_department;
    else if (badge.iconName.contains('language')) icon = Icons.language;
    else if (badge.iconName.contains('menu_book')) icon = Icons.menu_book;
    else if (badge.iconName.contains('bolt')) icon = Icons.bolt;
    else if (badge.iconName.contains('psychology')) icon = Icons.psychology;
    else if (badge.iconName.contains('groups')) icon = Icons.groups;
    else if (badge.iconName.contains('history_edu')) icon = Icons.history_edu;

    return Opacity(
      opacity: 0.6,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.02),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            child: Center(child: Icon(icon, color: Colors.white.withOpacity(0.3), size: 36)),
          ),
          const SizedBox(height: 8),
          Text(badge.name,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
