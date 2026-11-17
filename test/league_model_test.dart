import 'package:flutter_test/flutter_test.dart';
import 'package:vokabeltrainer/models/league_model.dart';

void main() {
  group('LeagueModel XP Boundaries Test', () {
    test('0 XP should evaluate to Bronze League', () {
      final league = LeagueModel.fromXp(0);
      expect(league.name, 'Bronze');
    });

    test('999 XP should evaluate to Bronze League', () {
      final league = LeagueModel.fromXp(999);
      expect(league.name, 'Bronze');
    });

    test('1000 XP should evaluate to Silber League', () {
      final league = LeagueModel.fromXp(1000);
      expect(league.name, 'Silber');
    });

    test('3000 XP should evaluate to Gold League', () {
      final league = LeagueModel.fromXp(3000);
      expect(league.name, 'Gold');
    });

    test('7000 XP should evaluate to Platin League', () {
      final league = LeagueModel.fromXp(7000);
      expect(league.name, 'Platin');
    });

    test('15000 XP should evaluate to Diamant League', () {
      final league = LeagueModel.fromXp(15000);
      expect(league.name, 'Diamant');
    });
  });
}
