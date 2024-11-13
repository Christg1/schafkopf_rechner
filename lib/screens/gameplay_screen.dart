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
import '../utils/balance_calculator.dart';

const _playerEmojis = {
  0: '🐸',
  1: '🤠',
  2: '🦊',
  3: '🐻',
  4: '🦁',
  5: '🐯',
  6: '😎',
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
            // Get the base multiplier based on game type and player count
            double typeMultiplier = 1.0;
            if (selectedGameType != null && selectedGameType != GameType.sauspiel) {
              // Only apply 2x multiplier for solo games in 4-player games
              typeMultiplier = session.players.length == 4 ? 2.0 : 1.0;
            }
            
            double currentValue = GameCalculator.calculateGameValue(
              gameType: selectedGameType ?? GameType.sauspiel,
              baseValue: session.baseValue * typeMultiplier,
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
                    _buildGameTypeSelection(
                      context, 
                      session, 
                      setState,
                      selectedGameType,
                      (value) => selectedGameType = value,
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
                        isWon: isWon,
                        value: currentValue,
                        timestamp: DateTime.now(),
                      );
                      
                      try {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(child: CircularProgressIndicator()),
                        );
                        
                        // Add the round
                        await _saveRound(context, session, round);
                        
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
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void _showEndSessionDialog(BuildContext context, Session session) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final settlements = BalanceCalculator.calculateFinalSettlement(session.playerBalances);

        return AlertDialog(
          title: const Text('Session beenden'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Finale Abrechnung:'),
              const SizedBox(height: 16),
              ...settlements.map((settlement) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  settlement.toString(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                await SessionService().endSession(session.id);
                if (!context.mounted) return;
                Navigator.of(context).pushReplacementNamed('/');
              },
              child: const Text('Session beenden'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameTypeSelection(
    BuildContext context, 
    Session session, 
    StateSetter setState,
    GameType? selectedGameType,
    void Function(GameType?) onGameTypeChanged,
  ) {
    final availableGameTypes = session.players.length == 3 
        ? GameType.values.where((type) => type != GameType.sauspiel).toList()
        : GameType.values;

    return DropdownButtonFormField<GameType>(
      decoration: const InputDecoration(labelText: 'Spielart'),
      value: selectedGameType,
      items: availableGameTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text('${type.name} ${type.emoji}'),
        );
      }).toList(),
      onChanged: (GameType? value) {
        setState(() => onGameTypeChanged(value));
      },
    );
  }

  Future<void> _saveRound(BuildContext context, Session session, GameRound round) async {
    try {
      // For Ramsch games, make sure we're using the base value directly
      if (round.gameType == GameType.ramsch) {
        final baseValue = session.baseValue;
        final updatedRound = GameRound(
          gameType: round.gameType,
          mainPlayer: round.mainPlayer,
          partner: round.partner,
          isWon: round.isWon,
          value: baseValue,  // Use base value directly
          timestamp: DateTime.now(),
        );
        await SessionService().addRound(session.id, updatedRound);
      } else {
        await SessionService().addRound(session.id, round);
      }
      // ... rest of the method
    } catch (e) {
      // ... error handling
    }
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
                        final index = entry.key;
                        final player = entry.value;
                        final balance = session.playerBalances[player] ?? 0;
                        final emoji = _playerEmojis[index % _playerEmojis.length];
                        final isDealer = index == (session.rounds.length % session.players.length);  // Works for both 3 and 4 players
                        
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
                                  if (isDealer) ...[
                                    const SizedBox(width: 8),
                                    const Text('🎯', style: TextStyle(fontSize: 20)),
                                  ],
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
                      }),
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
                        child: ListView.builder(
                          itemCount: session.rounds.length,
                          itemBuilder: (context, index) {
                            return _buildRoundTile(session.rounds[index], session, index);
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

  Widget _buildRoundTile(GameRound round, Session session, int index) {
    String displayValue = '${round.value.toStringAsFixed(2)}€';

    return ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text('${round.gameType.name} - ${round.mainPlayer}'),
      trailing: Text(
        displayValue,
        style: TextStyle(
          color: round.isWon ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

