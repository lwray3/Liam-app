import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'burnout_mood_analysis.dart';
import 'mood_trigger_analysis.dart';
import 'date_range_selector.dart';
import 'goal_progress_visualization.dart';
import 'mood_forecasting.dart';
import 'sleep_mood_correlation.dart';
import 'journal_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---- DATA ----
  List<Map<String, dynamic>> moodData = [];
  List<Map<String, dynamic>> habitData = [];
  List<Map<String, dynamic>> journalEntries = [];

  // ---- LOADING FLAGS ----
  bool isLoadingMoods = true;
  bool isLoadingHabits = true;
  bool isLoadingJournal = true;

  // ---- FETCHERS ----
  Future<void> loadMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final resp = await http.get(
      Uri.parse('http://10.0.2.2:3000/moods'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return;

    if (resp.statusCode == 200) {
      final rows = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
      setState(() {
        moodData = rows
            .map((r) => {
                  'date': r['date'], // ISO string recommended
                  'mood': (r['mood'] as num).toDouble(),
                })
            .toList();
        isLoadingMoods = false;
      });
      computeMoodDistribution();
    } else {
      setState(() => isLoadingMoods = false);
    }
  }

  Future<void> loadHabits() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final resp = await http.get(
      Uri.parse('http://10.0.2.2:3000/habits'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (!mounted) return;

    if (resp.statusCode == 200) {
      final rows = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
      setState(() {
        habitData = rows; // [{habit: String, completion: num(0-100)}, ...]
        isLoadingHabits = false;
      });
    } else {
      setState(() => isLoadingHabits = false);
    }
  }

  Future<void> loadJournals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final resp = await http.get(
        Uri.parse('http://10.0.2.2:3000/journals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final rows = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        setState(() {
          journalEntries = rows; // each row should include 'timestamp'
          isLoadingJournal = false;
        });
      } else {
        setState(() => isLoadingJournal = false);
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingJournal = false);
    }
  }

  // ---- COMPUTED STATS ----
  double get averageMood {
    if (moodData.isEmpty) return 0;
    final sum =
        moodData.fold<double>(0, (s, m) => s + (m['mood'] as num).toDouble());
    return sum / moodData.length;
  }

  double get habitSuccessRate {
    if (habitData.isEmpty) return 0;
    final sum = habitData.fold<double>(
        0, (s, h) => s + (h['completion'] as num).toDouble());
    return sum / habitData.length; // 0-100
  }

  int get activeDaysThisMonth {
    if (moodData.isEmpty) return 0;
    final now = DateTime.now();
    final days = <String>{};
    for (final m in moodData) {
      final d = DateTime.tryParse(m['date'].toString());
      if (d != null && d.year == now.year && d.month == now.month) {
        days.add('${d.year}-${d.month}-${d.day}');
      }
    }
    return days.length;
  }

  int get journalCountThisMonth {
    final now = DateTime.now();
    return journalEntries.where((e) {
      final d = DateTime.tryParse(e['timestamp'].toString());
      return d != null && d.year == now.year && d.month == now.month;
    }).length;
  }

  // ---- MOOD DISTRIBUTION ----
  List<Map<String, dynamic>> moodDistribution = [];

  void computeMoodDistribution() {
    final Map<String, int> counts = {};
    for (final m in moodData) {
      final category = moodCategory(((m['mood']) as num).toDouble());
      counts[category] = (counts[category] ?? 0) + 1;
    }
    setState(() {
      moodDistribution = counts.entries
          .map((e) => {
                'name': e.key,
                'value': e.value.toDouble(),
                'color': moodColor(e.key),
              })
          .toList();
    });
  }

  // ---- AI INSIGHTS ----
  List<Map<String, dynamic>> aiInsights = [];
  bool loadingInsights = true;
  String? insightsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    loadMoods();
    loadHabits();
    loadJournals();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final uri = Uri.parse('http://10.0.2.2:3000/insights'); // backend route
      final resp =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (resp.statusCode != 200) {
        throw Exception('Failed to fetch insights: ${resp.body}');
      }

      final data = jsonDecode(resp.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        aiInsights = List<Map<String, dynamic>>.from(data);
        loadingInsights = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        insightsError = e.toString();
        loadingInsights = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Advanced'),
            Tab(text: 'AI Predictions'),
            Tab(text: 'Deep Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicAnalytics(),
          const GoalProgressVisualization(),
          const MoodForecasting(),
          const SleepMoodCorrelation(),
        ],
      ),
    );
  }

  Widget _buildBasicAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Insights into your wellness journey",
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // Dynamic stat cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                title: 'Average Mood',
                value: moodData.isEmpty
                    ? '—'
                    : '${averageMood.toStringAsFixed(1)}/10',
                icon: '😊',
                subtitle: moodData.isEmpty ? 'No entries yet' : 'Last 30 days',
              ),
              _StatCard(
                title: 'Habit Success Rate',
                value: habitData.isEmpty
                    ? '—'
                    : '${habitSuccessRate.toStringAsFixed(0)}%',
                icon: '🎯',
                subtitle:
                    habitData.isEmpty ? 'No habits yet' : 'Average this month',
              ),
              _StatCard(
                title: 'Active Days',
                value: moodData.isEmpty ? '0/30' : '${activeDaysThisMonth}/30',
                icon: '📅',
                subtitle: 'This month',
              ),
              _StatCard(
                title: 'Journal Entries',
                value: journalEntries.isEmpty
                    ? '0'
                    : '${journalCountThisMonth} entries',
                icon: '📝',
                subtitle:
                    journalEntries.isEmpty ? 'No entries yet' : 'This month',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Charts (with empty-state guards)
          _buildMoodLineChart(),
          const SizedBox(height: 16),
          _buildMoodPieChart(),
          const SizedBox(height: 20),
          _buildHabitBarChart(),
          const SizedBox(height: 20),
          _buildInsights(),
        ],
      ),
    );
  }

  Widget _buildMoodLineChart() {
    if (moodData.isEmpty) {
      return Card(
        child: SizedBox(
          height: 140,
          child: Center(child: Text("No mood data yet")),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mood Trend",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("Your mood journey"),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index >= 0 && index < moodData.length) {
                            return Text(moodData[index]['date']);
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: moodData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(),
                            (e.value['mood'] as num).toDouble());
                      }).toList(),
                      isCurved: true,
                      color: Colors.pink,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodPieChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mood Distribution",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("How often you feel each mood"),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: moodDistribution.isEmpty
                  ? const Center(child: Text("No mood data available"))
                  : PieChart(
                      PieChartData(
                        sections: moodDistribution.map((entry) {
                          return PieChartSectionData(
                            value: (entry['value'] as num).toDouble(),
                            title: entry['name'],
                            color: entry['color'],
                            radius: 60,
                            titleStyle: const TextStyle(fontSize: 12),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitBarChart() {
    if (habitData.isEmpty) {
      return Card(
        child: SizedBox(
          height: 140,
          child: Center(child: Text("No habit data yet")),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Habit Completion Rates",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("How well you're sticking to your habits this month"),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    leftTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index >= 0 && index < habitData.length) {
                            return Text(
                              habitData[index]['habit'].toString(),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  barGroups: habitData.asMap().entries.map((entry) {
                    final y = (entry.value['completion'] as num).toDouble();
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: y,
                          color: Colors.pink,
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsights() {
    if (loadingInsights) {
      return const Center(child: CircularProgressIndicator());
    }
    if (insightsError != null) {
      return Text("Error: $insightsError",
          style: const TextStyle(color: Colors.red));
    }
    if (aiInsights.isEmpty) {
      return const Text("No insights yet. Keep tracking your habits!");
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AI-Powered Insights",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("Personalized recommendations based on your data"),
            const SizedBox(height: 16),
            ...aiInsights.map((insight) => _insightCard(
                  emoji: insight['emoji'] ?? '💡',
                  title: insight['title'] ?? 'Insight',
                  color: _colorForProbability(
                      ((insight['score'] ?? 70) as num).toInt()),
                  message: insight['message'] ?? '',
                )),
          ],
        ),
      ),
    );
  }

  Color _colorForProbability(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 65) return Colors.orange;
    return Colors.red;
  }

  Widget _insightCard({
    required String emoji,
    required String title,
    required Color color,
    required String message,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(emoji),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ]),
          const SizedBox(height: 6),
          Text(message,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w > 600 ? (w / 2 - 24) : w - 32; // responsive
    return Card(
      child: SizedBox(
        width: cardWidth,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text(icon, style: const TextStyle(fontSize: 20)),
              ]),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
