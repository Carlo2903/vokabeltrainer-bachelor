import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../widgets/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<UserProfile>> _leaderboardFuture;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _leaderboardFuture = context.read<FirestoreService>().getLeaderboard(limit: 100);
  }

  void _setTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() {
      _selectedTabIndex = index;
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<AuthProvider>().currentUser?.uid;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Liga-Bestenliste', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.8),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: const Icon(Icons.emoji_events, color: Color(0xFF13ec5b)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _buildTabItem('Wöchentlich', _selectedTabIndex == 0, () => _setTab(0)),
              _buildTabItem('Monatlich', _selectedTabIndex == 1, () => _setTab(1)),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _leaderboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF13ec5b)));
          }
          if (snapshot.hasError) {
            print('Leaderboard errored: ${snapshot.error}');
            return Center(child: Text('Fehler beim Laden der Bestenliste: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Noch keine Daten vorhanden.'));
          }

          // Top 3 for podium
          final top1 = users.isNotEmpty ? users[0] : null;
          final top2 = users.length > 1 ? users[1] : null;
          final top3 = users.length > 2 ? users[2] : null;
          
          final others = users.length > 3 ? users.sublist(3) : <UserProfile>[];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (top2 != null) Expanded(child: _buildPodiumItem(top2, 2, 110, Colors.grey.shade400)),
                      if (top1 != null) Expanded(child: _buildPodiumItem(top1, 1, 150, const Color(0xFF13ec5b))),
                      if (top3 != null) Expanded(child: _buildPodiumItem(top3, 3, 80, Colors.orange.shade400)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final user = others[index];
                      final rank = index + 4;
                      return _buildListItem(user, rank, user.uid == currentUid, theme);
                    },
                    childCount: others.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabItem(String title, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF13ec5b) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF13ec5b) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPodiumItem(UserProfile user, int rank, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            UserAvatar(
              photoUrl: user.photoUrl,
              displayName: user.displayName,
              radius: rank == 1 ? 35 : 30,
              borderColor: color,
              borderWidth: 3,
            ),
            Positioned(
              bottom: -10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rank == 1 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName.split(' ').first,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${user.xp} XP',
          style: const TextStyle(color: Color(0xFF13ec5b), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
        )
      ],
    );
  }

  Widget _buildListItem(UserProfile user, int rank, bool isCurrent, ThemeData theme) {
    final bgColor = isCurrent ? const Color(0xFF13ec5b) : theme.cardColor;
    final textColor = isCurrent ? Colors.black : theme.textTheme.bodyLarge?.color;
    final xpColor = isCurrent ? Colors.black : const Color(0xFF13ec5b);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: !isCurrent ? Border.all(color: const Color(0xFF13ec5b).withOpacity(0.1)) : null,
        boxShadow: isCurrent
            ? [BoxShadow(color: const Color(0xFF13ec5b).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(fontWeight: FontWeight.bold, color: isCurrent ? Colors.black87 : Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          UserAvatar(
            photoUrl: user.photoUrl,
            displayName: user.displayName,
            radius: 20,
            borderColor: isCurrent ? Colors.black : Colors.grey.shade800,
            borderWidth: 2,
            fallbackBackground: isCurrent ? Colors.black : Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCurrent ? '${user.displayName} (Du)' : user.displayName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  '${user.currentStreak} Tage Serie',
                  style: TextStyle(fontSize: 12, color: isCurrent ? Colors.black87 : Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user.xp} XP',
                style: TextStyle(fontWeight: FontWeight.bold, color: xpColor),
              ),
              if (isCurrent)
                const Text(
                  'WEITER SO!',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
                )
            ],
          ),
        ],
      ),
    );
  }
}
