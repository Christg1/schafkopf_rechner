import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/models/game_types.dart';
import 'package:schafkopf_rechner/models/player.dart';
import 'package:schafkopf_rechner/models/session.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:schafkopf_rechner/widgets/loading_indicator.dart';

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
            isScrollable: true,
            tabs: [
              Tab(text: 'Spieler 👥'),
              Tab(text: 'Sessions 📊'),
              Tab(text: 'Rankings 🏆'),
              Tab(text: 'Verlauf 📈'),
              Tab(text: 'Rekorde ⭐'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlayerStatsTab(),
            _SessionsTab(),
            _RankingsTab(),
            _BalanceProgressionTab(),
            _RecordsTab(),
          ],
        ),
      ),
    );
  }
}

class _PlayerStatsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }
        if (!snapshot.hasData) {
          return const CustomLoadingIndicator();
        }

        // Calculate totals from all sessions
        Map<String, Player> players = {};
        
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          
          // Initialize players if they don't exist
          for (var playerName in session.players) {
            players.putIfAbsent(playerName, () => Player(name: playerName));
          }
          
          // Add balances
          session.playerBalances.forEach((playerName, balance) {
            players[playerName]!.totalEarnings += balance;
          });
          
          // Update games played, participated, and won
          for (var round in session.rounds) {
            // Update participated for all players in the session
            for (var playerName in session.players) {
              players[playerName]!.gamesParticipated++;
            }
            
            // Update played and won for the main player
            final mainPlayer = players[round.mainPlayer]!;
            mainPlayer.gamesPlayed++;
            if (round.isWon) {
              mainPlayer.gamesWon++;
            }
            
            // Update game type stats
            mainPlayer.gameTypeStats[round.gameType] = 
                (mainPlayer.gameTypeStats[round.gameType] ?? 0) + 1;
          }
        }

        final playersList = players.values.toList()
          ..sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));

        return ListView.builder(
          itemCount: playersList.length,
          itemBuilder: (context, index) {
            final player = playersList[index];
            return PlayerStatisticsCard(
              player: player,
              balance: player.totalEarnings,  // Use totalEarnings directly from player
              gamesPlayed: player.gamesPlayed,
              gamesWon: player.gamesWon,
              winRate: player.gamesPlayed > 0 
                  ? (player.gamesWon / player.gamesPlayed * 100)
                  : 0,
            );
          },
        );
      },
    );
  }
}

class PlayerStatisticsCard extends StatelessWidget {
  final Player player;
  final double balance;
  final int gamesPlayed;
  final int gamesWon;
  final double winRate;

  const PlayerStatisticsCard({
    required this.player,
    required this.balance,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.winRate,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  player.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${balance.toStringAsFixed(2)}€',
                  style: TextStyle(
                    color: balance >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            // ... rest of the card content ...
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class PlayerDetailsSheet extends StatelessWidget {
  final String playerId;
  final Map<String, dynamic> playerData;
  final ScrollController scrollController;
  final double totalBalance;

  const PlayerDetailsSheet({
    super.key,
    required this.playerId,
    required this.playerData,
    required this.scrollController,
    required this.totalBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sessions')
            .where('players', arrayContains: playerData['name'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Calculate game type stats across all sessions
          Map<GameType, int> gameTypeStats = {};
          for (var sessionDoc in snapshot.data!.docs) {
            final session = Session.fromFirestore(sessionDoc);
            for (var round in session.rounds) {
              if (round.mainPlayer == playerData['name']) {
                gameTypeStats[round.gameType] = (gameTypeStats[round.gameType] ?? 0) + 1;
              }
            }
          }

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                playerData['name'] as String,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              
              _buildDetailedStats(totalBalance),
              const SizedBox(height: 16),
              
              _buildGameTypeStats(gameTypeStats),
              const SizedBox(height: 16),
              
              _buildRecentGames(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailedStats(double totalBalance) {
    final gamesPlayed = playerData['gamesPlayed'] as int? ?? 0;
    final gamesParticipated = playerData['gamesParticipated'] as int? ?? 0;
    final gamesWon = playerData['gamesWon'] as int? ?? 0;
    final playRate = gamesParticipated > 0 
        ? (gamesPlayed / gamesParticipated * 100) 
        : 0.0;
    
    final avgEarnings = (gamesPlayed + gamesParticipated) > 0 
        ? totalBalance / (gamesPlayed + gamesParticipated)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Detaillierte Statistiken', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _DetailRow(
          label: 'Aktiv gespielt',
          value: gamesPlayed.toString(),
        ),
        _DetailRow(
          label: 'Davon gewonnen',
          value: gamesWon.toString(),
        ),
        _DetailRow(
          label: 'Gewinnrate',
          value: '${_calculateWinRate(playerData)}%',
        ),
        _DetailRow(
          label: 'Teilgenommen',
          value: gamesParticipated.toString(),
        ),
        _DetailRow(
          label: 'Spielrate',
          value: '${playRate.toStringAsFixed(1)}%',
        ),
        _DetailRow(
          label: 'Gesamtspiele',
          value: '${gamesPlayed + gamesParticipated}',
        ),
        _DetailRow(
          label: 'Gesamtbilanz',
          value: '${totalBalance.toStringAsFixed(2)}€',
        ),
        _DetailRow(
          label: 'Durchschnitt pro Spiel',
          value: '${avgEarnings.toStringAsFixed(2)}€',
        ),
      ],
    );
  }

  Widget _buildGameTypeStats(Map<GameType, int> gameTypeStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spieltypen', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...GameType.values.map((type) {
          final count = gameTypeStats[type] ?? 0;
          return _DetailRow(
            label: type.name,
            value: count.toString(),
          );
        }),
      ],
    );
  }

  Widget _buildRecentGames() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('games')
          .where('players', arrayContains: playerData['name'])
          .orderBy('date', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Letzte Spiele', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...snapshot.data!.docs.map((doc) {
              final gameData = doc.data() as Map<String, dynamic>;
              final date = (gameData['date'] as Timestamp).toDate();
              return ListTile(
                title: Text(DateFormat('dd.MM.yyyy HH:mm').format(date)),
                subtitle: Text('Mitspieler: ${(gameData['players'] as List<dynamic>).join(', ')}'),
              );
            }),
          ],
        );
      },
    );
  }

  String _calculateWinRate(Map<String, dynamic> playerData) {
    final gamesPlayed = playerData['gamesPlayed'] as int? ?? 0;
    final gamesWon = playerData['gamesWon'] as int? ?? 0;
    if (gamesPlayed == 0) return '0';
    return ((gamesWon / gamesPlayed) * 100).toStringAsFixed(1);
  }
}

class _SessionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CustomLoadingIndicator();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final session = Session.fromFirestore(snapshot.data!.docs[index]);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateFormat('dd.MM.yyyy').format(session.date),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          '${session.rounds.length} Runden',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: session.players.map((player) => Chip(
                        label: Text(player),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    ...session.playerBalances.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key),
                          Text(
                            '${e.value.toStringAsFixed(2)}€',
                            style: TextStyle(
                              color: e.value >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            );
          },
        );
      },
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
    // Calculate session statistics
    Map<String, Map<GameType, int>> playerGameTypes = {};
    Map<String, int> totalGamesPlayed = {};
    Map<String, int> gamesWon = {};

    // Initialize maps for each player
    for (String player in session.players) {
      playerGameTypes[player] = {};
      totalGamesPlayed[player] = 0;
      gamesWon[player] = 0;
    }

    // Calculate statistics from rounds
    for (var round in session.rounds) {
      // Count game types for main player
      final mainPlayer = round.mainPlayer;
      playerGameTypes[mainPlayer]?[round.gameType] = 
          (playerGameTypes[mainPlayer]?[round.gameType] ?? 0) + 1;
      
      totalGamesPlayed[mainPlayer] = (totalGamesPlayed[mainPlayer] ?? 0) + 1;
      if (round.isWon) {
        gamesWon[mainPlayer] = (gamesWon[mainPlayer] ?? 0) + 1;
      }
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Session vom ${DateFormat('dd.MM.yyyy HH:mm').format(session.date)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          // Session overview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Übersicht', 
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Anzahl Runden: ${session.rounds.length}'),
                  Text('Grundwert: ${session.baseValue}€'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detailed player statistics
          ...session.players.map((player) => Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player name and balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(player, 
                        style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${(session.playerBalances[player] ?? 0).toStringAsFixed(2)}€',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: (session.playerBalances[player] ?? 0) >= 0 
                              ? Colors.green 
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),

                  // Games statistics
                  _buildStatRow('Gespielt', totalGamesPlayed[player] ?? 0),
                  _buildStatRow('Gewonnen', gamesWon[player] ?? 0),
                  _buildStatRow('Gewinnrate', 
                    totalGamesPlayed[player] == 0 ? 0 :
                    '${((gamesWon[player] ?? 0) / (totalGamesPlayed[player] ?? 1) * 100)
                        .toStringAsFixed(1)}%'),

                  // Game types played
                  if ((playerGameTypes[player]?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: 8),
                    Text('Gespielte Spiele:', 
                      style: Theme.of(context).textTheme.titleMedium),
                    ...playerGameTypes[player]!.entries
                        .where((e) => e.value > 0)
                        .map((e) => _buildStatRow(
                          e.key.name, 
                          e.value
                        )),
                  ],
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RankingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CustomLoadingIndicator();

        // Calculate totals from all sessions
        Map<String, double> totalEarnings = {};
        
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          if (!session.isActive) { // Only count completed sessions
            final balances = session.playerBalances;
            for (var entry in balances.entries) {
              totalEarnings[entry.key] = (totalEarnings[entry.key] ?? 0) + entry.value;
            }
          }
        }

        final players = totalEarnings.entries.map((e) {
          final player = Player(name: e.key);
          player.totalEarnings = e.value;
          return player;
        }).toList()
          ..sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));

        return ListView.builder(
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return ListTile(
              title: Text(player.name),
              trailing: Text(
                '${player.totalEarnings.toStringAsFixed(2)}€',
                style: TextStyle(
                  color: player.totalEarnings >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BalanceProgressionTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CustomLoadingIndicator();
        }

        // Initialize data structures
        Map<String, List<FlSpot>> playerSpots = {};
        Set<String> allPlayers = {};
        double maxX = 1; // Start at 1 to show initial point
        double maxY = 0;
        double minY = 0;

        // First pass: collect all unique players
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          allPlayers.addAll(session.players);
        }

        // Initialize each player's data with a starting point at (0,0)
        for (var player in allPlayers) {
          playerSpots[player] = [const FlSpot(0, 0)];
        }

        // Track running balances
        Map<String, double> runningBalances = {
          for (var player in allPlayers) player: 0.0
        };

        // Process all sessions chronologically
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          
          // Update running balances and add data points
          session.playerBalances.forEach((player, balance) {
            if (playerSpots.containsKey(player)) {
              runningBalances[player] = (runningBalances[player] ?? 0) + balance;
              playerSpots[player]!.add(FlSpot(maxX, runningBalances[player]!));
              
              maxY = max(maxY, runningBalances[player]!);
              minY = min(minY, runningBalances[player]!);
            }
          });
          
          maxX++;
        }

        // Ensure we have some range on Y axis
        if (maxY == minY) {
          maxY += 10;
          minY -= 10;
        }

        // Create line chart
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: AspectRatio(
            aspectRatio: 1.5,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(2)}€',
                          TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                minX: 0,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                lineBarsData: playerSpots.entries.map((entry) {
                  final color = Colors.primaries[
                    entry.key.hashCode % Colors.primaries.length
                  ];
                  return LineChartBarData(
                    spots: entry.value,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecordsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sessions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Ein Fehler ist aufgetreten'));
        }
        if (!snapshot.hasData) {
          return const CustomLoadingIndicator();
        }

        // Track streaks per player
        Map<String, double> currentStreaks = {};
        Map<String, double> highestStreaks = {};
        
        // Sort sessions by date to process them chronologically
        final sessions = snapshot.data!.docs
            .map((doc) => Session.fromFirestore(doc))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

        for (var session in sessions) {
          for (var round in session.rounds) {
            final mainPlayer = round.mainPlayer;
            
            // Calculate actual earnings for the main player
            double actualEarnings = 0;
            if (session.players.length == 3) {
              actualEarnings = round.isWon ? (round.value * 2) : -(round.value * 2);
            } else {
              // 4 player game
              if (round.gameType == GameType.sauspiel) {
                actualEarnings = round.isWon ? round.value : -round.value;
              } else {
                actualEarnings = round.isWon ? (round.value * 3) : -(round.value * 3);
              }
            }

            // Update streak for main player
            if (round.isWon) {
              currentStreaks[mainPlayer] = (currentStreaks[mainPlayer] ?? 0) + actualEarnings;
              
              // Update highest streak if current is higher
              if ((currentStreaks[mainPlayer] ?? 0) > (highestStreaks[mainPlayer] ?? 0)) {
                highestStreaks[mainPlayer] = currentStreaks[mainPlayer]!;
              }
            } else {
              // Reset streak on loss
              currentStreaks[mainPlayer] = 0;
            }
          }
        }

        // Find the highest streak among all players
        double overallHighestStreak = 0;
        String? playerWithHighestStreak;
        
        highestStreaks.forEach((player, streak) {
          if (streak > overallHighestStreak) {
            overallHighestStreak = streak;
            playerWithHighestStreak = player;
          }
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRecordTile(
              context,
              'Wertvollste Siegesserie',
              '${overallHighestStreak.toStringAsFixed(2)}€',
              description: playerWithHighestStreak != null 
                  ? 'von $playerWithHighestStreak' 
                  : null,
            ),
            // ... other records ...
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Widget _buildRecordTile(
    BuildContext context,
    String title,
    String value,
    {String? description}
  ) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: description != null ? Text(description) : null,
        trailing: Text(
          value,
          style: TextStyle(
            color: value.contains('-') ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}