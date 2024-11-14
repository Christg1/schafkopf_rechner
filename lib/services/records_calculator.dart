import 'dart:math';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/screens/statistics_screen.dart';

import '../models/statistics_data.dart';
import '../models/session.dart';
import '../models/game_types.dart';
import '../models/game_round.dart';

class RecordsCalculator {
  static List<GameRecord> calculateRecords(List<Session> sessions) {
    final records = <GameRecord>[];
    
    // Highest Single Win for an active player
    GameRound? highestWin;
    Session? highestWinSession;
    for (final session in sessions) {
      for (final round in session.rounds) {
        // Only consider non-Ramsch games where the player won
        if (round.gameType != GameType.ramsch && round.isWon) {
          double actualWinAmount = round.value * (session.players.length - 1);
          if (highestWin == null || actualWinAmount > (highestWin.value * (highestWinSession!.players.length - 1))) {
            highestWin = round;
            highestWinSession = session;
          }
        }
      }
    }
    
    if (highestWin != null && highestWinSession != null) {
      records.add(GameRecord(
        type: RecordType.highestSingleWin,
        player: highestWin.mainPlayer,
        value: highestWin.value * (highestWinSession.players.length - 1),
        additionalInfo: highestWin.gameType.displayName,
      ));
    }

    // Most Valuable Streak
    Map<String, List<double>> playerStreaks = {};
    for (final session in sessions) {
      for (final round in session.rounds) {
        playerStreaks.putIfAbsent(round.mainPlayer, () => []);
        playerStreaks[round.mainPlayer]!.add(
          (round.isWon ? round.value : -round.value) * (session.players.length - 1)
        );
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

    // Longest Win Streak
    Map<String, int> currentStreaks = {};
    Map<String, int> maxStreaks = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        // Main player
        if (round.isWon) {
          currentStreaks[round.mainPlayer] = (currentStreaks[round.mainPlayer] ?? 0) + 1;
          maxStreaks[round.mainPlayer] = max(
            maxStreaks[round.mainPlayer] ?? 0,
            currentStreaks[round.mainPlayer]!
          );
        } else {
          currentStreaks[round.mainPlayer] = 0;
        }

        // Partner in team games (Sauspiel)
        if (round.partner != null && round.isWon) {
          currentStreaks[round.partner!] = (currentStreaks[round.partner!] ?? 0) + 1;
          maxStreaks[round.partner!] = max(
            maxStreaks[round.partner!] ?? 0,
            currentStreaks[round.partner!]!
          );
        } else if (round.partner != null) {
          currentStreaks[round.partner!] = 0;
        }

        // Defenders in solo games
        if (round.gameType.isSolo) {
          for (final player in session.players) {
            if (player != round.mainPlayer) {
              if (!round.isWon) { // Solo player lost = defenders won
                currentStreaks[player] = (currentStreaks[player] ?? 0) + 1;
                maxStreaks[player] = max(
                  maxStreaks[player] ?? 0,
                  currentStreaks[player]!
                );
              } else { // Solo player won = defenders lost
                currentStreaks[player] = 0;
              }
            }
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

    // Biggest Comeback (lowest balance before ending positive)
    double biggestComeback = 0;
    String comebackPlayer = '';
    
    for (final session in sessions) {
      Map<String, double> runningBalances = {};
      Map<String, double> lowestBalances = {};
      
      // Initialize balances
      for (final player in session.players) {
        runningBalances[player] = 0;
        lowestBalances[player] = 0;
      }
      
      // Track running balances and record lowest points
      for (final round in session.rounds) {
        // Calculate round earnings for each player
        if (round.gameType == GameType.ramsch) {
          // In Ramsch, mainPlayer is the loser
          runningBalances[round.mainPlayer] = (runningBalances[round.mainPlayer] ?? 0) - round.value;
        } else {
          // Normal game
          if (round.isWon) {
            // Main player (and partner in Sauspiel) won
            runningBalances[round.mainPlayer] = (runningBalances[round.mainPlayer] ?? 0) + round.value;
            if (round.partner != null) {
              runningBalances[round.partner!] = (runningBalances[round.partner!] ?? 0) + round.value;
            }
          } else {
            // Main player (and partner in Sauspiel) lost
            runningBalances[round.mainPlayer] = (runningBalances[round.mainPlayer] ?? 0) - round.value;
            if (round.partner != null) {
              runningBalances[round.partner!] = (runningBalances[round.partner!] ?? 0) - round.value;
            }
          }
        }
        
        // Update lowest balances for all players
        for (final player in session.players) {
          lowestBalances[player] = min(
            lowestBalances[player] ?? 0,
            runningBalances[player] ?? 0
          );
        }
      }
      
      // Check if anyone made a comeback (ended positive after being negative)
      for (final entry in session.playerBalances.entries) {
        if (entry.value > 0 && lowestBalances[entry.key]! < biggestComeback) {
          biggestComeback = lowestBalances[entry.key]!;
          comebackPlayer = entry.key;
        }
      }
    }

    if (comebackPlayer.isNotEmpty) {
      records.add(GameRecord(
        type: RecordType.biggestComeback,
        player: comebackPlayer,
        value: -biggestComeback,  // Make positive for display
        additionalInfo: 'Von ${biggestComeback.toStringAsFixed(2)}€ auf Plus',
      ));
    }

    // Most Games in Session
    int mostGamesInSession = 0;
    String mostGamesSessionDate = '';
    
    for (final session in sessions) {
      if (session.rounds.length > mostGamesInSession) {
        mostGamesInSession = session.rounds.length;
        mostGamesSessionDate = DateFormat('dd.MM.yyyy').format(session.date);
      }
    }

    if (mostGamesInSession > 0) {
      records.add(GameRecord(
        type: RecordType.mostGamesInSession,
        player: mostGamesSessionDate,
        value: mostGamesInSession.toDouble(),
        additionalInfo: '$mostGamesInSession Spiele',
      ));
    }

    // Highest Daily Volume
    Map<String, double> dailyVolumes = {};
    
    for (final session in sessions) {
      String date = DateFormat('dd.MM.yyyy').format(session.date);
      double volume = session.rounds.fold(0.0, (sum, round) => 
          sum + (round.value * (session.players.length - 1)));
      dailyVolumes[date] = (dailyVolumes[date] ?? 0) + volume;
    }

    if (dailyVolumes.isNotEmpty) {
      final highestVolume = dailyVolumes.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.highestDailyVolume,
        player: highestVolume.key,
        value: highestVolume.value,
        additionalInfo: '${highestVolume.value.toStringAsFixed(2)}€',
      ));
    }

    // Best Win Rate (minimum 10 games)
    Map<String, WinRateStats> winRates = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.gameType == GameType.ramsch) {
          // Skip Ramsch games for win rate calculation
          continue;
        }

        // Initialize stats for all players if needed
        for (final player in session.players) {
          winRates.putIfAbsent(player, () => WinRateStats());
        }

        if (round.gameType.isSolo) {
          // Solo game
          final mainStats = winRates[round.mainPlayer]!;
          mainStats.total++;
          if (round.isWon) mainStats.wins++;

          // Defenders
          for (final player in session.players) {
            if (player != round.mainPlayer) {
              final defenderStats = winRates[player]!;
              defenderStats.total++;
              if (!round.isWon) defenderStats.wins++;
            }
          }
        } else {
          // Sauspiel
          final mainStats = winRates[round.mainPlayer]!;
          mainStats.total++;
          if (round.isWon) mainStats.wins++;

          if (round.partner != null) {
            final partnerStats = winRates[round.partner!]!;
            partnerStats.total++;
            if (round.isWon) partnerStats.wins++;

            // Defenders (other two players)
            for (final player in session.players) {
              if (player != round.mainPlayer && player != round.partner) {
                final defenderStats = winRates[player]!;
                defenderStats.total++;
                if (!round.isWon) defenderStats.wins++;
              }
            }
          }
        }
      }
    }

    // Find best win rate (minimum 10 games)
    double bestRate = 0;
    String bestPlayer = '';
    
    for (final entry in winRates.entries) {
      if (entry.value.total >= 10) {
        final rate = entry.value.wins / entry.value.total;
        if (rate > bestRate) {
          bestRate = rate;
          bestPlayer = entry.key;
        }
      }
    }

    if (bestPlayer.isNotEmpty) {
      records.add(GameRecord(
        type: RecordType.bestWinRate,
        player: bestPlayer,
        value: bestRate,
        additionalInfo: '${winRates[bestPlayer]!.wins}/${winRates[bestPlayer]!.total} Spiele',
      ));
    }

    // Highest Average Earnings (minimum 10 games)
    Map<String, double> totalEarnings = {};
    Map<String, int> gamesCount = {};
    
    for (final session in sessions) {
      // Initialize counters for all players in the session
      for (final player in session.players) {
        totalEarnings.putIfAbsent(player, () => 0);
        gamesCount.putIfAbsent(player, () => 0);
      }

      // Add final session balances
      for (final entry in session.playerBalances.entries) {
        totalEarnings[entry.key] = (totalEarnings[entry.key] ?? 0) + entry.value;
      }

      // Count total games played
      for (final round in session.rounds) {
        // Count for all players in the game
        for (final player in session.players) {
          gamesCount[player] = (gamesCount[player] ?? 0) + 1;
        }
      }
    }

    double bestAverage = 0;
    String bestAveragePlayer = '';
    
    for (final player in totalEarnings.keys) {
      if (gamesCount[player]! >= 5) {  // Lowered minimum to 5 games
        double average = totalEarnings[player]! / gamesCount[player]!;
        if (average > bestAverage) {
          bestAverage = average;
          bestAveragePlayer = player;
        }
      }
    }

    if (bestAverage > 0) {
      records.add(GameRecord(
        type: RecordType.highestAverageEarnings,
        player: bestAveragePlayer,
        value: bestAverage,
        additionalInfo: '${bestAverage.toStringAsFixed(2)}€ pro Spiel',
      ));
    }

    // Most Consistent Player (lowest standard deviation in earnings, minimum 5 games)
    Map<String, List<double>> playerEarnings = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        playerEarnings.putIfAbsent(round.mainPlayer, () => []);
        playerEarnings[round.mainPlayer]!.add(round.isWon ? round.value : -round.value);
      }
    }

    double lowestDeviation = double.infinity;
    String mostConsistentPlayer = '';
    double consistentPlayerAvg = 0;
    
    for (final entry in playerEarnings.entries) {
      if (entry.value.length >= 5) {
        double avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
        double variance = entry.value.map((x) => pow(x - avg, 2)).reduce((a, b) => a + b) / entry.value.length;
        double stdDev = sqrt(variance);
        
        if (stdDev < lowestDeviation) {
          lowestDeviation = stdDev;
          mostConsistentPlayer = entry.key;
          consistentPlayerAvg = avg;
        }
      }
    }

    if (lowestDeviation != double.infinity) {
      records.add(GameRecord(
        type: RecordType.mostConsistentPlayer,
        player: mostConsistentPlayer,
        value: consistentPlayerAvg,
        additionalInfo: '±${lowestDeviation.toStringAsFixed(0)} Abweichung',
      ));
    }

    // Most Games Played
    final gamesPlayed = <String, int>{};
    for (final session in sessions) {
      for (final round in session.rounds) {
        gamesPlayed[round.mainPlayer] = (gamesPlayed[round.mainPlayer] ?? 0) + 1;
      }
    }
    
    if (gamesPlayed.isNotEmpty) {
      final mostGames = gamesPlayed.entries.reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.mostGamesPlayed,
        player: mostGames.key,
        value: mostGames.value.toDouble(),
        additionalInfo: '${mostGames.value} Spiele',
      ));
    }

    // Most Solo Games
    Map<String, int> soloGames = {};
    Map<String, int> soloWins = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.gameType.isSolo) {
          soloGames[round.mainPlayer] = (soloGames[round.mainPlayer] ?? 0) + 1;
          if (round.isWon) {
            soloWins[round.mainPlayer] = (soloWins[round.mainPlayer] ?? 0) + 1;
          }
        }
      }
    }

    if (soloGames.isNotEmpty) {
      final mostSolos = soloGames.entries.reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.mostSoloGames,
        player: mostSolos.key,
        value: mostSolos.value.toDouble(),
        additionalInfo: '${soloWins[mostSolos.key] ?? 0} gewonnen',
      ));
    }

    // Most Ramsch Losses
    Map<String, int> ramschLosses = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.gameType == GameType.ramsch && !round.isWon) {
          ramschLosses[round.mainPlayer] = (ramschLosses[round.mainPlayer] ?? 0) + 1;
        }
      }
    }

    if (ramschLosses.isNotEmpty) {
      final mostLosses = ramschLosses.entries.reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.mostRamschLosses,
        player: mostLosses.key,
        value: mostLosses.value.toDouble(),
        additionalInfo: '${mostLosses.value} Ramsche verloren',
      ));
    }

    // Worst Loss Streak
    Map<String, int> currentLossStreaks = {};
    Map<String, int> worstLossStreaks = {};
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        // Check main player
        if (!round.isWon) {
          currentLossStreaks[round.mainPlayer] = (currentLossStreaks[round.mainPlayer] ?? 0) + 1;
          worstLossStreaks[round.mainPlayer] = max(
            worstLossStreaks[round.mainPlayer] ?? 0,
            currentLossStreaks[round.mainPlayer]!
          );
        } else {
          currentLossStreaks[round.mainPlayer] = 0;
        }

        // Check partner in team games
        if (round.partner != null) {
          if (!round.isWon) {
            currentLossStreaks[round.partner!] = (currentLossStreaks[round.partner!] ?? 0) + 1;
            worstLossStreaks[round.partner!] = max(
              worstLossStreaks[round.partner!] ?? 0,
              currentLossStreaks[round.partner!]!
            );
          } else {
            currentLossStreaks[round.partner!] = 0;
          }
        }

        // Check defenders in solo games
        if (round.gameType.isSolo) {
          for (final player in session.players) {
            if (player != round.mainPlayer) {
              if (round.isWon) { // Solo player won, defenders lost
                currentLossStreaks[player] = (currentLossStreaks[player] ?? 0) + 1;
                worstLossStreaks[player] = max(
                  worstLossStreaks[player] ?? 0,
                  currentLossStreaks[player]!
                );
              } else { // Solo player lost, defenders won
                currentLossStreaks[player] = 0;
              }
            }
          }
        }
      }
    }

    if (worstLossStreaks.isNotEmpty) {
      final worstStreak = worstLossStreaks.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      records.add(GameRecord(
        type: RecordType.worstLossStreak,
        player: worstStreak.key,
        value: worstStreak.value.toDouble(),
        additionalInfo: '${worstStreak.value} Niederlagen in Folge',
      ));
    }

    // Best Team Player (Sauspiel games only)
    Map<String, int> sauspielGames = {};
    Map<String, int> sauspielWins = {};
    Map<String, double> sauspielEarnings = {};

    for (final session in sessions) {
      for (final round in session.rounds) {
        if (round.gameType == GameType.sauspiel) {
          // Track main player
          sauspielGames[round.mainPlayer] = (sauspielGames[round.mainPlayer] ?? 0) + 1;
          sauspielEarnings[round.mainPlayer] = (sauspielEarnings[round.mainPlayer] ?? 0) + 
              (round.isWon ? round.value : -round.value) * (session.players.length - 1);
          if (round.isWon) {
            sauspielWins[round.mainPlayer] = (sauspielWins[round.mainPlayer] ?? 0) + 1;
          }

          // Track partner
          if (round.partner != null) {
            sauspielGames[round.partner!] = (sauspielGames[round.partner!] ?? 0) + 1;
            sauspielEarnings[round.partner!] = (sauspielEarnings[round.partner!] ?? 0) + 
                (round.isWon ? round.value : -round.value) * (session.players.length - 1);
            if (round.isWon) {
              sauspielWins[round.partner!] = (sauspielWins[round.partner!] ?? 0) + 1;
            }
          }
        }
      }
    }

    // Calculate average earnings per Sauspiel game
    Map<String, double> sauspielAvgEarnings = {};
    for (final player in sauspielGames.keys) {
      if (sauspielGames[player]! >= 5) {  // Minimum 5 games
        sauspielAvgEarnings[player] = sauspielEarnings[player]! / sauspielGames[player]!;
      }
    }

    if (sauspielAvgEarnings.isNotEmpty) {
      final bestTeamPlayer = sauspielGames.entries
          .where((e) => sauspielGames[e.key]! >= 5)  // Minimum 5 games
          .map((e) => MapEntry(
            e.key,
            sauspielWins[e.key]! / sauspielGames[e.key]!  // Calculate win rate
          ))
          .reduce((a, b) => a.value > b.value ? a : b);
      
      records.add(GameRecord(
        type: RecordType.bestTeamPlayer,
        player: bestTeamPlayer.key,
        value: bestTeamPlayer.value * 100,  // Store as percentage
        additionalInfo: '${sauspielGames[bestTeamPlayer.key]} Sauspiele gespielt',
      ));
    }

    return records;
  }
} 