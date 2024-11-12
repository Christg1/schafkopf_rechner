import 'dart:ui';

import 'package:flutter/material.dart';

class PlayerSelectionChip extends StatelessWidget {
  final String playerName;
  final bool isSelected;
  final VoidCallback onTap;

  const PlayerSelectionChip({
    super.key,
    required this.playerName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: FilterChip(
          label: Text(
            playerName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected 
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          avatar: CircleAvatar(
            backgroundColor: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant,
            child: Text(
              playerName[0].toUpperCase(),
              style: TextStyle(
                color: isSelected
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          onSelected: (_) => onTap(),
        ),
      ),
    );
  }
} 