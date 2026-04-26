import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/sleep_phase.dart';

class SleepPhaseChart extends StatelessWidget {
  final List<SleepPhase> phases;
  final DateTime bedTime;
  final DateTime wakeTime;
  final Color color;

  const SleepPhaseChart({
    super.key,
    required this.phases,
    required this.bedTime,
    required this.wakeTime,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = wakeTime.difference(bedTime).inMilliseconds;
    if (phases.isEmpty || totalMs <= 0) {
      return const Center(
        child: Text(
          'Inte tillräckligt med data',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (final p in phases) {
      final startX =
          p.start.difference(bedTime).inMilliseconds / totalMs;
      final endX = p.end.difference(bedTime).inMilliseconds / totalMs;
      final y = 1.0 - p.kind.curveValue;
      spots.add(FlSpot(startX.clamp(0, 1).toDouble(), y));
      spots.add(FlSpot(endX.clamp(0, 1).toDouble(), y));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
