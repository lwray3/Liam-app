import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // keep if you'll add charts later
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Uses Pillar/Habit models from pillars_screen.dart (or move to models.dart)
import 'pillars_screen.dart';

class GraphAwesome extends StatefulWidget {
  final List<Pillar> pillars;

  const GraphAwesome({super.key, required this.pillars});

  @override
  State<GraphAwesome> createState() => _GraphAwesomeState();
}

class _GraphAwesomeState extends State<GraphAwesome> {
  // ---- existing ----
  int _streak = 0;
  List<Habit> get _allHabits => [for (final p in widget.pillars) ...p.habits];
  int get _pillarsCount => widget.pillars.length;
  int get _habitsCount => _allHabits.length;

  // ---- NEW: mood state ----
  double _moodScore = 5; // slider 1..10
  bool _moodSubmittedToday = false; // UI toggle after submit
  int? _moodTodayValue; // if server returns today’s value

  String _todayYmd() {
    final now = DateTime.now();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  @override
  void initState() {
    super.initState();
    _loadStreak();
    _checkMoodToday(); // <-- NEW
  }

  Future<void> _loadStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse("http://10.0.2.2:3000/streak"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _streak = data["streak"] ?? 0;
        });
      } else {
        // non-200; optionally show a snackbar
        // ignore for now
      }
    } catch (e) {
      // ignore; optionally show a snackbar
    }
  }

  // ---- NEW: check if mood already logged today ----
  Future<void> _checkMoodToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final res = await http.get(
        Uri.parse("http://10.0.2.2:3000/moods/today"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final exists = body['exists'] == true;
        setState(() {
          _moodSubmittedToday = exists;
          _moodTodayValue = exists ? (body['score'] as num?)?.toInt() : null;
        });
      } else {
        // treat as not submitted; server will enforce uniqueness anyway
        setState(() {
          _moodSubmittedToday = false;
          _moodTodayValue = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moodSubmittedToday = false;
        _moodTodayValue = null;
      });
    }
  }

  // ---- NEW: submit today’s mood ----
  Future<void> _submitMoodToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final res = await http.post(
        Uri.parse("http://10.0.2.2:3000/moods"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "date": _todayYmd(),
          "score": _moodScore,
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _moodSubmittedToday = true;
          _moodTodayValue = _moodScore.round();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mood logged for today ✅")),
        );
        // If streak depends on mood entries, refresh it:
        _loadStreak();
      } else if (res.statusCode == 409) {
        // duplicate (already logged)
        setState(() => _moodSubmittedToday = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Already logged mood today.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res.body}")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Habits Overview")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Welcome back!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Here's how you're doing today",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // ---- NEW: Today's Mood card (once/day) ----
            _buildTodaysMoodCard(),
            const SizedBox(height: 16),

            // Dashboard cards grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatCard(
                  "Current Streak",
                  "$_streak days",
                  "Amazing consistency! 🔥",
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildStatCard(
                  "Pillars",
                  "$_pillarsCount",
                  "Foundations you're growing",
                  Icons.track_changes,
                  Colors.blue,
                ),
                _buildStatCard(
                  "Habits",
                  "$_habitsCount",
                  "Total habits across pillars",
                  Icons.checklist_rounded,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Habits + Weekly Progress
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: _buildTodaysHabitsCard(),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: _buildWeeklyProgressCard(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- NEW: UI for today's mood input/summary ----
  Widget _buildTodaysMoodCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Mood",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_moodSubmittedToday)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Logged for ${_todayYmd()}",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Chip(label: Text("Score: ${_moodTodayValue ?? '-'}")),
                ],
              )
            else ...[
              Text("How are you feeling today?",
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text("1"),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _moodScore.toStringAsFixed(0),
                      value: _moodScore,
                      onChanged: (v) => setState(() => _moodScore = v),
                    ),
                  ),
                  const Text("10"),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _submitMoodToday,
                  icon: const Icon(Icons.check),
                  label: const Text("Log Today"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 170,
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    Icon(icon, size: 18, color: color),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Uses actual habits from `widget.pillars`
  Widget _buildTodaysHabitsCard() {
    final habits = _allHabits;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Habits",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              habits.isEmpty
                  ? "No habits yet — add one from your Pillars screen."
                  : "Keep up the great work!",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (habits.isEmpty)
              const SizedBox.shrink()
            else
              ...habits.map((h) {
                // Find which pillar it belongs to (for color/label)
                final pillar = widget.pillars.firstWhere(
                  (p) => p.habits.any((ph) => ph.id == h.id),
                  orElse: () => widget.pillars.isNotEmpty
                      ? widget.pillars.first
                      : Pillar(
                          id: -1,
                          title: "Pillar",
                          description: "",
                          progress: 0,
                          color: Colors.grey,
                          habits: const [],
                        ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(
                          h.completed
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: h.completed ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.title),
                            Text(
                              pillar.title,
                              style: TextStyle(
                                color: pillar.color.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ]),
                      Chip(label: Text("🔥 ${h.streak}")),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  /// Uses real pillar progress & colors
  Widget _buildWeeklyProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Weekly Progress",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Your pillar development this week",
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            if (widget.pillars.isEmpty)
              const Text("No pillars yet.")
            else
              ...widget.pillars.map((p) {
                final progress = p.progress.clamp(0, 100);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.circle, size: 10, color: p.color),
                            const SizedBox(width: 6),
                            Text(p.title),
                          ]),
                          Text("$progress%"),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress / 100.0,
                        minHeight: 6,
                        color: p.color,
                        backgroundColor: p.color.withOpacity(0.15),
                      ),
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
