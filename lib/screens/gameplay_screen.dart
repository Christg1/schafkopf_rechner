import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_types.dart';
import '../models/game_round.dart';
import '../utils/game_calculator.dart';
import '../services/session_service.dart';
import '../models/session.dart';
import '../providers/settings_provider.dart';


class GameplayScreen extends ConsumerStatefulWidget {
  final String sessionId;
  
  const GameplayScreen({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  final SessionService _sessionService = SessionService();
  GameType selectedGameType = GameType.sauspiel;

  @override
  void initState() {
    super.initState();
    // If you need to load the game type from somewhere, do it here
    // For example:
    // _loadInitialGameType();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsNotifierProvider);

    return StreamBuilder<Session?>(
      stream: _sessionService.getActiveSession(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data!;

        return settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (settings) => Scaffold(
            appBar: AppBar(
              title: const Text('Spielverlauf'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () => _endSession(session),
                ),
              ],
            ),
            body: Column(
              children: [
                // Dealer indicator
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Geber: ${session.players[session.currentDealer]}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),

                // Balance overview
                Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aktueller Spielstand:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...session.players.map((player) {
                          final balance = session.playerBalances[player] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(player),
                                Text(
                                  '${balance.toStringAsFixed(2)}€',
                                  style: TextStyle(
                                    color: balance >= 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
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

                // Rounds list
                Expanded(
                  child: ListView.builder(
                    itemCount: session.rounds.length,
                    itemBuilder: (context, index) {
                      final round = session.rounds[index];
                      return ListTile(
                        title: Text('Runde ${index + 1}: ${round.gameType.name}'),
                        subtitle: Text(_buildRoundDescription(round)),
                      );
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showNewRoundDialog(session),
              child: const Icon(Icons.add),
            ),
          ),
        );
      },
    );
  }

  void _showNewRoundDialog(Session session) {
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
                          onPressed: () => setState(() {
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
                        await _sessionService.addRound(widget.sessionId, round);
                        
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

  Future<void> _showSessionSummary(Session session) async {
    // Calculate net balances between players
    final Map<String, Map<String, double>> settlements = {};
    
    // Initialize settlements map
    for (String player in session.players) {
      settlements[player] = {};
      for (String otherPlayer in session.players) {
        if (player != otherPlayer) {
          settlements[player]![otherPlayer] = 0.0;
        }
      }
    }

    // Find players with negative and positive balances
    final negativeBalances = session.playerBalances.entries
        .where((e) => e.value < 0)
        .toList()
        ..sort((a, b) => a.value.compareTo(b.value)); // Most negative first

    final positiveBalances = session.playerBalances.entries
        .where((e) => e.value > 0)
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Most positive first

    // For each negative balance, distribute to positive balances
    for (var negative in negativeBalances) {
      var remainingDebt = -negative.value; // Make positive for calculations
      
      for (var positive in positiveBalances) {
        if (remainingDebt <= 0) break;
        
        var availableCredit = positive.value;
        var transfer = min(remainingDebt, availableCredit);
        
        if (transfer > 0) {
          settlements[negative.key]![positive.key] = transfer;
          remainingDebt -= transfer;
        }
      }
    }

    // Show the dialog
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spielabrechnung'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Endstand:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...session.playerBalances.entries.map((e) => 
                Text('${e.key}: ${e.value.toStringAsFixed(2)}€')),
              const SizedBox(height: 16),
              const Text('Ausgleichszahlungen:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...settlements.entries.expand((player) => 
                player.value.entries
                    .where((payment) => payment.value > 0)
                    .map((payment) => Text(
                      '${player.key} zahlt an ${payment.key}: ${payment.value.toStringAsFixed(2)}€'
                    ))
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildEndSessionDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Spiel beenden'),
      content: const Text('Möchtest du das Spiel wirklich beenden?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Beenden'),
        ),
      ],
    );
  }

  Future<void> _endSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: _buildEndSessionDialog,
    );

    if (confirmed == true) {
      await _showSessionSummary(session);
      await _sessionService.endSession(session.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  String _buildRoundDescription(GameRound round) {
    final parts = <String>[];
    
    // Basic game info
    parts.add('${round.mainPlayer} - ${round.gameType.name}');
    
    // Partner for Sauspiel
    if (round.gameType == GameType.sauspiel && round.partner != null) {
      parts.add('mit ${round.partner}');
    }
    
    // Game result
    parts.add(round.isWon ? 'Gewonnen' : 'Verloren');
    
    // Special conditions
    if (round.isSchneider) parts.add('Schneider');
    if (round.isSchwarz) parts.add('Schwarz');
    
    // Additional modifiers
    if (round.knockingPlayers.isNotEmpty) {
      parts.add('${round.knockingPlayers.length}x Klopfen');
    }
    if (round.kontraPlayers.isNotEmpty) parts.add('Kontra');
    if (round.rePlayers.isNotEmpty) parts.add('Re');
    
    // Game value
    parts.add('${round.value.toStringAsFixed(2)}€');
    
    return parts.join(' | ');
  }
}
