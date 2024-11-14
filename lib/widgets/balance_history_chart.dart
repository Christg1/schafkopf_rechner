import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';

class BalanceHistoryChart extends StatelessWidget {
  final List<Session> sessions;
  // Add some predefined colors for the lines
  final List<Color> lineColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
  ];

  BalanceHistoryChart({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final balanceHistory = _calculateBalanceHistory();
    
    return Column(
      children: [
        Expanded(
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: Theme.of(context).colorScheme.surface,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final playerName = balanceHistory.keys.elementAt(spot.barIndex);
                      return LineTooltipItem(
                        '$playerName: ${spot.y.toStringAsFixed(2)}€',
                        TextStyle(
                          color: lineColors[spot.barIndex % lineColors.length],
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= sessions.length) return const Text('');
                      return Text(
                        DateFormat('dd.MM').format(sessions[value.toInt()].date),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                    interval: 1,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 100, // Increased interval for less cramped y-axis
                    reservedSize: 45, // Increased space for y-axis labels
                  ),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: _createLineBarsData(balanceHistory),
            ),
          ),
        ),
        // Add legend below the chart
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: balanceHistory.keys.map((player) {
            final colorIndex = balanceHistory.keys.toList().indexOf(player);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 3,
                  color: lineColors[colorIndex % lineColors.length],
                ),
                const SizedBox(width: 4),
                Text(
                  player,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  List<LineChartBarData> _createLineBarsData(Map<String, List<double>> balanceHistory) {
    return balanceHistory.entries.map((entry) {
      final colorIndex = balanceHistory.keys.toList().indexOf(entry.key);
      return LineChartBarData(
        spots: entry.value.asMap().entries.map((point) {
          return FlSpot(point.key.toDouble(), point.value);
        }).toList(),
        isCurved: true,
        color: lineColors[colorIndex % lineColors.length],
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();
  }

  Map<String, List<double>> _calculateBalanceHistory() {
    final history = <String, List<double>>{};
    
    // Sort sessions by date
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Initialize starting balances
    for (final session in sortedSessions) {
      for (final player in session.players) {
        history.putIfAbsent(player, () => [0.0]);
      }
    }
    
    // Calculate running totals
    for (final session in sortedSessions) {
      for (final entry in session.playerBalances.entries) {
        final previousBalance = history[entry.key]!.last;
        history[entry.key]!.add(previousBalance + entry.value);
      }
      
      // Add current balance for players who didn't play in this session
      for (final player in history.keys) {
        if (!session.playerBalances.containsKey(player)) {
          history[player]!.add(history[player]!.last);
        }
      }
    }
    
    return history;
  }
} 