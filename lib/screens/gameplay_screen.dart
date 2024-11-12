import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schafkopf_rechner/widgets/loading_indicator.dart';
import '../models/game_types.dart';
import '../models/game_round.dart';
import '../utils/game_calculator.dart';
import '../services/session_service.dart';
import '../models/session.dart';
import '../providers/settings_provider.dart';

const _playerEmojis = {
  0: '😎',
  1: '🤠',
  2: '🦊',
  3: '🐻',
  4: '🦁',
  5: '🐯',
  6: '🐸',
  7: '🦉',
  8: '🦄',
  9: '🐼',
};

class GameplayScreen extends StatelessWidget {
  final String sessionId;

  const GameplayScreen({super.key, required this.sessionId});

  void _showNewRoundDialog(BuildContext context, Session session) {
    GameType? selectedGameType;
    String? selectedPlayer;
    String? selectedPartner;
    bool isWon = true;
    bool isSchneider = false;
    bool isSchwarz = false;
    final knockingPlayers = <String>[];
    final kontraPlayers = <String>{};
    final rePlayers = <String>{};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            double currentValue = GameCalculator.calculateGameValue(
              gameType: selectedGameType ?? GameType.sauspiel,
              baseValue: session.baseValue,
              knockingPlayers: knockingPlayers,
              kontraPlayers: kontraPlayers.toList(),
              rePlayers: rePlayers.toList(),
              isSchneider: isSchneider,
              isSchwarz: isSchwarz,
            );

            return AlertDialog(
              title: const Text('Neue Runde'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Game Type Selection
                    DropdownButtonFormField<GameType>(
                      decoration: const InputDecoration(labelText: 'Spielart'),
                      value: selectedGameType,
                      items: GameType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        );
                      }).toList(),
                      onChanged: (GameType? value) {
                        setState(() {
                          selectedGameType = value;
                          selectedPartner = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Main Player Selection
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Spieler'),
                      value: selectedPlayer,
                      items: session.players.map((player) {
                        return DropdownMenuItem(
                          value: player,
                          child: Text(player),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() => selectedPlayer = value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Partner Selection (only for Sauspiel)
                    if (selectedGameType == GameType.sauspiel)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Partner'),
                        value: selectedPartner,
                        items: session.players
                            .where((player) => player != selectedPlayer)
                            .map((player) {
                          return DropdownMenuItem(
                            value: player,
                            child: Text(player),
                          );
                        }).toList(),
                        onChanged: (String? value) {
                          setState(() => selectedPartner = value);
                        },
                      ),

                    const SizedBox(height: 16),
                    const Divider(),

                    // Game Result Options
                    SwitchListTile(
                      title: const Text('Verloren'),
                      value: !isWon,
                      onChanged: (bool value) {
                        setState(() {
                          isWon = !value;
                        });
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Schneider'),
                      value: isSchneider,
                      onChanged: (bool value) {
                        setState(() => isSchneider = value);
                      },
                    ),

                    SwitchListTile(
                      title: const Text('Schwarz'),
                      value: isSchwarz,
                      onChanged: (bool value) {
                        setState(() => isSchwarz = value);
                      },
                    ),

                    const Divider(),

                    // Klopfen Selection
                    Row(
                      children: [
                        const Text('Klopfen:'),
                        const SizedBox(width: 8),
                        Text(knockingPlayers.length.toString()),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: knockingPlayers.length >= 4 
                              ? null  // This will grey out the button
                              : () => setState(() {
                                    knockingPlayers.add('klopfen');
                                  }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: knockingPlayers.isEmpty
                              ? null
                              : () => setState(() {
                                    knockingPlayers.removeLast();
                                  }),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Kontra Selection
                    SwitchListTile(
                      title: const Text('Kontra'),
                      value: kontraPlayers.isNotEmpty,
                      onChanged: (bool value) {
                        setState(() {
                          if (value) {
                            kontraPlayers.add('kontra');
                          } else {
                            kontraPlayers.clear();
                          }
                        });
                      },
                    ),

                    // Re Selection
                    SwitchListTile(
                      title: const Text('Re'),
                      value: rePlayers.isNotEmpty,
                      onChanged: (bool value) {
                        setState(() {
                          if (value) {
                            rePlayers.add('re');
                          } else {
                            rePlayers.clear();
                          }
                        });
                      },
                    ),

                    const Divider(),

                    // Current Value Display
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            const Text('Aktueller Spielwert:'),
                            Text(
                              '${currentValue.toStringAsFixed(2)} €',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedGameType != null && selectedPlayer != null) {
                      // Check if it's a Sauspiel without partner
                      if (selectedGameType == GameType.sauspiel && selectedPartner == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bitte wähle einen Partner für das Sauspiel'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;  // Don't proceed with saving
                      }

                      final round = GameRound(
                        gameType: selectedGameType!,
                        mainPlayer: selectedPlayer!,
                        partner: selectedPartner,
                        suit: null,
                        isWon: isWon,
                        isSchneider: isSchneider,
                        isSchwarz: isSchwarz,
                        knockingPlayers: knockingPlayers,
                        kontraPlayers: kontraPlayers.toList(),
                        rePlayers: rePlayers.toList(),
                        value: currentValue,
                      );
                      
                      try {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        // Add the round
                        await SessionService().addRound(session.id, round);
                        
                        // Close loading indicator and dialog
                        Navigator.of(context).pop(); // Close loading
                        Navigator.of(context).pop(); // Close new round dialog
                      } catch (e) {
                        // Close loading indicator
                        Navigator.of(context).pop();
                        // Show error
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler beim Speichern: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _endSession(BuildContext context, String sessionId) async {
    try {
      await SessionService().endSession(sessionId);
      if (!context.mounted) return;
      
      Navigator.of(context).pushReplacementNamed('/statistics');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _showEndSessionDialog(BuildContext context, Session session) async {
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Text('🏁 '),
            Text('Session beenden?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Möchtest du die aktuelle Session beenden?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${session.rounds.length} Spiele gespielt 🎮\n'
                  '${session.players.length} Spieler 👥',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => _endSession(context, sessionId),
            child: const Text('Beenden ✅'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Session>(
      stream: SessionService().getSession(sessionId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CustomLoadingIndicator();
        }

        final session = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Aktuelle Session'),
            actions: [
              IconButton(
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Session beenden',
                onPressed: () => _showEndSessionDialog(context, session),
              ),
            ],
          ),
          body: Column(
            children: [
              // Balance Overview Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spielstand',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      ...session.players.asMap().entries.map((entry) {
                        final player = entry.value;
                        final balance = session.playerBalances[player] ?? 0;
                        final emoji = _playerEmojis[entry.key % _playerEmojis.length];
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    emoji!,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    player,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              Text(
                                '${balance.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: balance >= 0 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              // Games List
              Expanded(
                child: Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gespielte Runden',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${session.rounds.length} Spiele',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: session.rounds.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final round = session.rounds[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                child: Text('${index + 1}'),
                              ),
                              title: Text(
                                '${round.gameType.name} - ${round.mainPlayer}'
                                '${round.partner != null ? ' mit ${round.partner}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: Text(
                                '${round.value.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: round.isWon ? Colors.green : Colors.red,
                                ),
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
          floatingActionButton: FloatingActionButton.large(
            onPressed: () => _showNewRoundDialog(context, session),
            child: const Icon(Icons.add, size: 32),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}
