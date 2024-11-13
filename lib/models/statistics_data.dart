import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'session.dart';
import 'game_types.dart';
import 'game_round.dart';
import 'player.dart';

class StatisticsData {
  final Map<String, PlayerStatistics> playerStats;
  final Map<String, List<double>> balanceHistory;
  final List<GameRecord> records;
  final List<Session> sessions;

  StatisticsData({
    required this.playerStats,
    required this.balanceHistory,
    required this.records,
    required this.sessions,
  });

  factory StatisticsData.fromSessions(List<Session> sessions) {
    print('Creating StatisticsData from ${sessions.length} sessions');
    try {
      final playerStats = _calculatePlayerStats(sessions);
      print('Calculated player stats');
      
      final balanceHistory = _calculateBalanceHistory(sessions);
      print('Calculated balance history');
      
      final records = _calculateRecords(sessions);
      print('Calculated records');

      return StatisticsData(
        playerStats: playerStats,
        balanceHistory: balanceHistory,
        records: records,
        sessions: sessions,
      );
    } catch (e, stackTrace) {
      print('Error in StatisticsData.fromSessions: $e');
      print(stackTrace);
      rethrow;
    }
  }

  static Map<String, PlayerStatistics> _calculatePlayerStats(List<Session> sessions) {
    final stats = <String, PlayerStatistics>{};
    
    for (final session in sessions) {
      for (final player in session.players) {
        stats.putIfAbsent(
          player,
          () => PlayerStatistics.empty(player),
        ).gamesParticipated += session.rounds.length;
      }

      for (final round in session.rounds) {
        final player = stats.putIfAbsent(
          round.mainPlayer,
          () => PlayerStatistics.empty(round.mainPlayer),
        );
        
        player.gamesPlayed++;
        if (round.isWon) player.gamesWon++;
        player.gameTypeStats.update(
          round.gameType,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      for (final entry in session.playerBalances.entries) {
        stats.putIfAbsent(
          entry.key,
          () => PlayerStatistics.empty(entry.key),
        ).totalEarnings += entry.value;
      }
    }
    
    return stats;
  }

  static List<GameRecord> _calculateRecords(List<Session> sessions) {
    List<GameRecord> records = [];

    // Most valuable streak
    Map<String, List<double>> playerStreaks = {};
    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.mainPlayer != null) {
          playerStreaks.putIfAbsent(round.mainPlayer, () => []);
          playerStreaks[round.mainPlayer]!.add(
            round.isWon ? round.value : -round.value
          );
        }
      }
    }

    if (playerStreaks.isNotEmpty) {
      double maxStreakValue = 0;
      String maxStreakPlayer = '';
      int maxStreakLength = 0;

      for (final entry in playerStreaks.entries) {
        List<double> values = entry.value;
        for (int i = 0; i < values.length; i++) {
          double sum = 0;
          for (int j = i; j < values.length; j++) {
            sum += values[j];
            if (sum > maxStreakValue) {
              maxStreakValue = sum;
              maxStreakPlayer = entry.key;
              maxStreakLength = j - i + 1;
            }
          }
        }
      }

      if (maxStreakValue > 0) {
        records.add(GameRecord(
          type: RecordType.mostValuableStreak,
          player: maxStreakPlayer,
          value: maxStreakValue,
          additionalInfo: '$maxStreakLength Spiele',
        ));
      }
    }

    // Longest streak
    Map<String, int> currentStreaks = {};
    Map<String, int> maxStreaks = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.mainPlayer != null) {
          if (round.isWon) {
            currentStreaks[round.mainPlayer] = (currentStreaks[round.mainPlayer] ?? 0) + 1;
            maxStreaks[round.mainPlayer] = max(
              maxStreaks[round.mainPlayer] ?? 0,
              currentStreaks[round.mainPlayer]!
            );
          } else {
            currentStreaks[round.mainPlayer] = 0;
          }
        }
      }
    }

    if (maxStreaks.isNotEmpty) {
      final longestStreak = maxStreaks.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.longestStreak,
        player: longestStreak.key,
        value: longestStreak.value.toDouble(),
        additionalInfo: '${longestStreak.value} Siege in Folge',
      ));
    }

    // Continue with other records, adding similar null checks...
    // For each record calculation, wrap in if (collection.isNotEmpty) { ... }

    return records;
  }

  static Map<String, List<double>> _calculateBalanceHistory(List<Session> sessions) {
    final history = <String, List<double>>{};
    
    // Sort sessions by date
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Initialize starting balances
    for (final session in sortedSessions) {
      for (final player in session.players) {
        history.putIfAbsent(player, () => [0.0]);  // Start with 0
      }
    }
    
    // Calculate running totals
    for (final session in sortedSessions) {
      for (final entry in session.playerBalances.entries) {
        final previousBalance = history[entry.key]!.last;
        history[entry.key]!.add(previousBalance + entry.value);
      }
    }
    
    return history;
  }
}

class PlayerStatistics {
  final String name;
  int gamesPlayed;
  int gamesWon;
  int gamesParticipated;
  double totalEarnings;
  Map<GameType, int> gameTypeStats;

  PlayerStatistics({
    required this.name,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.gamesParticipated,
    required this.totalEarnings,
    required this.gameTypeStats,
  });

  factory PlayerStatistics.empty(String name) => PlayerStatistics(
    name: name,
    gamesPlayed: 0,
    gamesWon: 0,
    gamesParticipated: 0,
    totalEarnings: 0,
    gameTypeStats: {},
  );

  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;
  double get participationRate => gamesParticipated > 0 ? gamesPlayed / gamesParticipated : 0;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'gamesParticipated': gamesParticipated,
      'totalEarnings': totalEarnings,
      'gameTypeStats': gameTypeStats.map(
        (key, value) => MapEntry(key.name, value),
      ),
    };
  }

  factory PlayerStatistics.fromFirestore(Map<String, dynamic> data) {
    return PlayerStatistics(
      name: data['name'] as String,
      gamesPlayed: data['gamesPlayed'] as int,
      gamesWon: data['gamesWon'] as int,
      gamesParticipated: data['gamesParticipated'] as int,
      totalEarnings: (data['totalEarnings'] as num).toDouble(),
      gameTypeStats: (data['gameTypeStats'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          GameType.values.firstWhere((e) => e.name == key),
          value as int,
        ),
      ),
    );
  }

  factory PlayerStatistics.fromPlayer(Player player) {
    return PlayerStatistics(
      name: player.name,
      gamesPlayed: player.gamesPlayed,
      gamesWon: player.gamesWon,
      gamesParticipated: player.gamesParticipated,
      totalEarnings: player.totalEarnings,
      gameTypeStats: Map.from(player.gameTypeStats),
    );
  }

  Player toPlayer() {
    final player = Player(name: name);
    player.gamesPlayed = gamesPlayed;
    player.gamesWon = gamesWon;
    player.gamesParticipated = gamesParticipated;
    player.totalEarnings = totalEarnings;
    player.gameTypeStats = Map.from(gameTypeStats);
    return player;
  }
}

enum RecordType {
  mostValuableStreak,
  longestStreak,
  highestSingleWin,
  biggestComeback,
  mostGamesInSession,
  highestDailyVolume,
  bestWinRate,
  mostGamesPlayed,
  highestAverageEarnings,
  mostSoloGames,
  bestSoloWinRate,
  mostRamschLosses,
  bestTeamPlayer,
  worstLossStreak,
  mostConsistentPlayer,
}

class GameRecord {
  final String player;
  final double value;
  final RecordType type;
  final String? additionalInfo;  // For extra context like dates or game types

  const GameRecord({
    required this.player,
    required this.value,
    required this.type,
    this.additionalInfo,
  });
}

class SoloStats {
  int gamesPlayed = 0;
  int gamesWon = 0;
  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;
}

class TeamPlayStats {
  int gamesPlayed = 0;
  int gamesWon = 0;
  double get winRate => gamesPlayed > 0 ? gamesWon / gamesPlayed : 0;
} 