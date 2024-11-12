import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final List<TextEditingController> _playerControllers = 
    List.generate(4, (index) => TextEditingController());
  int _selectedDealerIndex = 0;
  final _baseValueController = TextEditingController(text: '10');
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Runde'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Player name inputs with autocomplete
            ...List.generate(4, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('players')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snapshot) {
                  List<String> previousPlayers = [];
                  if (snapshot.hasData) {
                    previousPlayers = snapshot.data!.docs
                        .map((doc) => doc['name'] as String)
                        .toList();
                  }

                  return Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return previousPlayers;
                      }
                      return previousPlayers.where((player) => 
                          player.toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      _playerControllers[index].text = selection;
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      _playerControllers[index] = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Spieler ${index + 1}',
                          border: const OutlineInputBorder(),
                          errorText: _getErrorText(index),
                        ),
                        onChanged: (value) => setState(() {}),
                      );
                    },
                  );
                },
              ),
            )),

            // Dealer selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Geber:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: List.generate(4, (index) {
                        final playerName = _playerControllers[index].text;
                        return FilterChip(
                          label: Text(playerName.isEmpty 
                            ? 'Spieler ${index + 1}' 
                            : playerName),
                          selected: _selectedDealerIndex == index,
                          onSelected: playerName.isEmpty ? null : (selected) {
                            setState(() => _selectedDealerIndex = index);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Base value input
            TextField(
              controller: _baseValueController,
              decoration: const InputDecoration(
                labelText: 'Grundwert (Cents)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _canStartGame() ? _startGame : null,
              child: const Text('Spiel starten'),
            ),
          ],
        ),
      ),
    );
  }

  String? _getErrorText(int index) {
    final value = _playerControllers[index].text;
    if (value.isEmpty) return null;

    // Check for duplicates in current game setup only
    int occurrences = 0;
    for (var controller in _playerControllers) {
      if (controller.text.toLowerCase() == value.toLowerCase()) {
        occurrences++;
      }
    }

    if (occurrences > 1) {
      return 'Name bereits in dieser Runde vergeben';
    }
    return null;
  }

  bool _canStartGame() {
    // Check if all players are entered
    final names = _playerControllers.map((c) => c.text.trim()).toList();
    if (names.any((name) => name.isEmpty)) return false;

    // Check for duplicates in current game
    if (names.toSet().length != 4) return false;

    // Check if base value is valid
    final baseValue = int.tryParse(_baseValueController.text);
    if (baseValue == null || baseValue <= 0) return false;

    return true;
  }

  Future<void> _startGame() async {
    final players = _playerControllers.map((c) => c.text).toList();
    final baseValue = int.parse(_baseValueController.text);

    // Create or update player documents in Firestore
    final db = FirebaseFirestore.instance;
    for (final playerName in players) {
      final playerRef = db.collection('players').doc(playerName);
      final playerDoc = await playerRef.get();
      
      if (!playerDoc.exists) {
        await playerRef.set(Player(name: playerName).toFirestore());
      }
    }

    // Create new game document
    final gameRef = await db.collection('games').add({
      'date': Timestamp.now(),
      'players': players,
      'dealer': _selectedDealerIndex,
      'baseValue': baseValue,
      'rounds': [],
      'isActive': true,
    });

    if (!mounted) return;

    // Navigate to gameplay screen
    Navigator.pushReplacementNamed(
      context, 
      '/gameplay',
      arguments: {
        'gameId': gameRef.id,
        'players': players,
        'dealer': _selectedDealerIndex,
        'baseValue': baseValue,
      },
    );
  }

  @override
  void dispose() {
    for (var controller in _playerControllers) {
      controller.dispose();
    }
    _baseValueController.dispose();
    super.dispose();
  }
} 