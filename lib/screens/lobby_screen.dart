import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'gameplay_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final List<String> players = [];
  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _baseValueController = TextEditingController(text: '10');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Session'),
      ),
      body: Column(
        children: [
          // Settings Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Einstellungen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  // Base Value Input
                  TextField(
                    controller: _baseValueController,
                    decoration: InputDecoration(
                      labelText: 'Grundwert',
                      prefixIcon: const Icon(Icons.euro),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: '€',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
          ),

          // Player Input Card
          Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spieler hinzufügen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _playerController,
                          decoration: InputDecoration(
                            hintText: 'Spielername',
                            prefixIcon: const Icon(Icons.person_add),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton.filled(
                        onPressed: _addPlayer,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Previous Players
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('players').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();

                      final previousPlayers = snapshot.data!.docs
                          .map((doc) => doc.id)
                          .where((name) => !players.contains(name))
                          .toList();

                      if (previousPlayers.isEmpty) return const SizedBox();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vorherige Spieler 👥',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: previousPlayers.map((name) {
                              return FilterChip(
                                label: Text(name),
                                onSelected: (_) {
                                  setState(() {
                                    if (players.length < 4) {
                                      players.add(name);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Current Players List
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.groups),
                        const SizedBox(width: 8),
                        Text(
                          'Spielerliste',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final isDealer = index == 0; // First player is dealer
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(players[index][0].toUpperCase()),
                          ),
                          title: Row(
                            children: [
                              Text(players[index]),
                              const SizedBox(width: 8),
                              if (isDealer) const Text('🎯'), // Dealer indicator
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(index < 4 ? '✅' : '⏳'), // Ready status
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removePlayer(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: players.length >= 4
          ? FloatingActionButton.extended(
              onPressed: _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Session starten'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _addPlayer() {
    final name = _playerController.text.trim();
    if (name.isNotEmpty && !players.contains(name) && players.length < 4) {
      setState(() {
        players.add(name);
        _playerController.clear();
      });
    }
  }

  void _removePlayer(int index) {
    setState(() {
      players.removeAt(index);
    });
  }

  Future<void> _startSession() async {
    if (players.length == 4) {
      try {
        final baseValue = double.parse(_baseValueController.text.replaceAll(',', '.'));
        if (baseValue <= 0) throw Exception('Grundwert muss größer als 0 sein');

        final sessionId = await SessionService().createSession(
          players: players,
          baseValue: baseValue,
          initialDealer: 0,
        );

        if (!mounted) return;
        
        Navigator.pushReplacementNamed(
          context,
          '/gameplay',
          arguments: {'sessionId': sessionId},
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    _baseValueController.dispose();
    super.dispose();
  }
} 