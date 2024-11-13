import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:schafkopf_rechner/models/session.dart';
import 'package:schafkopf_rechner/models/game_types.dart';

class SessionDetailsScreen extends StatelessWidget {
  final Session session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Session vom ${DateFormat('dd.MM.yyyy').format(session.date)}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Session Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spieler: ${session.players.join(", ")}'),
                  Text('Grundwert: ${session.baseValue.toStringAsFixed(2)}€'),
                  Text('Spiele: ${session.rounds.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Final Balances Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Endstand:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...session.playerBalances.entries.map((entry) => 
                    Text('${entry.key}: ${entry.value.toStringAsFixed(2)}€',
                      style: TextStyle(
                        color: entry.value >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rounds List
          const Text('Spiele:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...session.rounds.asMap().entries.map((entry) {
            final index = entry.key;
            final round = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('${round.gameType.emoji} ${round.gameType.displayName}'),
                subtitle: Text('${round.mainPlayer}${round.partner != null ? ' mit ${round.partner}' : ''}'),
                trailing: Text(
                  '${round.isWon ? '+' : '-'}${round.value.toStringAsFixed(2)}€',
                  style: TextStyle(
                    color: round.isWon ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
} 