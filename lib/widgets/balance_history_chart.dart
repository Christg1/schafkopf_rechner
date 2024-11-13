import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

class BalanceHistoryChart extends StatelessWidget {
  final List<Session> sessions;

  const BalanceHistoryChart({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(child: Text('Keine Daten verfügbar'));
    }

    // Get all unique players
    final players = <String>{};
    for (final session in sessions) {
      players.addAll(session.players);
    }

    // Calculate cumulative balances for each player
    Map<String, List<FlSpot>> playerSpots = {};
    
    // Sort sessions by date
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Add starting point (0) for each player
    for (var player in players) {
      playerSpots[player] = [
        FlSpot(0, 0), // Start at 0
      ];
    }

    // Calculate spots for each player
    double currentBalance = 0;
    for (int i = 0; i < sortedSessions.length; i++) {
      final session = sortedSessions[i];
      for (var player in players) {
        currentBalance = (playerSpots[player]!.last.y + 
            (session.playerBalances[player] ?? 0));
        playerSpots[player]!.add(FlSpot(i + 1, currentBalance));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.outlineVariant,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}€');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(sortedSessions.length / 5, 1),
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedSessions.length) return const Text('');
                return Text(
                  DateFormat('dd.MM').format(sortedSessions[value.toInt()].date),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: playerSpots.entries.map((entry) {
          final color = _getPlayerColor(entry.key, players.length);
          return LineChartBarData(
            spots: entry.value,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          );
        }).toList(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Theme.of(context).colorScheme.surface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final playerName = playerSpots.entries
                    .firstWhere((entry) => entry.value.contains(spot))
                    .key;
                return LineTooltipItem(
                  '$playerName\n${spot.y.toStringAsFixed(2)}€',
                  TextStyle(color: _getPlayerColor(playerName, players.length)),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Color _getPlayerColor(String player, int totalPlayers) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    
    return colors[player.hashCode % colors.length];
  }
} 