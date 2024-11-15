import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/models/game_types.dart';
import 'package:schafkopf_rechner/models/player.dart';
import 'package:schafkopf_rechner/models/session.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:schafkopf_rechner/models/statistics_data.dart';
import 'package:schafkopf_rechner/widgets/loading_indicator.dart';
import 'package:schafkopf_rechner/screens/session_details_screen.dart';
import 'package:schafkopf_rechner/services/statistics_service.dart';
import 'package:schafkopf_rechner/widgets/balance_history_chart.dart';
import 'package:schafkopf_rechner/widgets/game_type_distribution_chart.dart';
import 'package:schafkopf_rechner/widgets/average_game_value_chart.dart';
import 'package:schafkopf_rechner/services/rankings_calculator.dart';
import '../models/game_round.dart';
import '../models/game_types.dart';
import '../models/session.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiken'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Spieler'),
              Tab(text: 'Sessions'),
              Tab(text: 'Rekorde'),
              Tab(text: 'Bestenlisten'),
              Tab(text: 'Verlauf'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: 20,
              child: Opacity(
                opacity: 0.1,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Image.asset(
                    'assets/images/eichel.png',
                    width: 100,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                  ),
                ),
              ),
            ),
            StreamBuilder<StatisticsData>(
              stream: StatisticsService().getStatisticsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CustomLoadingIndicator();
                }

                final stats = snapshot.data!;
                
                return TabBarView(
                  children: [
                    _PlayersTab(statistics: stats),
                    _SessionsTab(statistics: stats),
                    _RecordsTab(statistics: stats),
                    _BestenlistenTab(statistics: stats),
                    _VerlaufTab(statistics: stats),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final StatisticsData statistics;

  const _PlayersTab({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = statistics.playerStats.entries.toList()
      ..sort((a, b) => b.value.totalEarnings.compareTo(a.value.totalEarnings));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedPlayers.length,
      itemBuilder: (context, index) {
        final player = sortedPlayers[index];
        final isPositive = player.value.totalEarnings >= 0;
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPlayerRankColor(index),
              child: Text(
                _getPlayerRankEmoji(index),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            title: Text(
              player.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${player.value.gamesParticipated} Spiele gespielt',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  '${player.value.totalEarnings.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            onTap: () => _showPlayerDetails(context, player.key, player.value),
          ),
        );
      },
    );
  }

  String _getPlayerRankEmoji(int rank) {
    switch (rank) {
      case 0: return '🥇';
      case 1: return '🥈';
      case 2: return '🥉';
      default: return '${rank + 1}';
    }
  }

  Color _getPlayerRankColor(int rank) {
    switch (rank) {
      case 0: return Colors.amber;
      case 1: return Colors.grey.shade300;
      case 2: return Colors.brown.shade300;
      default: return Colors.grey.shade100;
    }
  }

  void _showPlayerDetails(BuildContext context, String playerName, PlayerStatistics playerStats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => PlayerDetailsSheet(
          playerName: playerName,
          playerStats: playerStats,
          statistics: statistics,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class PlayerDetailsSheet extends StatelessWidget {
  final String playerName;
  final PlayerStatistics playerStats;
  final StatisticsData statistics;
  final ScrollController scrollController;

  const PlayerDetailsSheet({
    super.key,
    required this.playerName,
    required this.playerStats,
    required this.statistics,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              playerName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildGeneralStats(context),
                const SizedBox(height: 16),
                _buildGameTypeStats(context),
                const SizedBox(height: 16),
                _buildWinRates(context),
                const SizedBox(height: 16),
                _buildRecentGames(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralStats(BuildContext context) {
    // Calculate average earnings per participated game (excluding Ramsch)
    final averageEarnings = playerStats.gamesParticipated > 0 
        ? playerStats.totalEarnings / playerStats.gamesParticipated 
        : 0.0;

    // Calculate actively played games (excluding Ramsch)
    int activeGames = 0;
    int activeWins = 0;
    
    for (final session in statistics.sessions) {
      for (final round in session.rounds) {
        if (round.mainPlayer == playerName && round.gameType != GameType.ramsch) {
          activeGames++;
          if (round.isWon) activeWins++;
        }
      }
    }

    final winRate = activeGames > 0 ? (activeWins / activeGames) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allgemeine Statistiken',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              context,
              'Teilgenommene Spiele',
              playerStats.gamesParticipated.toString(),
              Icons.groups,
            ),
            _buildStatRow(
              context,
              'Aktiv gespielt',
              activeGames.toString(),
              Icons.person,
            ),
            _buildStatRow(
              context,
              'Davon gewonnen',
              activeWins.toString(),
              Icons.emoji_events,
            ),
            _buildStatRow(
              context,
              'Gewinnrate',
              '${(winRate * 100).toStringAsFixed(1)}%',
              Icons.percent,
            ),
            _buildStatRow(
              context,
              'Durchschn. Gewinn/Spiel',
              '${averageEarnings.toStringAsFixed(2)}€',
              Icons.euro,
            ),
            _buildStatRow(
              context,
              'Gesamtgewinn',
              '${playerStats.totalEarnings.toStringAsFixed(2)}€',
              Icons.account_balance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTypeStats(BuildContext context) {
    Map<GameType, int> gameTypeCounts = {};
    
    for (final session in statistics.sessions) {
      for (final round in session.rounds) {
        if (round.gameType == GameType.ramsch) {
          // For Ramsch, count if player was in the session
          if (session.players.contains(playerName)) {
            gameTypeCounts[GameType.ramsch] = (gameTypeCounts[GameType.ramsch] ?? 0) + 1;
          }
        } else {
          // For other games, count if player was main player
          if (round.mainPlayer == playerName) {
            gameTypeCounts[round.gameType] = (gameTypeCounts[round.gameType] ?? 0) + 1;
          }
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spieltypen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...GameType.values.map((type) {
              final count = gameTypeCounts[type] ?? 0;
              if (count == 0) return const SizedBox.shrink(); // Hide unused game types
              return ListTile(
                leading: Text(
                  type.emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(type.displayName),
                trailing: Text('${count}x'),
              );
            }).where((widget) => widget is ListTile), // Remove empty widgets
          ],
        ),
      ),
    );
  }

  Widget _buildWinRates(BuildContext context) {
    // Calculate win rates per game type
    Map<GameType, WinRateStats> winRates = {};
    
    for (final session in statistics.sessions) {
      for (final round in session.rounds) {
        if (round.mainPlayer == playerName) {
          winRates.putIfAbsent(round.gameType, () => WinRateStats());
          winRates[round.gameType]!.total++;
          if (round.isWon) winRates[round.gameType]!.wins++;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gewinnraten nach Spieltyp',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...winRates.entries
                .where((e) => e.value.total > 0)  // Only show played game types
                .map((entry) {
              final winRate = (entry.value.wins / entry.value.total) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      entry.key.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${entry.value.wins}/${entry.value.total} gewonnen',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 80,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${winRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getWinRateColor(winRate),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getWinRateColor(double winRate) {
    if (winRate >= 60) return Colors.green;
    if (winRate >= 45) return Colors.orange;
    return Colors.red;
  }

  Widget _buildRecentGames(BuildContext context) {
    // Get last 10 games where player participated
    final recentGames = statistics.sessions
        .expand((s) => s.rounds.map((r) => (session: s, round: r)))
        .where((pair) => pair.round.gameType == GameType.ramsch 
            ? pair.session.players.contains(playerName)  // For Ramsch, check session participation
            : pair.round.mainPlayer == playerName)      // For other games, check main player
        .toList()
        .reversed
        .take(10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Letzte Spiele',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...recentGames.map((pair) => ListTile(
              leading: Text(
                pair.round.gameType.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(pair.round.gameType.displayName),
              subtitle: pair.round.gameType == GameType.sauspiel
                  ? Text('Partner: ${pair.round.partner}')
                  : pair.round.gameType == GameType.ramsch
                      ? Text('Spieler: ${pair.session.players.join(", ")}')
                      : null,
              trailing: Text(
                '${pair.round.isWon ? "+" : "-"}${(pair.round.value * (pair.session.players.length - 1)).toStringAsFixed(2)}€',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pair.round.isWon ? Colors.green : Colors.red,
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getGameTypeColor(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return Colors.blue;
      case GameType.wenz:
        return Colors.red;
      case GameType.farbwenz:
        return Colors.orange;
      case GameType.geier:
        return Colors.green;
      case GameType.farbgeier:
        return Colors.teal;
      case GameType.farbspiel:
        return Colors.purple;
      case GameType.ramsch:
        return Colors.brown;
    }
  }
}

class _SessionsTab extends StatelessWidget {
  final StatisticsData statistics;

  const _SessionsTab({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final sortedSessions = statistics.sessions.toList()
      ..sort((b, a) => a.date.compareTo(b.date));  // Newest first

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedSessions.length,
      itemBuilder: (context, index) {
        final session = sortedSessions[index];
        return Card(
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd.MM').format(session.date),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('yyyy').format(session.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            title: Text('${session.rounds.length} Spiele'),
            subtitle: Text(session.players.join(', ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSessionDetails(context, session),
          ),
        );
      },
    );
  }

  void _showSessionDetails(BuildContext context, Session session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SessionDetailsSheet(
          session: session,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class SessionDetailsSheet extends StatelessWidget {
  final Session session;
  final ScrollController scrollController;

  const SessionDetailsSheet({
    super.key,
    required this.session,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Session vom ${DateFormat('dd.MM.yyyy').format(session.date)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildSessionStats(context),
                const SizedBox(height: 16),
                _buildPlayerBalances(context),
                const SizedBox(height: 16),
                _buildGamesList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats(BuildContext context) {
    final gameTypes = session.rounds.fold<Map<GameType, int>>(
      {},
      (map, round) {
        map[round.gameType] = (map[round.gameType] ?? 0) + 1;
        return map;
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiken',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Anzahl Spiele: ${session.rounds.length}'),
            Text('Spieler: ${session.players.join(", ")}'),
            const SizedBox(height: 8),
            Text('Gespielte Spiele:'),
            ...gameTypes.entries.map((e) => Text(
              '${e.key.displayName}: ${e.value}x',
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBalances(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spielstand',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...session.playerBalances.entries.map((e) {
              final isPositive = e.value >= 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Text(
                      '${e.value.toStringAsFixed(2)}€',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGamesList(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spiele',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...session.rounds.asMap().entries.map((entry) {
              final round = entry.value;
              return Column(
                children: [
                  if (entry.key > 0) const Divider(),
                  ExpansionTile(
                    leading: Text(
                      round.gameType.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Row(
                      children: [
                        Text(
                          round.gameType.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(round.gameType == GameType.sauspiel 
                              ? round.value * 2  // For Sauspiel: multiply by 2 (both teams)
                              : round.value * (session.players.length - 1)  // For other games: multiply by number of players minus 1
                          ).toStringAsFixed(2)}€',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: _buildGameSubtitle(round),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (round.gameType != GameType.ramsch) ...[
                              Text(
                                'Spieler:',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    round.isWon ? Icons.emoji_events : Icons.close,
                                    color: round.isWon ? Colors.amber : Colors.red,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    round.mainPlayer ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (round.gameType == GameType.sauspiel && round.partner != null) ...[
                                    const Text(' mit '),
                                    Text(
                                      round.partner!,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Kontostand nach dem Spiel:',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            ...session.players.map((player) {
                              // Get the running balance up to this round
                              final runningSession = Session(
                                id: session.id,
                                players: session.players,
                                baseValue: session.baseValue,
                                rounds: session.rounds.sublist(0, entry.key + 1),
                                currentDealer: session.currentDealer,
                                isActive: session.isActive,
                                date: session.date,
                              );
                              
                              final balance = runningSession.playerBalances[player] ?? 0;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(player),
                                    Text(
                                      '${balance.toStringAsFixed(2)}€',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: balance >= 0 ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildGameSubtitle(GameRound round) {
    if (round.gameType == GameType.ramsch) {
      return const Text('Ramsch');
    } else if (round.gameType == GameType.sauspiel) {
      return Text('${round.mainPlayer} mit ${round.partner}');
    } else {
      return Text('Spieler: ${round.mainPlayer}');
    }
  }
}

class _RecordsTab extends StatelessWidget {
  final StatisticsData statistics;

  const _RecordsTab({required this.statistics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRecordSection('🏆 Allgemeine Rekorde', [
          RecordType.highestSingleWin,
          RecordType.biggestComeback,
          RecordType.mostValuableStreak,
          RecordType.bestWinRate,
        ]),
        _buildRecordSection('📈 Spielstatistiken', [
          RecordType.mostGamesPlayed,
          RecordType.longestStreak,
          RecordType.highestAverageEarnings,
          RecordType.mostConsistentPlayer,
        ]),
        _buildRecordSection('🎮 Spieltypen', [
          RecordType.mostSoloGames,
          RecordType.bestSoloWinRate,
          RecordType.mostRamschLosses,
          RecordType.bestTeamPlayer,
        ]),
        _buildRecordSection('⏱️ Zeitliche Rekorde', [
          RecordType.mostGamesInSession,
          RecordType.highestDailyVolume,
          RecordType.worstLossStreak,
        ]),
      ],
    );
  }

  Widget _buildRecordSection(String title, List<RecordType> recordTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...recordTypes.map((type) {
          final record = statistics.records.firstWhere(
            (r) => r.type == type,
            orElse: () => GameRecord(
              player: '-',
              value: 0,
              type: type,
            ),
          );
          return _buildRecordTile(record);
        }),
      ],
    );
  }

  Widget _buildRecordTile(GameRecord record) {
    return Card(
      child: ListTile(
        leading: Text(
          _getRecordEmoji(record.type),
          style: const TextStyle(fontSize: 24),
        ),
        title: Text(_getRecordTitle(record.type)),
        subtitle: Text(record.player),
        trailing: Text(
          _formatValue(record),
          style: TextStyle(
            color: _getValueColor(record),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getRecordEmoji(RecordType type) {
    switch (type) {
      case RecordType.mostValuableStreak: return '🔥';
      case RecordType.longestStreak: return '📈';
      case RecordType.highestSingleWin: return '💰';
      case RecordType.biggestComeback: return '🔄';
      case RecordType.mostGamesInSession: return '🎮';
   
      case RecordType.highestDailyVolume: return '📊';
      case RecordType.bestWinRate: return '🎯';
      case RecordType.mostGamesPlayed: return '🏃';
      case RecordType.highestAverageEarnings: return '💎';
      case RecordType.mostSoloGames: return '🃏';
      case RecordType.bestSoloWinRate: return '👑';
      case RecordType.mostRamschLosses: return '😅';
      case RecordType.bestTeamPlayer: return '🤝';
      case RecordType.worstLossStreak: return '📉';
      case RecordType.mostConsistentPlayer: return '🎖️';
     
        // TODO: Handle this case.
    }
  }

  String _getRecordTitle(RecordType type) {
    switch (type) {
      case RecordType.mostValuableStreak: return 'Höchste Gewinnserie';
      case RecordType.longestStreak: return 'Längste Siegesserie';
      case RecordType.highestSingleWin: return 'Höchster Einzelgewinn';
      case RecordType.biggestComeback: return 'Größtes Comeback';
      case RecordType.mostGamesInSession: return 'Meiste Spiele in einer Session';

      case RecordType.highestDailyVolume: return 'Höchster Tagesumsatz';
      case RecordType.bestWinRate: return 'Beste Gewinnrate';
      case RecordType.mostGamesPlayed: return 'Meiste Spiele';
      case RecordType.highestAverageEarnings: return 'Höchster Durchschnittsgewinn';
      case RecordType.mostSoloGames: return 'Meiste Solo-Spiele';
      case RecordType.bestSoloWinRate: return 'Beste Solo-Gewinnrate';
      case RecordType.mostRamschLosses: return 'Meiste Ramsch-Verluste';
      case RecordType.bestTeamPlayer: return 'Bester Teamplayer';
      case RecordType.worstLossStreak: return 'Längste Verlustserie';
      case RecordType.mostConsistentPlayer: return 'Konstantester Spieler';
     
        // TODO: Handle this case.
    }
  }

  String _formatValue(GameRecord record) {
    switch (record.type) {
      case RecordType.mostGamesInSession:
      case RecordType.mostGamesPlayed:
      case RecordType.mostSoloGames:
      case RecordType.mostRamschLosses:
      case RecordType.longestStreak:
      case RecordType.worstLossStreak:
      case RecordType.mostConsistentPlayer:
        return record.value.toStringAsFixed(0);  // Just the number
      case RecordType.highestDailyVolume:
        return '${record.value.toStringAsFixed(2)}€';  // Money format
      case RecordType.bestWinRate:
        return '${(record.value * 100).toStringAsFixed(1)}%';  // Convert to percentage
      case RecordType.bestSoloWinRate:
        return '${(record.value * 100).toStringAsFixed(1)}%';
      default:
        return '${record.value.toStringAsFixed(2)}€';
    }
  }

  Color _getValueColor(GameRecord record) {
    switch (record.type) {
      case RecordType.mostValuableStreak: return Colors.blue;
      case RecordType.longestStreak: return Colors.green;
      case RecordType.highestSingleWin: return Colors.red;
      case RecordType.biggestComeback: return Colors.orange;
      case RecordType.mostGamesInSession: return Colors.purple;

      case RecordType.highestDailyVolume: return Colors.cyan;
      case RecordType.bestWinRate: return Colors.lime;
      case RecordType.mostGamesPlayed: return Colors.pink;
      case RecordType.highestAverageEarnings: return Colors.teal;
      case RecordType.mostSoloGames: return Colors.brown;
      case RecordType.bestSoloWinRate: return Colors.indigo;
      case RecordType.mostRamschLosses: return Colors.orange;
      case RecordType.bestTeamPlayer: return Colors.blue;
      case RecordType.worstLossStreak: return Colors.red;
      case RecordType.mostConsistentPlayer: return Colors.green;
     
        // TODO: Handle this case.
    }
  }
}

class _BestenlistenTab extends StatelessWidget {
  final StatisticsData statistics;

  const _BestenlistenTab({required this.statistics});

  @override
  Widget build(BuildContext context) {
    final rankings = RankingsCalculator.calculateRankings(statistics);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rankings.bestSauspielPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Beste Sauspiel-Spieler',
            icon: '🐷',
            rankings: rankings.bestSauspielPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        if (rankings.bestWenzPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Wenz-Könige',
            icon: '🃏',
            rankings: rankings.bestWenzPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        if (rankings.bestSoloPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Solo-Meister',
            icon: '👑',
            rankings: rankings.bestSoloPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        if (rankings.leastRamschLosses.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Ramsch-Überlebende',
            icon: '💥',
            rankings: rankings.leastRamschLosses,
            valueFormatter: (value) => '${value.toStringAsFixed(1)}%',
            isInverted: true,
          ),
        const SizedBox(height: 16),
        if (rankings.bestKontraPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Kontra-Könige',
            icon: '🎯',
            rankings: rankings.bestKontraPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        if (rankings.highestSoloEarnings.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Höchste Gewinnquote (Solo)',
            icon: '📈',
            rankings: rankings.highestSoloEarnings,
            valueFormatter: (value) => '${value.toStringAsFixed(2)}€/Spiel',
          ),
        const SizedBox(height: 16),
        if (rankings.bestGeierPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Geier-Experten',
            icon: '🦅',
            rankings: rankings.bestGeierPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
        const SizedBox(height: 16),
        if (rankings.bestFarbspielPlayers.isNotEmpty)
          _buildRankingCard(
            context,
            title: 'Farbspiel-Profis',
            icon: '🎨',
            rankings: rankings.bestFarbspielPlayers,
            valueFormatter: (value) => '${(value * 100).toStringAsFixed(1)}%',
          ),
      ],
    );
  }

  Widget _buildRankingCard(
    BuildContext context, {
    required String title,
    required String icon,
    required List<PlayerRanking> rankings,
    required String Function(double value) valueFormatter,
    bool isInverted = false,
  }) {
    if (rankings.isEmpty) {
      return const SizedBox.shrink();  // Don't show empty cards
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            ...rankings.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final player = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(rank),
                  child: Text(
                    _getRankEmoji(rank),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(player.name),
                subtitle: Text(player.additionalInfo ?? ''),
                trailing: Text(
                  valueFormatter(player.value),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isInverted ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '$rank';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return Colors.grey.shade300;
      case 3: return Colors.brown.shade300;
      default: return Colors.grey.shade100;
    }
  }
}

class _VerlaufTab extends StatelessWidget {
  final StatisticsData statistics;

  const _VerlaufTab({required this.statistics});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kontostand-Verlauf',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: BalanceHistoryChart(
                    sessions: statistics.sessions,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spieltypen-Verteilung',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: GameTypeDistributionChart(
                    sessions: statistics.sessions,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Durchschnittlicher Spielwert',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: AverageGameValueChart(
                    sessions: statistics.sessions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}



 