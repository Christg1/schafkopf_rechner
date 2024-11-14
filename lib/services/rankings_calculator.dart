import 'package:flutter/material.dart';
import '../models/statistics_data.dart';
import '../models/game_types.dart';
import '../models/session.dart';

class PlayerRanking {
  final String name;
  final double value;
  final String? additionalInfo;

  PlayerRanking({
    required this.name,
    required this.value,
    this.additionalInfo,
  });
}

class Rankings {
  final List<PlayerRanking> bestSauspielPlayers;
  final List<PlayerRanking> bestWenzPlayers;
  final List<PlayerRanking> bestSoloPlayers;
  final List<PlayerRanking> leastRamschLosses;
  final List<PlayerRanking> bestKontraPlayers;
  final List<PlayerRanking> highestSoloEarnings;
  final List<PlayerRanking> bestGeierPlayers;
  final List<PlayerRanking> bestFarbspielPlayers;

  Rankings({
    required this.bestSauspielPlayers,
    required this.bestWenzPlayers,
    required this.bestSoloPlayers,
    required this.leastRamschLosses,
    required this.bestKontraPlayers,
    required this.highestSoloEarnings,
    required this.bestGeierPlayers,
    required this.bestFarbspielPlayers,
  });

  // Optional: Add a factory constructor for empty rankings
  factory Rankings.empty() => Rankings(
    bestSauspielPlayers: [],
    bestWenzPlayers: [],
    bestSoloPlayers: [],
    leastRamschLosses: [],
    bestKontraPlayers: [],
    highestSoloEarnings: [],
    bestGeierPlayers: [],
    bestFarbspielPlayers: [],
  );
}

class RankingsCalculator {
  static Rankings calculateRankings(StatisticsData statistics) {
    // Initialize maps with default values
    final Map<String, int> sauspielGames = {};
    final Map<String, int> sauspielWins = {};
    final Map<String, int> wenzGames = {};
    final Map<String, int> wenzWins = {};
    final Map<String, int> soloGames = {};
    final Map<String, int> soloWins = {};
    final Map<String, int> ramschLosses = {};
    final Map<String, int> kontraGames = {};
    final Map<String, int> kontraWins = {};
    final Map<String, double> soloEarnings = {};
    final Map<String, int> geierGames = {};
    final Map<String, int> geierWins = {};
    final Map<String, int> farbspielGames = {};
    final Map<String, int> farbspielWins = {};
    final Map<String, int> totalRamschGames = {};
    final Map<String, int> ramschSurvivals = {};

    // Initialize maps for all players
    for (final playerStat in statistics.playerStats.values) {
      final playerName = playerStat.name;
      sauspielGames[playerName] = 0;
      sauspielWins[playerName] = 0;
      wenzGames[playerName] = 0;
      wenzWins[playerName] = 0;
      soloGames[playerName] = 0;
      soloWins[playerName] = 0;
      ramschLosses[playerName] = 0;
      kontraGames[playerName] = 0;
      kontraWins[playerName] = 0;
      soloEarnings[playerName] = 0.0;
      geierGames[playerName] = 0;
      geierWins[playerName] = 0;
      farbspielGames[playerName] = 0;
      farbspielWins[playerName] = 0;
      totalRamschGames[playerName] = 0;
      ramschSurvivals[playerName] = 0;
    }

    // Calculate statistics from sessions
    for (final session in statistics.sessions) {
      for (final round in session.rounds) {
        final mainPlayer = round.mainPlayer;
        
        switch (round.gameType) {
          case GameType.sauspiel:
            if (mainPlayer != null) {
              sauspielGames[mainPlayer] = (sauspielGames[mainPlayer] ?? 0) + 1;
              if (round.isWon) {
                sauspielWins[mainPlayer] = (sauspielWins[mainPlayer] ?? 0) + 1;
              }
            }
            break;
            
          case GameType.wenz:
          case GameType.farbwenz:
            if (mainPlayer != null) {
              wenzGames[mainPlayer] = (wenzGames[mainPlayer] ?? 0) + 1;
              if (round.isWon) {
                wenzWins[mainPlayer] = (wenzWins[mainPlayer] ?? 0) + 1;
              }
            }
            break;
            
          case GameType.geier:
          case GameType.farbgeier:
            if (mainPlayer != null) {
              geierGames[mainPlayer] = (geierGames[mainPlayer] ?? 0) + 1;
              if (round.isWon) {
                geierWins[mainPlayer] = (geierWins[mainPlayer] ?? 0) + 1;
              }
            }
            break;
            
          case GameType.farbspiel:
            if (mainPlayer != null) {
              farbspielGames[mainPlayer] = (farbspielGames[mainPlayer] ?? 0) + 1;
              if (round.isWon) {
                farbspielWins[mainPlayer] = (farbspielWins[mainPlayer] ?? 0) + 1;
              }
            }
            break;
            
          case GameType.ramsch:
            if (mainPlayer != null) {
              ramschLosses[mainPlayer] = (ramschLosses[mainPlayer] ?? 0) + 1;
            }
            for (final player in session.players) {
              totalRamschGames[player] = (totalRamschGames[player] ?? 0) + 1;
              
              if (player != round.mainPlayer) {
                ramschSurvivals[player] = (ramschSurvivals[player] ?? 0) + 1;
              }
            }
            break;
        }

        // Calculate solo statistics
        if (round.gameType.isSolo && mainPlayer != null) {
          soloGames[mainPlayer] = (soloGames[mainPlayer] ?? 0) + 1;
          if (round.isWon) {
            soloWins[mainPlayer] = (soloWins[mainPlayer] ?? 0) + 1;
            soloEarnings[mainPlayer] = (soloEarnings[mainPlayer] ?? 0) + round.value;
          }
        }
      }
    }

    // Calculate win rates and create rankings
    final Map<String, double> sauspielStats = {};
    final Map<String, double> wenzStats = {};
    final Map<String, double> soloStats = {};
    final Map<String, double> kontraStats = {};
    final Map<String, double> geierStats = {};
    final Map<String, double> farbspielStats = {};
    final Map<String, double> ramschSurvivalRates = {};

    for (final playerName in statistics.playerStats.keys) {
      // Calculate Sauspiel win rate
      if (sauspielGames[playerName]! > 0) {
        sauspielStats[playerName] = sauspielWins[playerName]! / sauspielGames[playerName]!;
      }
      
      // Calculate Wenz win rate
      if (wenzGames[playerName]! > 0) {
        wenzStats[playerName] = wenzWins[playerName]! / wenzGames[playerName]!;
      }
      
      // Calculate Solo win rate
      if (soloGames[playerName]! > 0) {
        soloStats[playerName] = soloWins[playerName]! / soloGames[playerName]!;
      }
      
      // Calculate Geier win rate
      if (geierGames[playerName]! > 0) {
        geierStats[playerName] = geierWins[playerName]! / geierGames[playerName]!;
      }
      
      // Calculate Farbspiel win rate
      if (farbspielGames[playerName]! > 0) {
        farbspielStats[playerName] = farbspielWins[playerName]! / farbspielGames[playerName]!;
      }
      
      if (totalRamschGames[playerName]! >= 5) {  // Minimum 5 games to qualify
        ramschSurvivalRates[playerName] = ramschSurvivals[playerName]! / totalRamschGames[playerName]!;
      }
    }

    // Create rankings
    return Rankings(
      bestSauspielPlayers: getTop3Safe(sauspielStats),
      bestWenzPlayers: getTop3Safe(wenzStats),
      bestSoloPlayers: getTop3Safe(soloStats),
      leastRamschLosses: getTop3Safe(ramschSurvivalRates),
      bestKontraPlayers: getTop3Safe(kontraStats),
      highestSoloEarnings: getTop3Safe(soloEarnings),
      bestGeierPlayers: getTop3Safe(geierStats),
      bestFarbspielPlayers: getTop3Safe(farbspielStats),
    );
  }

  static List<PlayerRanking> getTop3Safe(Map<String, double> stats) {
    if (stats.isEmpty) return [];
    
    final sorted = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    return sorted.take(3).map((e) => PlayerRanking(
      name: e.key,
      value: e.value,
    )).toList();
  }
} 