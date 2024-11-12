import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/utils/currency_formatter.dart';
import '../models/game_types.dart';
import '../models/session.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Statistiken'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Spieler'),
              Tab(text: 'Allgemein'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PlayerStatisticsTab(),
            _GeneralStatisticsTab(),
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
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data?.docs.length ?? 0,
          itemBuilder: (context, index) {
            final playerDoc = snapshot.data!.docs[index];
            final playerData = playerDoc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => _showPlayerDetails(context, playerDoc.id, playerData),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerData['name'] as String,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      _buildQuickStats(playerData),
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

  Widget _buildQuickStats(Map<String, dynamic> playerData) {
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
          value: '${(playerData['totalEarnings'] ?? 0).toStringAsFixed(2)}€',
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

  void _showPlayerDetails(BuildContext context, String playerId, Map<String, dynamic> playerData) {
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

  const _DetailRow(this.label, this.value);

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

  const PlayerDetailsSheet({
    super.key,
    required this.playerId,
    required this.playerData,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            playerData['name'] as String,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          
          _buildDetailedStats(),
          const SizedBox(height: 16),
          
          _buildGameTypeStats(),
          const SizedBox(height: 16),
          
          _buildRecentGames(),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    final gamesPlayed = playerData['gamesPlayed'] as int? ?? 0;
    final gamesParticipated = playerData['gamesParticipated'] as int? ?? 0;
    final gamesWon = playerData['gamesWon'] as int? ?? 0;
    final playRate = gamesParticipated > 0 
        ? (gamesPlayed / gamesParticipated * 100) 
        : 0.0;
    
    final totalEarnings = playerData['totalEarnings'] as double? ?? 0.0;
    final avgEarnings = (gamesPlayed + gamesParticipated) > 0 
        ? totalEarnings / (gamesPlayed + gamesParticipated)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Detaillierte Statistiken', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _DetailRow('Aktiv gespielt', gamesPlayed.toString()),
        _DetailRow('Davon gewonnen', gamesWon.toString()),
        _DetailRow('Gewinnrate', '${_calculateWinRate(playerData)}%'),
        _DetailRow('Teilgenommen', gamesParticipated.toString()),
        _DetailRow('Spielrate', '${playRate.toStringAsFixed(1)}%'),
        _DetailRow('Gesamtspiele', '${gamesPlayed + gamesParticipated}'),
        _DetailRow('Gesamtbilanz', '${totalEarnings.toStringAsFixed(2)}€'),
        _DetailRow('Durchschnitt pro Spiel', '${avgEarnings.toStringAsFixed(2)}€'),
      ],
    );
  }

  Widget _buildGameTypeStats() {
    final gameTypeStats = playerData['gameTypeStats'] as Map<String, dynamic>? ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Spieltypen', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...GameType.values.map((type) {
          final count = gameTypeStats[type.name] as int? ?? 0;
          return _DetailRow(type.name, count.toString());
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

class _GeneralStatisticsTab extends StatelessWidget {
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
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spieler: ${session.players.join(", ")}'),
                      Text('Runden: ${session.rounds.length}'),
                      const SizedBox(height: 4),
                      ...session.playerBalances.entries.map((e) => 
                        Text('${e.key}: ${(e.value / 100).toStringAsFixed(2)}€')),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            }),
          ],
        );
      },
    );
  }
} 