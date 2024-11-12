import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/models/game_types.dart';
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
          bottom: TabBar(
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
      stream: FirebaseFirestore.instance.collection('players').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CustomLoadingIndicator();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final playerDoc = snapshot.data!.docs[index];
            final playerData = playerDoc.data() as Map<String, dynamic>;
            final totalEarnings = (playerData['totalEarnings'] as num?)?.toDouble() ?? 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showPlayerDetails(context, playerDoc.id, playerData),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(playerDoc.id[0].toUpperCase()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              playerDoc.id,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: totalEarnings >= 0 
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${totalEarnings.toStringAsFixed(2)}€',
                              style: TextStyle(
                                color: totalEarnings >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.casino,
                            label: 'Spiele',
                            value: '${playerData['gamesPlayed'] ?? 0}',
                          ),
                          _StatItem(
                            icon: Icons.emoji_events,
                            label: 'Gewonnen',
                            value: '${playerData['gamesWon'] ?? 0}',
                          ),
                          _StatItem(
                            icon: Icons.percent,
                            label: 'Quote',
                            value: _calculateWinRate(playerData),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _calculateWinRate(Map<String, dynamic> playerData) {
    final played = playerData['gamesPlayed'] ?? 0;
    final won = playerData['gamesWon'] ?? 0;
    if (played == 0) return '0%';
    return '${((won / played) * 100).toStringAsFixed(1)}%';
  }

  void _showPlayerDetails(BuildContext context, String playerId, Map<String, dynamic> playerData) {
    final totalBalance = (playerData['totalEarnings'] as num?)?.toDouble() ?? 0.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: PlayerDetailsSheet(
            playerId: playerId,
            playerData: playerData,
            scrollController: scrollController,
            totalBalance: totalBalance,
          ),
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
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('Letzte Sessions',
              style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...snapshot.data!.docs.map((doc) {
              final session = Session.fromFirestore(doc);
              return Card(
                child: ListTile(
                  title: Text(DateFormat('dd.MM.yyyy HH:mm').format(session.date)),
                  subtitle: Text('Spieler: ${session.players.join(", ")}'),
                  trailing: Text('${session.rounds.length} Runden'),
                  onTap: () => _showSessionDetails(context, session),
                ),
              );
            }),
          ],
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
        builder: (_, controller) => SessionDetailsSheet(
          session: session,
          scrollController: controller,
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
    // Calculate session statistics
    Map<String, Map<GameType, int>> playerGameTypes = {};
    Map<String, int> totalGamesPlayed = {};
    Map<String, int> gamesWon = {};
    Map<String, int> kontraCount = {};
    Map<String, int> reCount = {};
    Map<String, int> klopfenCount = {};

    // Initialize maps for each player
    for (String player in session.players) {
      playerGameTypes[player] = {};
      totalGamesPlayed[player] = 0;
      gamesWon[player] = 0;
      kontraCount[player] = 0;
      reCount[player] = 0;
      klopfenCount[player] = 0;
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

      // Count Kontra/Re/Klopfen for all players
      for (String player in round.kontraPlayers) {
        kontraCount[player] = (kontraCount[player] ?? 0) + 1;
      }
      for (String player in round.rePlayers) {
        reCount[player] = (reCount[player] ?? 0) + 1;
      }
      for (String player in round.knockingPlayers) {
        klopfenCount[player] = (klopfenCount[player] ?? 0) + 1;
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
                    ((gamesWon[player] ?? 0) / (totalGamesPlayed[player] ?? 1) * 100)
                        .toStringAsFixed(1) + '%'),
                  
                  // Special moves
                  const SizedBox(height: 8),
                  Text('Ansagen:', 
                    style: Theme.of(context).textTheme.titleMedium),
                  _buildStatRow('Kontra', kontraCount[player] ?? 0),
                  _buildStatRow('Re', reCount[player] ?? 0),
                  _buildStatRow('Klopfen', klopfenCount[player] ?? 0),

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
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Calculate all statistics
        Map<String, double> totalEarnings = {};
        Map<String, int> gamesPlayed = {};
        Map<String, int> gamesWon = {};
        Map<String, Map<GameType, int>> playerGameTypes = {};
        Map<String, Map<String, int>> duoGames = {};
        Map<String, Map<String, int>> duoWins = {};

        // Process all sessions
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          
          // Process all rounds in this session
          for (var round in session.rounds) {  // This is List<GameRound>
            final mainPlayer = round.mainPlayer;
            
            // Update games played and won
            gamesPlayed[mainPlayer] = (gamesPlayed[mainPlayer] ?? 0) + 1;
            if (round.isWon) {
              gamesWon[mainPlayer] = (gamesWon[mainPlayer] ?? 0) + 1;
            }

            // Track game types for favorite game calculation
            playerGameTypes.putIfAbsent(mainPlayer, () => {});
            playerGameTypes[mainPlayer]![round.gameType] = 
                (playerGameTypes[mainPlayer]![round.gameType] ?? 0) + 1;

            // Track duo stats for Sauspiel
            if (round.gameType == GameType.sauspiel && round.partner != null) {
              final duo = [mainPlayer, round.partner!]..sort();
              final duoKey = duo.join(' & ');
              
              duoGames.putIfAbsent(duoKey, () => {});
              duoWins.putIfAbsent(duoKey, () => {});
              
              duoGames[duoKey]![round.gameType.name] = 
                  (duoGames[duoKey]![round.gameType.name] ?? 0) + 1;
              
              if (round.isWon) {
                duoWins[duoKey]![round.gameType.name] = 
                    (duoWins[duoKey]![round.gameType.name] ?? 0) + 1;
              }
            }
          }

          // Update total earnings from session balances
          session.playerBalances.forEach((player, balance) {
            totalEarnings[player] = (totalEarnings[player] ?? 0.0) + balance;
          });
        }

        // Calculate win rates and averages
        Map<String, double> winRates = {};
        Map<String, double> avgEarnings = {};
        Map<String, double> duoWinRates = {};
        Map<String, String> favoriteGames = {};

        // Calculate player stats
        gamesPlayed.forEach((player, games) {
          if (games >= 5) {  // Minimum 5 games
            winRates[player] = (gamesWon[player] ?? 0) / games * 100;
            avgEarnings[player] = (totalEarnings[player] ?? 0) / games;
          }
        });

        // Calculate duo win rates
        duoGames.forEach((duo, games) {
          games.forEach((gameType, count) {
            if (count >= 5) {  // Minimum 5 games together
              final wins = duoWins[duo]?[gameType] ?? 0;
              duoWinRates[duo] = wins / count * 100;
            }
          });
        });

        // Calculate favorite game types
        playerGameTypes.forEach((player, types) {
          double bestWinRate = 0;
          GameType? bestType;
          
          types.forEach((type, count) {
            if (count >= 5) {  // Minimum 5 games of this type
              final typeGames = count;
              final typeWins = types.entries
                  .where((e) => e.key == type && e.value >= 5)
                  .length;
              final winRate = (typeWins / typeGames) * 100;
              
              if (winRate > bestWinRate) {
                bestWinRate = winRate;
                bestType = type;
              }
            }
          });
          
          if (bestType != null) {
            final gameName = bestType.toString().split('.').last;  // Safe way to get enum name
            favoriteGames[player] = '$gameName (${bestWinRate.toStringAsFixed(1)}%)';
          }
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRankingCard(
              context,
              'Beste Gewinnrate',
              winRates.entries.toList(),
              suffix: '%',
              formatValue: (v) => v.toStringAsFixed(1),
            ),
            
            _buildRankingCard(
              context,
              'Höchster Durchschnittsgewinn',
              avgEarnings.entries.toList(),
              prefix: '€',
              formatValue: (v) => v.toStringAsFixed(2),
            ),
            
            _buildRankingCard(
              context,
              'Meiste Spiele',
              gamesPlayed.entries.toList(),
              formatValue: (v) => v.toStringAsFixed(0),
            ),
            
            _buildRankingCard(
              context,
              'Höchster Gesamtgewinn',
              totalEarnings.entries.toList(),
              prefix: '€',
              formatValue: (v) => v.toStringAsFixed(2),
            ),
            
            _buildRankingCard(
              context,
              'Bestes Duo',
              duoWinRates.entries.toList(),
              suffix: '%',
              formatValue: (v) => v.toStringAsFixed(1),
            ),
            
            _buildRankingCard(
              context,
              'Lieblingsspiel',
              favoriteGames.entries.toList(),
              formatValue: (v) => v.toString(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRankingCard(
    BuildContext context,
    String title,
    List<MapEntry<String, dynamic>> entries, {
    String? prefix,
    String? suffix,
    required String Function(double) formatValue,
  }) {
    // Sort entries by value descending
    entries.sort((a, b) => b.value.compareTo(a.value));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...entries.take(3).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key),
                  Text(
                    '${prefix ?? ''}${formatValue(e.value.toDouble())}${suffix ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
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
                    tooltipBgColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.8),
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
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
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
                    dotData: FlDotData(show: false),
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
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CustomLoadingIndicator();
        }

        // Initialize record variables
        double highestSessionWin = 0;
        String? highestSessionWinPlayer;
        DateTime? highestSessionWinDate;
        
        double biggestSingleGameWin = 0;
        String? biggestGameWinPlayer;
        GameType? biggestGameWinType;
        DateTime? biggestGameWinDate;

        int longestWinStreak = 0;
        String? streakPlayer;
        
        double biggestWinningStreak = 0;
        String? winningStreakPlayer;
        DateTime? winningStreakDate;

        int mostRoundsInSession = 0;
        DateTime? mostRoundsDate;

        double mostExpensiveRound = 0;
        GameType? expensiveRoundType;
        DateTime? expensiveRoundDate;

        double biggestComeback = 0;
        String? comebackPlayer;
        DateTime? comebackDate;

        Map<String, int> currentStreaks = {};
        Map<String, double> currentWinningStreaks = {};

        // Process all sessions
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          final sessionDate = session.date;

          // Check for highest session win
          session.playerBalances.forEach((player, balance) {
            if (balance > highestSessionWin) {
              highestSessionWin = balance;
              highestSessionWinPlayer = player;
              highestSessionWinDate = sessionDate;
            }
          });

          // Check for most rounds
          if (session.rounds.length > mostRoundsInSession) {
            mostRoundsInSession = session.rounds.length;
            mostRoundsDate = sessionDate;
          }

          // Process rounds in this session
          for (var round in session.rounds) {
            // Calculate actual win amount based on game type
            double actualWinAmount = round.value;
            if (round.gameType != GameType.sauspiel) {
              actualWinAmount *= 2; // Double value for Solo games and Ramsch
            }

            if (round.isWon && actualWinAmount > biggestSingleGameWin) {
              biggestSingleGameWin = actualWinAmount;
              biggestGameWinPlayer = round.mainPlayer;
              biggestGameWinType = round.gameType;
              biggestGameWinDate = sessionDate;
            }

            if (actualWinAmount > mostExpensiveRound) {
              mostExpensiveRound = actualWinAmount;
              expensiveRoundType = round.gameType;
              expensiveRoundDate = sessionDate;
            }

            // Update win streaks
            if (round.isWon) {
              currentStreaks[round.mainPlayer] = 
                  (currentStreaks[round.mainPlayer] ?? 0) + 1;
              currentWinningStreaks[round.mainPlayer] = 
                  (currentWinningStreaks[round.mainPlayer] ?? 0.0) + round.value;
              
              if ((currentStreaks[round.mainPlayer] ?? 0) > longestWinStreak) {
                longestWinStreak = currentStreaks[round.mainPlayer]!;
                streakPlayer = round.mainPlayer;
              }

              if ((currentWinningStreaks[round.mainPlayer] ?? 0) > biggestWinningStreak) {
                biggestWinningStreak = currentWinningStreaks[round.mainPlayer]!;
                winningStreakPlayer = round.mainPlayer;
                winningStreakDate = sessionDate;
              }
            } else {
              currentStreaks[round.mainPlayer] = 0;
              currentWinningStreaks[round.mainPlayer] = 0;
            }
          }

          // Calculate comebacks
          Map<String, double> runningBalances = {};
          Map<String, double> lowestBalances = {};
          
          for (var round in session.rounds) {
            for (var player in session.players) {
              double roundValue = 0.0;
              if (player == round.mainPlayer) {
                roundValue = round.isWon ? round.value : -round.value;
                if (round.gameType != GameType.sauspiel) {
                  roundValue *= 2;
                }
              } else {
                roundValue = round.isWon ? -round.value : round.value;
                if (round.gameType != GameType.sauspiel) {
                  roundValue *= 2;
                }
              }
              
              runningBalances[player] = (runningBalances[player] ?? 0.0) + roundValue;
              lowestBalances[player] = min(
                lowestBalances[player] ?? double.infinity,
                runningBalances[player]!
              );
              
              final currentComeback = runningBalances[player]! - lowestBalances[player]!;
              if (currentComeback > biggestComeback) {
                biggestComeback = currentComeback;
                comebackPlayer = player;
                comebackDate = sessionDate;
              }
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRecordCard(
              context,
              'Höchster Sessiongewinn',
              '${highestSessionWin.toStringAsFixed(2)}€',
              '${highestSessionWinPlayer ?? "-"}\n${_formatDate(highestSessionWinDate)}',
              '🏆',
            ),
            
            _buildRecordCard(
              context,
              'Höchster Einzelspielgewinn',
              '${biggestSingleGameWin.toStringAsFixed(2)}€',
              '${biggestGameWinPlayer ?? "-"} (${biggestGameWinType?.name ?? "-"})\n${_formatDate(biggestGameWinDate)}',
              '💰',
            ),
            
            _buildRecordCard(
              context,
              'Längste Siegesserie',
              '$longestWinStreak Spiele',
              streakPlayer ?? "-",
              '🔥',
            ),

            _buildRecordCard(
              context,
              'Wertvollste Siegesserie',
              '${biggestWinningStreak.toStringAsFixed(2)}€',
              '${winningStreakPlayer ?? "-"}\n${_formatDate(winningStreakDate)}',
              '📈',
            ),
            
            _buildRecordCard(
              context,
              'Meiste Runden in einer Session',
              '$mostRoundsInSession Runden',
              _formatDate(mostRoundsDate),
              '🎲',
            ),

            _buildRecordCard(
              context,
              'Teuerstes Spiel',
              '${mostExpensiveRound.toStringAsFixed(2)}€',
              '${expensiveRoundType?.name ?? "-"}\n${_formatDate(expensiveRoundDate)}',
              '💸',
            ),

            _buildRecordCard(
              context,
              'Größtes Comeback',
              '${biggestComeback.toStringAsFixed(2)}€',
              '${comebackPlayer ?? "-"}\n${_formatDate(comebackDate)}',
              '🚀',
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  Widget _buildRecordCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    String emoji,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Text(
          emoji,
          style: const TextStyle(fontSize: 36),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}