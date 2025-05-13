import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ActivityChart extends StatelessWidget {
  final Map<String, double> monthlyStats;

  const ActivityChart({Key? key, required this.monthlyStats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: monthlyStats.entries
                .map((e) => FlSpot(
                      double.parse(e.key),
                      e.value,
                    ))
                .toList(),
            isCurved: true,
            color: Color(0xFF0079C0),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Color(0xFF0079C0).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
