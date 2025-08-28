import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HabitSuccessPredictor extends StatefulWidget {
  const HabitSuccessPredictor({super.key});

  @override
  State<HabitSuccessPredictor> createState() => _HabitSuccessPredictorState();
}

class _HabitSuccessPredictorState extends State<HabitSuccessPredictor> {
  List<Map<String, dynamic>> predictions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchPredictions();
  }

  Future<void> _fetchPredictions() async {
    try {
      final habits = [
        {
          'habit': "Morning Meditation",
          'streak': 12,
          'reflection': 'Weekends are tricky'
        },
        {
          'habit': "Daily Exercise",
          'streak': 5,
          'reflection': 'Weather and overtime'
        },
      ];

      final results = <Map<String, dynamic>>[];
      for (final h in habits) {
        final p = await getHabitPrediction(
          habitName: h['habit'] as String,
          currentStreak: h['streak'] as int,
          reflection: h['reflection'] as String,
        );
        results.add({
          'habit': h['habit'],
          'currentStreak': h['streak'],
          ...p, // merges successProbability, recommendation, riskFactors
          'color': _colorFor(p['successProbability']),
        });
      }

      setState(() {
        predictions = results;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Color _colorFor(int probability) {
    if (probability >= 85) return Colors.green;
    if (probability >= 65) return Colors.orange;
    return Colors.red;
  }

  Future<Map<String, dynamic>> getHabitPrediction({
    required String habitName,
    required int currentStreak,
    required String reflection,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final uri = Uri.parse(
        'http://10.0.2.2:3000/predict'); // Android emulator -> host machine
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'habitName': habitName,
        'currentStreak': currentStreak,
        'reflection': reflection,
        'features': {
          // send any optional telemetry you track
          'weeklyFrequencyTarget': 5,
          'last7Days': [true, true, false, true, true, true, false],
          'timeOfDay': 'morning',
          'sleepHoursAvg': 6.8,
          'stressLevel': 6
        }
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Predict failed: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null)
      return Text('Error: $error', style: const TextStyle(color: Colors.red));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "AI Habit Success Predictor",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                "Machine learning predictions for your habit completion"),
            const SizedBox(height: 16),
            ...predictions.map((prediction) {
              final String habit = prediction['habit'];
              final int currentStreak = prediction['currentStreak'];
              final int successProbability = prediction['successProbability'];
              final String recommendation = prediction['recommendation'];
              final List<String> riskFactors =
                  List<String>.from(prediction['riskFactors']);
              final Color color = prediction['color'];

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(habit,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text("$successProbability%",
                            style: TextStyle(color: color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: successProbability / 100),
                    const SizedBox(height: 8),
                    Text("Current streak: $currentStreak days"),
                    Text("AI Recommendation: $recommendation"),
                    Text("Risk factors: ${riskFactors.join(", ")}",
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
