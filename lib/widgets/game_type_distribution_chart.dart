import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/game_types.dart';
import '../models/session.dart';

class GameTypeDistributionChart extends StatelessWidget {
  final List<Session> sessions;

  const GameTypeDistributionChart({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(child: Text('Keine Daten verfügbar'));
    }

    // Count game types
    Map<GameType, int> gameTypeCounts = {};
    int totalGames = 0;
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        gameTypeCounts[round.gameType] = (gameTypeCounts[round.gameType] ?? 0) + 1;
        totalGames++;
      }
    }

    // Convert to pie chart sections
    final sections = gameTypeCounts.entries.map((entry) {
      final percentage = (entry.value / totalGames) * 100;
      return PieChartSectionData(
        color: _getGameTypeColor(entry.key),
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: GameType.values.map((type) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: _getGameTypeColor(type),
                ),
                const SizedBox(width: 4),
                Text(
                  '${type.displayName} (${gameTypeCounts[type] ?? 0})',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getGameTypeColor(GameType type) {
    switch (type) {
      case GameType.sauspiel:
        return Colors.blue;
      case GameType.wenz:
        return Colors.red;
      case GameType.farbwenz:
        return Colors.orange;
      case GameType.geier:
        return Colors.green;
      case GameType.farbgeier:
        return Colors.teal;
      case GameType.farbspiel:
        return Colors.purple;
      case GameType.ramsch:
        return Colors.brown;
    }
  }
} 