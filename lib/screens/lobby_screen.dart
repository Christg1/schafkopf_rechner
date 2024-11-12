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
  final List<TextEditingController> _playerControllers = 
    List.generate(4, (index) => TextEditingController());
  final _baseValueController = TextEditingController(text: '0.10');
  int _selectedDealerIndex = 0;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _playerControllers) {
      if (controller.hasListeners) {
        controller.dispose();
      }
    }
    if (_baseValueController.hasListeners) {
      _baseValueController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neue Runde'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('players')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          List<String> previousPlayers = [];
          if (snapshot.hasData) {
            previousPlayers = snapshot.data!.docs
                .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
                .toSet()
                .toList()
                ..sort();
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Player input fields
                      ...List.generate(4, (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Autocomplete<String>(
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
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Geber'),
                              selected: _selectedDealerIndex == index,
                              onSelected: _playerControllers[index].text.isEmpty 
                                  ? null 
                                  : (selected) {
                                      setState(() => _selectedDealerIndex = index);
                                    },
                            ),
                          ],
                        ),
                      )),

                      const SizedBox(height: 16),
                      TextField(
                        controller: _baseValueController,
                        decoration: const InputDecoration(
                          labelText: 'Grundwert (€)',
                          border: OutlineInputBorder(),
                          prefixText: '€ ',
                          hintText: '0.10',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _canStartSession() ? _startSession : null,
                        child: const Text('Spiel starten'),
                      ),

                      if (previousPlayers.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Häufige Spieler:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),

              // Previous Players List
              if (previousPlayers.isNotEmpty)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: previousPlayers.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          avatar: CircleAvatar(
                            child: Text(previousPlayers[index][0].toUpperCase()),
                          ),
                          label: Text(previousPlayers[index]),
                          onPressed: () {
                            // Find first empty controller or the last one
                            final targetControllerIndex = _playerControllers
                                .indexWhere((controller) => controller.text.isEmpty);
                            if (targetControllerIndex != -1) {
                              setState(() {
                                _playerControllers[targetControllerIndex].text = 
                                    previousPlayers[index];
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
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

  bool _canStartSession() {
    // Check if all players are entered
    final names = _playerControllers.map((c) => c.text.trim()).toList();
    if (names.any((name) => name.isEmpty)) return false;

    // Check for duplicates
    if (names.toSet().length != 4) return false;

    // Check if base value is valid
    try {
      final baseValueText = _baseValueController.text.replaceAll(',', '.');
      final baseValueEuro = double.parse(baseValueText);
      return baseValueEuro > 0;
    } catch (e) {
      return false;
    }
  }

  Future<void> _startSession() async {
    if (_canStartSession()) {
      final players = _playerControllers.map((c) => c.text.trim()).toList();
      final baseValue = double.parse(_baseValueController.text.replaceAll(',', '.'));
      
      try {
        final sessionId = await SessionService().createSession(
          players: players,
          baseValue: baseValue,
          initialDealer: _selectedDealerIndex,
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
} 