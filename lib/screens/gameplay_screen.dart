import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_types.dart';
import '../models/game_round.dart';
import '../utils/game_calculator.dart';

class GameplayScreen extends StatefulWidget {
  final String gameId;
  final List<String> players;
  final int initialDealer;
  final int baseValue;
  
  const GameplayScreen({
    super.key, 
    required this.gameId,
    required this.players,
    required this.initialDealer,
    required this.baseValue,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  late int _currentDealer;
  Map<String, double> _playerBalances = {};

  @override
  void initState() {
    super.initState();
    _currentDealer = widget.initialDealer;
    // Initialize balances to 0 for all players
    for (String player in widget.players) {
      _playerBalances[player] = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielverlauf'),
      ),
      body: Column(
        children: [
          // Dealer indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Geber: ${widget.players[_currentDealer]}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          // Balance Overview Card
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
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: widget.players.map((player) {
                            final balance = _playerBalances[player] ?? 0;
                            final isPositive = balance >= 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(player),
                                  Text(
                                    '${isPositive ? "+" : ""}${(balance / 100).toStringAsFixed(2)}€',
                                    style: TextStyle(
                                      color: isPositive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Rounds List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('games')
                  .doc(widget.gameId)
                  .collection('rounds')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Calculate balances from rounds
                _updateBalances(snapshot.data?.docs ?? []);

                return snapshot.data!.docs.isEmpty
                    ? const Center(child: Text('Noch keine Runden gespielt'))
                    : ListView.builder(
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final roundData = 
                              snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          final round = GameRound.fromFirestore(roundData);
                          return ListTile(
                            title: Text('Runde ${index + 1}: ${round.gameType.name}'),
                            subtitle: Text(_buildRoundDescription(round)),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewRoundDialog,
        child: const Icon(Icons.add),
      ),
    );
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
    parts.add('${(round.value / 100).toStringAsFixed(2)}€');
    
    return parts.join(' | ');
  }

  void _showNewRoundDialog() {
    GameType? selectedGameType;
    String? selectedPlayer;
    String? selectedPartner;
    bool isWon = false;
    bool isSchneider = false;
    bool isSchwarz = false;
    final knockingPlayers = <String>{};
    final kontraPlayers = <String>{};
    final rePlayers = <String>{};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentValue = selectedGameType != null 
                ? GameCalculator.calculateGameValue(
                    gameType: selectedGameType!,
                    baseValue: widget.baseValue,
                    knockingPlayers: knockingPlayers.toList(),
                    kontraPlayers: kontraPlayers.toList(),
                    rePlayers: rePlayers.toList(),
                    isSchneider: isSchneider,
                    isSchwarz: isSchwarz,
                  )
                : 0.0;

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
                      items: widget.players.map((player) {
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
                        items: widget.players
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
                      title: const Text('Gewonnen'),
                      value: isWon,
                      onChanged: (bool value) {
                        setState(() => isWon = value);
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
                    const Text('Klopfen:', style: TextStyle(fontSize: 16)),
                    Wrap(
                      spacing: 8.0,
                      children: widget.players.map((player) {
                        return FilterChip(
                          label: Text(player),
                          selected: knockingPlayers.contains(player),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                knockingPlayers.add(player);
                              } else {
                                knockingPlayers.remove(player);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Kontra Selection
                    const Text('Kontra:', style: TextStyle(fontSize: 16)),
                    Wrap(
                      spacing: 8.0,
                      children: widget.players.map((player) {
                        return FilterChip(
                          label: Text(player),
                          selected: kontraPlayers.contains(player),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                kontraPlayers.add(player);
                                rePlayers.remove(player);  // Can't have both
                              } else {
                                kontraPlayers.remove(player);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    // Re Selection
                    const Text('Re:', style: TextStyle(fontSize: 16)),
                    Wrap(
                      spacing: 8.0,
                      children: widget.players.map((player) {
                        return FilterChip(
                          label: Text(player),
                          selected: rePlayers.contains(player),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                rePlayers.add(player);
                                kontraPlayers.remove(player);  // Can't have both
                              } else {
                                rePlayers.remove(player);
                              }
                            });
                          },
                        );
                      }).toList(),
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
                              '${(currentValue / 100).toStringAsFixed(2)} €',
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
                  onPressed: () {
                    if (selectedGameType != null && selectedPlayer != null) {
                      final round = GameRound(
                        gameType: selectedGameType!,
                        mainPlayer: selectedPlayer!,
                        partner: selectedPartner,
                        suit: null,  // Removed suit
                        isWon: isWon,
                        isSchneider: isSchneider,
                        isSchwarz: isSchwarz,
                        knockingPlayers: knockingPlayers.toList(),
                        kontraPlayers: kontraPlayers.toList(),
                        rePlayers: rePlayers.toList(),
                        value: currentValue,
                      );
                      _saveRound(round);
                      Navigator.pop(context);
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

  Future<void> _saveRound(GameRound round) async {
    try {
      // Update dealer
      setState(() {
        _currentDealer = (_currentDealer + 1) % 4;
      });

      // Save round to Firestore
      await FirebaseFirestore.instance
          .collection('games')
          .doc(widget.gameId)
          .update({
        'rounds': FieldValue.arrayUnion([round.toFirestore()]),
        'currentDealer': _currentDealer,
      });

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Runde gespeichert'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message if save fails
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Speichern: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updateBalances(List<QueryDocumentSnapshot> rounds) {
    // Reset balances
    _playerBalances.clear();
    for (String player in widget.players) {
      _playerBalances[player] = 0;
    }

    // Calculate balances from all rounds
    for (var roundDoc in rounds) {
      final roundData = roundDoc.data() as Map<String, dynamic>;
      final round = GameRound.fromFirestore(roundData);
      _calculateRoundBalances(round);
    }
    
    // Force UI update
    setState(() {});
  }

  void _calculateRoundBalances(GameRound round) {
    if (round.gameType == GameType.sauspiel) {
      // Sauspiel calculation
      if (round.isWon) {
        // Winners get money from losers
        _playerBalances[round.mainPlayer] = (_playerBalances[round.mainPlayer] ?? 0) + round.value;
        if (round.partner != null) {
          _playerBalances[round.partner!] = (_playerBalances[round.partner!] ?? 0) + round.value;
        }
        // Losers pay
        for (String player in widget.players) {
          if (player != round.mainPlayer && player != round.partner) {
            _playerBalances[player] = (_playerBalances[player] ?? 0) - round.value;
          }
        }
      } else {
        // Losers pay winners
        _playerBalances[round.mainPlayer] = (_playerBalances[round.mainPlayer] ?? 0) - (round.value * 2);
        if (round.partner != null) {
          _playerBalances[round.partner!] = (_playerBalances[round.partner!] ?? 0) - (round.value * 2);
        }
        // Winners get money
        for (String player in widget.players) {
          if (player != round.mainPlayer && player != round.partner) {
            _playerBalances[player] = (_playerBalances[player] ?? 0) + round.value;
          }
        }
      }
    } else {
      // Solo games calculation
      if (round.isWon) {
        // Winner gets money from all others
        _playerBalances[round.mainPlayer] = (_playerBalances[round.mainPlayer] ?? 0) + (round.value * 3);
      } else {
        // Losers pay winners
        _playerBalances[round.mainPlayer] = (_playerBalances[round.mainPlayer] ?? 0) - (round.value * 2);
        // Winners get money
        for (String player in widget.players) {
          if (player != round.mainPlayer) {
            _playerBalances[player] = (_playerBalances[player] ?? 0) + round.value;
          }
        }
      }
    }
  }
}