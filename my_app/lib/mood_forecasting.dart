import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ---------- Helpers you likely already have ----------
String moodCategory(double score) {
  if (score >= 8) return "Amazing";
  if (score >= 6) return "Good";
  if (score >= 4) return "Okay";
  if (score >= 2) return "Low";
  return "Difficult";
}

Color moodColor(String category) {
  switch (category) {
    case "Amazing":
      return const Color(0xFF10B981);
    case "Good":
      return const Color(0xFF3B82F6);
    case "Okay":
      return const Color(0xFF6B7280);
    case "Low":
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFFEF4444);
  }
}

IconData moodIcon(double score) {
  if (score >= 8) return Icons.emoji_emotions;
  if (score >= 6) return Icons.sentiment_satisfied_alt;
  if (score >= 4) return Icons.sentiment_neutral;
  if (score >= 2) return Icons.sentiment_dissatisfied;
  return Icons.sentiment_very_dissatisfied;
}

// ---------- Data models ----------
class HabitImpact {
  final String habit;
  final double impact; // + positive improves mood, - negative worsens mood

  HabitImpact({required this.habit, required this.impact});

  factory HabitImpact.fromJson(Map<String, dynamic> j) => HabitImpact(
      habit: j['habit'] as String, impact: (j['impact'] as num).toDouble());
}

class DayForecast {
  final String day; // e.g., "Friday"
  final double predictedMood; // e.g., 1–10 scale
  final String? reason; // short rationale string
  final String? suggestion; // actionable tip
  final List<HabitImpact> impacts; // per-habit effects

  DayForecast({
    required this.day,
    required this.predictedMood,
    this.reason,
    this.suggestion,
    required this.impacts,
  });

  factory DayForecast.fromJson(Map<String, dynamic> j) {
    final impactsJson = (j['habit_impacts'] as List? ?? [])
        .map((e) => HabitImpact.fromJson(e as Map<String, dynamic>))
        .toList();
    return DayForecast(
      day: j['day'] as String,
      predictedMood: (j['predicted_mood'] as num).toDouble(),
      reason: j['reason'] as String?,
      suggestion: j['suggestion'] as String?,
      impacts: impactsJson,
    );
  }
}

// ---------- API layer ----------
class ForecastApi {
  // Change this to your server URL:
  static const String _baseUrl =
      "http://10.0.2.2:3000"; // or your deployed host
  static const String _path = "/mood/forecast"; // <- adjust to your route

  static Future<List<DayForecast>> fetchForecast() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final res = await http.get(
      Uri.parse("$_baseUrl$_path"),
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode != 200) {
      throw Exception(
          "Forecast request failed (${res.statusCode}): ${res.body}");
    }

    final Map<String, dynamic> body = json.decode(res.body);
    final preds = (body['predictions'] as List? ?? []);
    return preds
        .map((e) => DayForecast.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------- UI ----------
class MoodForecasting extends StatefulWidget {
  const MoodForecasting({super.key});

  @override
  State<MoodForecasting> createState() => _MoodForecastingState();
}

class _MoodForecastingState extends State<MoodForecasting> {
  late Future<List<DayForecast>> _future;

  @override
  void initState() {
    super.initState();
    _future = ForecastApi.fetchForecast();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<DayForecast>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _HeaderAndSubheader(
                title: "AI Mood Forecasting",
                subtitle: "Predictive insights for the week ahead",
                trailing: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeaderAndSubheader(
                    title: "AI Mood Forecasting",
                    subtitle: "Predictive insights for the week ahead",
                  ),
                  SizedBox(height: 12),
                  Text("Couldn’t load forecast. Please try again.",
                      style: TextStyle(color: Colors.red)),
                ],
              );
            }

            final data = snapshot.data ?? [];
            if (data.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _HeaderAndSubheader(
                    title: "AI Mood Forecasting",
                    subtitle: "Predictive insights for the week ahead",
                  ),
                  SizedBox(height: 12),
                  Text(
                      "No predictions yet. Start completing habits to get a forecast."),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderAndSubheader(
                  title: "AI Mood Forecasting",
                  subtitle: "Predictive insights for the week ahead",
                ),
                const SizedBox(height: 8),

                // List of daily forecasts
                ...data.map((f) {
                  final cat = moodCategory(f.predictedMood);
                  final color = moodColor(cat);
                  final icon = moodIcon(f.predictedMood);

                  // Show top 2 drivers by absolute impact
                  final topDrivers = [...f.impacts]
                    ..sort((a, b) => b.impact.abs().compareTo(a.impact.abs()));
                  final displayDrivers = topDrivers.take(2).toList();

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.15),
                        child: Icon(icon, color: color),
                      ),
                      title: Text(
                        "${f.day}: ${f.predictedMood.toStringAsFixed(1)} (${cat})",
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: color),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (f.reason != null && f.reason!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(f.reason!),
                            ),
                          if (displayDrivers.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: -6,
                              children: displayDrivers.map((d) {
                                final sign = d.impact >= 0 ? "+" : "";
                                final chipColor =
                                    d.impact >= 0 ? Colors.green : Colors.red;
                                return Chip(
                                  label: Text(
                                      "${d.habit}  $sign${d.impact.toStringAsFixed(2)}"),
                                  backgroundColor: chipColor.withOpacity(0.12),
                                  labelStyle:
                                      TextStyle(color: chipColor.shade700),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                          ],
                          if (f.suggestion != null && f.suggestion!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                f.suggestion!,
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderAndSubheader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _HeaderAndSubheader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
