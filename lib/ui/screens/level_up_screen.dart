import 'package:flutter/material.dart';

class LevelUpScreen extends StatelessWidget {
  final int newLevel;
  final int earnedXp;
  final int currentXp;
  final int nextLevelXp;
  final int masteredWords;

  const LevelUpScreen({
    Key? key,
    required this.newLevel,
    required this.earnedXp,
    required this.currentXp,
    required this.nextLevelXp,
    required this.masteredWords,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Calculate progress
    // We assume currentXp is already taking into account the level up. 
    // To find the progress within current level, we ideally need the base XP, 
    // but just a percentage works.
    double progress = 0.5; // default fallback
    int baseLevelXp = 0; // if we can pass it
    // Using a simplier UI visual for the progress bar without the exact 'base level xp'.
    // If currentXp >= nextLevelXp, it might be bugged or leveled up again.
    if (nextLevelXp > 0) {
       // Estimate base level xp for visualization logic
       progress = (currentXp / nextLevelXp).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sieg!', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Hero Badge ---
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF13ec5b).withOpacity(0.15),
                      border: Border.all(color: const Color(0xFF13ec5b), width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF13ec5b).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: const Icon(Icons.workspace_premium, size: 80, color: Color(0xFF13ec5b)),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF13ec5b),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'LEVEL $newLevel',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                      ),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Level Aufstieg!',
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.1),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vokabel-Virtuose',
                style: TextStyle(fontSize: 18, color: Color(0xFF13ec5b), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),

              // --- Progress Card ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('NÄCHSTES LEVEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              '$currentXp / $nextLevelXp XP',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF13ec5b), fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF13ec5b),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF13ec5b).withOpacity(0.5), blurRadius: 10)
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- Stats Grid ---
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt, color: Color(0xFF13ec5b), size: 20),
                              SizedBox(width: 4),
                              Text('XP VERDIENT', style: TextStyle(color: Color(0xFF13ec5b), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('+$earnedXp XP', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('+15% bonus', style: TextStyle(color: Color(0xFF13ec5b), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.cardColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.menu_book, color: Color(0xFF13ec5b), size: 20),
                              SizedBox(width: 4),
                              Text('GEMEISTERT', style: TextStyle(color: Color(0xFF13ec5b), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('$masteredWords Wörter', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('Tagesziel erreicht', style: TextStyle(color: Color(0xFF13ec5b), fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // --- Last Image visual Mockup ---
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey.shade900,
                  image: const DecorationImage(
                    image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAu99GdDebqp31T4fCMXtqqHQWexjdMH89Xmpm_nXxva-14Qh-7YEl_YBF9AmMlDiXO7Cc1nw5BArOC76m_twSeR5l3a9HNPhFFKLNPhOFA2pIB84lX8z3jf9mYo0CufQvmc-TSHAUgItoTjjmUCcsxVfIB5K9TwA3OrBWQpReZRwRqde0Wf7CHCg8_nSj5zIYMA_S3A3pSdNN9S3IlApt0DzF8AH-mWZjHkIS6UwBS4f77xOwAgJt6gYVRA3-B9llWbhwazgU6HA4'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('NEUESTE WÖRTER', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      SizedBox(height: 4),
                      Text('Ephemeral • Ubiquitous • Resilient', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100), // Bottom padding
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF13ec5b),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.play_arrow, color: Colors.black),
                  SizedBox(width: 8),
                  Text('WEITERLERNEN'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: TextButton.styleFrom(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textTheme.bodyLarge?.color,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: const Text('ZUM DASHBOARD'),
            ),
          ],
        ),
      ),
    );
  }
}
