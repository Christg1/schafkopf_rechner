import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import 'dart:math';

class AverageGameValueChart extends StatelessWidget {
  final List<Session> sessions;

  const AverageGameValueChart({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(child: Text('Keine Daten verfügbar'));
    }

    // Calculate moving average of game values
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    List<FlSpot> movingAverage = [];
    const windowSize = 10; // Moving average window size
    
    for (int i = 0; i < sortedSessions.length; i++) {
      final startIdx = i >= windowSize ? i - windowSize + 1 : 0;
      final windowSessions = sortedSessions.sublist(startIdx, i + 1);
      
      double totalValue = 0;
      int totalGames = 0;
      
      for (final session in windowSessions) {
        for (final round in session.rounds) {
          totalValue += round.value;
          totalGames++;
        }
      }
      
      if (totalGames > 0) {
        movingAverage.add(FlSpot(
          i.toDouble(),
          totalValue / totalGames,
        ));
      }
    }

    // Find max value for Y axis
    final maxY = movingAverage.fold<double>(0, 
        (max, spot) => spot.y > max ? spot.y : max);
    final roundedMaxY = ((maxY + 5) ~/ 5) * 5.0;  // Round up to nearest 5

    return LineChart(
      LineChartData(
        minY: 0,  // Force Y axis to start at 0
        maxY: roundedMaxY,  // Use rounded max value
        gridData: FlGridData(
          horizontalInterval: 5,
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
              interval: 5,
              reservedSize: 40,
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
        lineBarsData: [
          LineChartBarData(
            spots: movingAverage,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
} 