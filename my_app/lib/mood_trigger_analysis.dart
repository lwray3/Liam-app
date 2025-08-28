// mood_trigger_analysis.dart
import 'package:flutter/material.dart';

class MoodTriggerAnalysis extends StatelessWidget {
  const MoodTriggerAnalysis({super.key});

  final List<Map<String, dynamic>> triggerData = const [
    {"trigger": "Work Stress", "impact": 85, "change": -12, "type": "negative"},
    {"trigger": "Exercise", "impact": 78, "change": 15, "type": "positive"},
    {"trigger": "Social Media", "impact": 72, "change": -8, "type": "negative"},
    {
      "trigger": "Sleep Quality",
      "impact": 90,
      "change": 20,
      "type": "positive"
    },
    {"trigger": "Weather", "impact": 45, "change": 5, "type": "neutral"},
    {"trigger": "Family Time", "impact": 88, "change": 18, "type": "positive"},
  ];

  Color getTypeColor(String type) {
    switch (type) {
      case 'positive':
        return Colors.green;
      case 'negative':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.amber),
                SizedBox(width: 8),
                Text("Mood Trigger Analysis",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ],
            ),
            const SizedBox(height: 4),
            const Text("Identify what influences your mood most",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ...triggerData.map((item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['trigger'],
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        Row(
                          children: [
                            Icon(
                              item['change'] > 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 16,
                              color: item['change'] > 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item['change'] > 0 ? '+' : ''}${item['change']}%',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item['impact'] / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      color: getTypeColor(item['type']),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${item['impact']}% impact on mood",
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text(item['type'],
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: getTypeColor(item['type'])))
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ))
          ],
        ),
      ),
    );
  }
}
