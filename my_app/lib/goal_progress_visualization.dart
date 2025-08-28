// File: goal_progress_visualization.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GoalProgressVisualization extends StatelessWidget {
  const GoalProgressVisualization({super.key});

  @override
  Widget build(BuildContext context) {
    final pillarProgress = [
      {
        'pillar': 'Mindfulness',
        'currentScore': 78,
        'targetScore': 85,
        'progress': 78,
        'trend': 'improving',
        'timeToGoal': '2 weeks'
      },
      {
        'pillar': 'Physical Health',
        'currentScore': 82,
        'targetScore': 90,
        'progress': 91,
        'trend': 'stable',
        'timeToGoal': '3 weeks'
      },
      {
        'pillar': 'Personal Growth',
        'currentScore': 65,
        'targetScore': 80,
        'progress': 81,
        'trend': 'improving',
        'timeToGoal': '5 weeks'
      },
    ];

    final progressHistory = [
      {
        'week': 'Week 1',
        'Mindfulness': 45,
        'Physical Health': 60,
        'Personal Growth': 40
      },
      {
        'week': 'Week 2',
        'Mindfulness': 52,
        'Physical Health': 65,
        'Personal Growth': 45
      },
      {
        'week': 'Week 3',
        'Mindfulness': 58,
        'Physical Health': 70,
        'Personal Growth': 48
      },
      {
        'week': 'Week 4',
        'Mindfulness': 65,
        'Physical Health': 75,
        'Personal Growth': 55
      },
      {
        'week': 'Week 5',
        'Mindfulness': 70,
        'Physical Health': 78,
        'Personal Growth': 58
      },
      {
        'week': 'Week 6',
        'Mindfulness': 78,
        'Physical Health': 82,
        'Personal Growth': 65
      },
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.track_changes, color: Colors.teal),
                SizedBox(width: 8),
                Text('Goal Progress Visualization',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...pillarProgress.map((pillar) {
              final percent = ((pillar['currentScore'] as num) /
                      (pillar['targetScore'] as num)) *
                  100;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(pillar['pillar'] as String,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '${pillar['currentScore']} / ${pillar['targetScore']}')
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: percent / 100),
                    const SizedBox(height: 4),
                    Text(
                        '${pillar['progress']}% complete — ${pillar['timeToGoal']} to goal',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey))
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            const Text('Progress Over Time',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: progressHistory
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(),
                              e.value['Mindfulness'] as double))
                          .toList(),
                      isCurved: true,
                      color: Colors.teal,
                      barWidth: 3,
                    ),
                    LineChartBarData(
                      spots: progressHistory
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(),
                              e.value['Physical Health'] as double))
                          .toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                    ),
                    LineChartBarData(
                      spots: progressHistory
                          .asMap()
                          .entries
                          .map((e) => FlSpot(e.key.toDouble(),
                              e.value['Personal Growth'] as double))
                          .toList(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                    ),
                  ],
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
