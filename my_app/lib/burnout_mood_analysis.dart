// burnout_mood_analysis.dart
import 'package:flutter/material.dart';

class BurnoutRiskAssessment extends StatelessWidget {
  const BurnoutRiskAssessment({super.key});

  final int overallRisk = 61;

  final List<Map<String, dynamic>> riskFactors = const [
    {
      "factor": "Sleep Quality",
      "score": 25,
      "status": "good",
      "trend": "improving"
    },
    {
      "factor": "Stress Levels",
      "score": 75,
      "status": "warning",
      "trend": "stable"
    },
    {
      "factor": "Social Connection",
      "score": 40,
      "status": "moderate",
      "trend": "declining"
    },
    {
      "factor": "Physical Activity",
      "score": 80,
      "status": "warning",
      "trend": "improving"
    },
    {
      "factor": "Work-Life Balance",
      "score": 85,
      "status": "high",
      "trend": "declining"
    },
  ];

  final List<Map<String, String>> recommendations = const [
    {
      "priority": "High",
      "action": "Reduce work hours this week",
      "reason": "Work-life balance score is critically high",
      "impact": "Could reduce overall risk by 15%"
    },
    {
      "priority": "Medium",
      "action": "Schedule social activities",
      "reason": "Social connection declining",
      "impact": "Could improve mood stability"
    },
    {
      "priority": "Low",
      "action": "Maintain current exercise routine",
      "reason": "Physical activity showing improvement",
      "impact": "Continue positive trend"
    },
  ];

  Color getRiskColor(int score) {
    if (score < 30) return Colors.green;
    if (score < 60) return Colors.orange;
    return Colors.red;
  }

  String getRiskLevel(int score) {
    if (score < 30) return "Low Risk";
    if (score < 60) return "Moderate Risk";
    return "High Risk";
  }

  Icon getStatusIcon(String status) {
    switch (status) {
      case 'good':
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case 'moderate':
        return const Icon(Icons.warning, size: 16, color: Colors.orange);
      case 'warning':
      case 'high':
        return const Icon(Icons.cancel, size: 16, color: Colors.red);
      default:
        return const Icon(Icons.help_outline, size: 16, color: Colors.grey);
    }
  }

  Color getTrendColor(String trend) {
    switch (trend) {
      case 'improving':
        return Colors.green.shade100;
      case 'declining':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red.shade100;
      case 'Medium':
        return Colors.orange.shade100;
      default:
        return Colors.green.shade100;
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
                Icon(Icons.shield, color: Colors.blue),
                SizedBox(width: 8),
                Text("Burnout Risk Assessment",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            const Text("Early warning system for mental health",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text("$overallRisk%",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: getRiskColor(overallRisk))),
                  Text(getRiskLevel(overallRisk),
                      style: TextStyle(color: getRiskColor(overallRisk))),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: overallRisk / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[300],
                    color: getRiskColor(overallRisk),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text("Risk Factor Breakdown",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...riskFactors.map((f) => Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          getStatusIcon(f['status']),
                          const SizedBox(width: 8),
                          Text(f['factor'],
                              style: const TextStyle(fontSize: 14)),
                        ]),
                        Row(children: [
                          Text("${f['score']}%",
                              style: TextStyle(
                                  color: getRiskColor(f['score']),
                                  fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: getTrendColor(f['trend']),
                            ),
                            child: Text(f['trend'],
                                style: const TextStyle(fontSize: 10)),
                          )
                        ])
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: f['score'] / 100,
                      minHeight: 4,
                      backgroundColor: Colors.grey[200],
                      color: getRiskColor(f['score']),
                    ),
                    const SizedBox(height: 12),
                  ],
                )),
            const Text("Recommendations",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...recommendations.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: getPriorityColor(r['priority']!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['priority']!,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(r['action']!, style: const TextStyle(fontSize: 14)),
                      Text(r['reason']!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      Text(r['impact']!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.blue)),
                    ],
                  ),
                ))
          ],
        ),
      ),
    );
  }
}
