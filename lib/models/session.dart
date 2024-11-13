import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_round.dart';
import 'game_types.dart';

class Session {
  final String id;
  final List<String> players;
  final double baseValue;
  final List<GameRound> rounds;
  final int currentDealer;
  final bool isActive;
  final DateTime date;

  Session({
    required this.id,
    required this.players,
    required this.baseValue,
    required this.rounds,
    required this.currentDealer,
    required this.isActive,
    required this.date,
  });

  Map<String, double> get playerBalances {
    Map<String, double> balances = {for (var player in players) player: 0.0};
    
    for (var round in rounds) {
      if (round.gameType == GameType.ramsch) {
        final loser = round.mainPlayer;
        final otherPlayers = players.where((p) => p != loser).toList();
        
        balances[loser] = (balances[loser] ?? 0) - (round.value * otherPlayers.length);
        
        for (var player in otherPlayers) {
          balances[player] = (balances[player] ?? 0) + round.value;
        }
      } else {
        if (round.isWon) {
          balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) + 
              (round.value * (players.length - 1));
          
          for (var player in players.where((p) => p != round.mainPlayer)) {
            balances[player] = (balances[player] ?? 0) - round.value;
          }
        } else {
          balances[round.mainPlayer] = (balances[round.mainPlayer] ?? 0) - 
              (round.value * (players.length - 1));
          
          for (var player in players.where((p) => p != round.mainPlayer)) {
            balances[player] = (balances[player] ?? 0) + round.value;
          }
        }
      }
    }
    
    return balances;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'players': players,
      'baseValue': baseValue,
      'rounds': rounds.map((round) => round.toFirestore()).toList(),
      'playerBalances': playerBalances,
      'currentDealer': currentDealer,
      'isActive': isActive,
      'date': Timestamp.fromDate(date),
    };
  }

  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Session(
      id: doc.id,
      players: List<String>.from(data['players']),
      baseValue: (data['baseValue'] as num).toDouble(),
      rounds: (data['rounds'] as List? ?? [])
          .map((round) => GameRound.fromFirestore(round as Map<String, dynamic>))
          .toList(),
      currentDealer: data['currentDealer'] as int,
      isActive: data['isActive'] as bool? ?? true,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  void validate() {
    if (players.length < 3 || players.length > 4) {
      throw Exception('Invalid number of players (must be 3 or 4)');
    }
    if (players.length == 3 && rounds.any((r) => r.gameType == GameType.sauspiel)) {
      throw Exception('Sauspiel not allowed in 3-player game');
    }
  }
} 