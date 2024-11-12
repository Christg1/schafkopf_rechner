import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/models/game_types.dart';
import 'package:schafkopf_rechner/models/session.dart';
import 'package:fl_chart/fl_chart.dart';

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
              Tab(text: 'Spieler'),
              Tab(text: 'Sessions'),
              Tab(text: 'Rankings'),
              Tab(text: 'Verlauf'),
              Tab(text: 'Rekorde'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlayerStatisticsTab(),
            _SessionsStatisticsTab(),
            _RankingsTab(),
            _BalanceProgressionTab(),
            _RecordsTab(),
          ],
        ),
      ),
    );
  }
}

class _PlayerStatisticsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('players').snapshots(),
      builder: (context, playerSnapshot) {
        if (playerSnapshot.hasError) {
          return Center(child: Text('Error: ${playerSnapshot.error}'));
        }

        if (playerSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sessions')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            Map<String, double> totalBalances = {};
            for (var sessionDoc in sessionSnapshot.data?.docs ?? []) {
              final session = Session.fromFirestore(sessionDoc);
              session.playerBalances.forEach((player, balance) {
                totalBalances[player] = (totalBalances[player] ?? 0.0) + balance;
              });
            }

            return ListView.builder(
              itemCount: playerSnapshot.data?.docs.length ?? 0,
              itemBuilder: (context, index) {
                final playerDoc = playerSnapshot.data!.docs[index];
                final playerData = playerDoc.data() as Map<String, dynamic>;
                final playerName = playerData['name'] as String;
                
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () => _showPlayerDetails(
                      context, 
                      playerDoc.id, 
                      playerData,
                      totalBalances[playerName] ?? 0.0
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playerName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          _buildQuickStats(
                            playerData,
                            totalBalances[playerName] ?? 0.0
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
      },
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> playerData, double totalBalance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          label: 'Spiele',
          value: '${playerData['gamesParticipated'] ?? 0}',
        ),
        _StatItem(
          label: 'Gewinnrate',
          value: '${_calculateWinRate(playerData)}%',
        ),
        _StatItem(
          label: 'Bilanz',
          value: '${totalBalance.toStringAsFixed(2)}€',
          valueColor: totalBalance >= 0 ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  String _calculateWinRate(Map<String, dynamic> playerData) {
    final gamesPlayed = playerData['gamesPlayed'] as int? ?? 0;
    final gamesWon = playerData['gamesWon'] as int? ?? 0;
    if (gamesPlayed == 0) return '0';
    return ((gamesWon / gamesPlayed) * 100).toStringAsFixed(1);
  }

  void _showPlayerDetails(BuildContext context, String playerId, Map<String, dynamic> playerData, double totalBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => PlayerDetailsSheet(
          playerId: playerId,
          playerData: playerData,
          scrollController: controller,
          totalBalance: totalBalance,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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

class _SessionsStatisticsTab extends StatelessWidget {
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

class _BalanceProgressionTab extends StatefulWidget {
  @override
  State<_BalanceProgressionTab> createState() => _BalanceProgressionTabState();
}

class _BalanceProgressionTabState extends State<_BalanceProgressionTab> {
  final Map<String, bool> _visiblePlayers = {};
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Process sessions to create balance progression data
        Map<String, List<FlSpot>> playerData = {};
        Map<String, double> currentBalances = {};
        
        // Process all sessions chronologically
        var sessions = snapshot.data!.docs;
        for (int i = 0; i < sessions.length; i++) {
          final session = Session.fromFirestore(sessions[i]);
          
          // Update balances for each player
          session.playerBalances.forEach((player, balance) {
            currentBalances[player] = (currentBalances[player] ?? 0.0) + balance;
            
            // Initialize player data if needed
            playerData.putIfAbsent(player, () => []);
            
            // Add data point (x = session index, y = current balance)
            playerData[player]!.add(FlSpot(i.toDouble(), currentBalances[player]!));
          });
        }

        // Initialize visibility toggles for new players
        playerData.keys.forEach((player) {
          _visiblePlayers.putIfAbsent(player, () => true);
        });

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Player toggles
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: playerData.keys.map((player) => FilterChip(
                  label: Text(player),
                  selected: _visiblePlayers[player] ?? true,
                  onSelected: (selected) {
                    setState(() {
                      _visiblePlayers[player] = selected;
                    });
                  },
                )).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Chart
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text('${value.toStringAsFixed(0)}€');
                          },
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: playerData.entries
                        .where((e) => _visiblePlayers[e.key] ?? true)
                        .map((e) => LineChartBarData(
                          spots: e.value,
                          isCurved: true,
                          dotData: const FlDotData(show: false),
                          color: _getPlayerColor(e.key),
                          barWidth: 3,
                        )).toList(),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final playerName = playerData.entries
                                .firstWhere((e) => e.value.contains(spot))
                                .key;
                            return LineTooltipItem(
                              '$playerName\n${spot.y.toStringAsFixed(2)}€',
                              const TextStyle(color: Colors.white),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getPlayerColor(String player) {
    // Generate a consistent color for each player
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    
    return colors[player.hashCode % colors.length];
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
          return const Center(child: CircularProgressIndicator());
        }

        // Initialize record variables ONCE, outside all loops
        double highestSessionWin = 0.0;
        String? highestSessionWinPlayer;
        String? highestSessionWinDate;

        double biggestSingleGameWin = 0.0;
        String? biggestGameWinPlayer;
        GameType? biggestGameWinType;
        String? biggestGameWinDate;

        int longestWinStreak = 0;
        String? streakPlayer;
        Map<String, int> currentStreaks = {};

        double biggestWinningStreak = 0.0;
        String? winningStreakPlayer;
        String? winningStreakDate;
        Map<String, double> currentWinningStreaks = {};

        int mostRoundsInSession = 0;
        String? mostRoundsDate;

        int mostKlopfenInSession = 0;
        String? mostKlopfenPlayer;
        String? mostKlopfenSessionDate;

        double mostExpensiveRound = 0.0;
        GameType? expensiveRoundType;
        String? expensiveRoundDate;

        double biggestComeback = 0.0;
        String? comebackPlayer;
        String? comebackDate;

        int mostKontrasInSession = 0;
        String? mostKontrasPlayer;
        String? mostKontrasSessionDate;

        // Process all sessions
        for (var doc in snapshot.data!.docs) {
          final session = Session.fromFirestore(doc);
          final sessionDate = DateFormat('dd.MM.yyyy').format(session.date);

          // Reset counters for this session
          Map<String, int> sessionKlopfen = {};
          Map<String, int> sessionKontra = {};

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
            // Only check winning rounds
            if (round.isWon) {
              // Calculate actual win amount based on game type
              double actualWinAmount = round.value;
              if (round.gameType == GameType.sauspiel) {
                actualWinAmount = round.value;  // Base value for Sauspiel
              } else {
                actualWinAmount = round.value * 2;  // Double value for Solo games and Ramsch
              }

              if (actualWinAmount > biggestSingleGameWin) {
                biggestSingleGameWin = actualWinAmount;
                biggestGameWinPlayer = round.mainPlayer;
                biggestGameWinType = round.gameType;
                biggestGameWinDate = sessionDate;
              }
            }

            // Count Klopfen per player in this session
            for (var player in round.knockingPlayers) {
              sessionKlopfen[player] = (sessionKlopfen[player] ?? 0) + 1;
            }

            // Count Kontras per player in this session
            for (var player in round.kontraPlayers) {
              sessionKontra[player] = (sessionKontra[player] ?? 0) + 1;
            }

            // Update win streaks (games)
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

          // Check for most Klopfen in session
          sessionKlopfen.forEach((player, count) {
            if (count > mostKlopfenInSession) {
              mostKlopfenInSession = count;
              mostKlopfenPlayer = player;
              mostKlopfenSessionDate = sessionDate;
            }
          });

          // Check for most Kontras in session
          sessionKontra.forEach((player, count) {
            if (count > mostKontrasInSession) {
              mostKontrasInSession = count;
              // Find player with most Kontras in this session
              Map<String, int> playerKontras = {};
              for (var round in session.rounds) {
                for (var player in round.kontraPlayers) {
                  playerKontras[player] = (playerKontras[player] ?? 0) + 1;
                }
              }
              
              // Get player with most Kontras
              var maxKontrasPlayer = playerKontras.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;
                
              mostKontrasPlayer = maxKontrasPlayer;
              mostKontrasSessionDate = sessionDate;
            }
          });

          // Check for most expensive round
          if (session.rounds.length > 0) {
            double mostExpensiveRound = 0.0;
            GameType? expensiveRoundType;
            String? expensiveRoundDate;

            for (var round in session.rounds) {
              if (round.value > mostExpensiveRound) {
                mostExpensiveRound = round.value;
                expensiveRoundType = round.gameType;
                expensiveRoundDate = DateFormat('dd.MM.yyyy').format(session.date);
              }
            }
          }

          // Check for biggest comeback
          if (session.rounds.length > 0) {
            double biggestComeback = 0.0;
            String? comebackPlayer;
            String? comebackDate;

            for (var round in session.rounds) {
              if (round.value > biggestComeback) {
                biggestComeback = round.value;
                comebackPlayer = round.mainPlayer;
                comebackDate = DateFormat('dd.MM.yyyy').format(session.date);
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
              '${highestSessionWinPlayer ?? "-"}\n${highestSessionWinDate ?? "-"}',
            ),
            
            _buildRecordCard(
              context,
              'Höchster Einzelspielgewinn',
              '${biggestSingleGameWin.toStringAsFixed(2)}€',
              '${biggestGameWinPlayer ?? "-"} (${biggestGameWinType?.name ?? "-"})\n${biggestGameWinDate ?? "-"}',
            ),
            
            _buildRecordCard(
              context,
              'Längste Siegesserie',
              '$longestWinStreak Spiele',
              streakPlayer ?? "-",
            ),

            _buildRecordCard(
              context,
              'Wertvollste Siegesserie',
              '${biggestWinningStreak.toStringAsFixed(2)}€',
              '${winningStreakPlayer ?? "-"}\n${winningStreakDate ?? "-"}',
            ),
            
            _buildRecordCard(
              context,
              'Meiste Runden in einer Session',
              '$mostRoundsInSession Runden',
              mostRoundsDate ?? "-",
            ),
            
            _buildRecordCard(
              context,
              'Meiste Klopfen in einer Session',
              '$mostKlopfenInSession Klopfen',
              '${mostKlopfenPlayer ?? "-"}\n${mostKlopfenSessionDate ?? "-"}',
            ),
            
            _buildRecordCard(
              context,
              'Meiste Kontras in einer Session',
              '$mostKontrasInSession Kontras',
              '${mostKontrasPlayer ?? "-"}\n${mostKontrasSessionDate ?? "-"}',
            ),

            _buildRecordCard(
              context,
              'Teuerstes Spiel',
              '${mostExpensiveRound.toStringAsFixed(2)}€',
              '${expensiveRoundType?.name ?? "-"}\n${expensiveRoundDate ?? "-"}',
            ),

            _buildRecordCard(
              context,
              'Größtes Comeback',
              '${biggestComeback.toStringAsFixed(2)}€',
              '${comebackPlayer ?? "-"}\n${comebackDate ?? "-"}',
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    String title,
    String record,
    String details,
  ) {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    details,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}