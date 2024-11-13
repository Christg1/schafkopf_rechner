import 'package:flutter/material.dart';
import 'package:schafkopf_rechner/models/game_types.dart';

class NewGameDialog extends StatelessWidget {
  final GameType selectedGameType;
  final Function(GameType) onGameTypeChanged;
  final int playerCount;

  const NewGameDialog({
    super.key,
    required this.selectedGameType,
    required this.onGameTypeChanged,
    required this.playerCount,
  });

  @override
  Widget build(BuildContext context) {
    final availableGameTypes = playerCount == 3 
        ? GameType.values.where((type) => type.allowedInThreePlayerGame)
        : GameType.values;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Neues Spiel',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: SegmentedButton<GameType>(
                segments: availableGameTypes.map((type) => ButtonSegment(
                  value: type,
                  label: Text(type.name),
                  icon: Icon(_getGameTypeIcon(type)),
                )).toList(),
                selected: {selectedGameType},
                onSelectionChanged: (Set<GameType> selection) {
                  onGameTypeChanged(selection.first);
                },
              ),
            ),
            // ... rest of the dialog content
          ],
        ),
      ),
    );
  }

  IconData _getGameTypeIcon(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return Icons.pets;
      case GameType.farbspiel:
        return Icons.person;
      case GameType.wenz:
        return Icons.looks_one;
      case GameType.farbwenz:
        return Icons.filter_1;
      case GameType.geier:
        return Icons.catching_pokemon;
      case GameType.farbgeier:
        return Icons.filter_2;
      case GameType.farbspiel:
        return Icons.palette;
      case GameType.ramsch:
        return Icons.trending_down;
      default:
        return Icons.help_outline;
    }
  }
} 