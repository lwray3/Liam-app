import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 👇 Add this import (make sure GraphAwesome exists with: GraphAwesome({required List<Pillar> pillars}))
import 'graph_awesome.dart';

class PillarsScreen extends StatefulWidget {
  const PillarsScreen({super.key});

  @override
  State<PillarsScreen> createState() => _PillarsScreenState();
}

// ------ Models (keep here or move to models.dart and import from both screens) ------
class Habit {
  final int id;
  final String title;
  final bool completed;
  final int streak;

  const Habit({
    required this.id,
    required this.title,
    required this.completed,
    required this.streak,
  });

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        completed: (j['completed'] == true || j['completed'] == 1),
        streak: (j['streak'] as num).toInt(),
      );
}

class Pillar {
  final int id;
  final String title;
  final String description;
  final int progress; // 0..100
  final Color color;
  final List<Habit> habits;

  const Pillar({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.color,
    required this.habits,
  });

  factory Pillar.fromJson(Map<String, dynamic> j) => Pillar(
        id: (j['id'] as num).toInt(),
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        progress: (j['progress'] as num? ?? 0).toInt(),
        color: Color((j['color'] as num? ?? 0xFF3B82F6).toInt()),
        habits: ((j['habits'] as List?) ?? [])
            .map((h) => Habit.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

// ---------------- Screen ----------------
class _PillarsScreenState extends State<PillarsScreen> {
  static const String baseUrl = 'http://10.0.2.2:3000';

  final List<Pillar> _pillars = [];
  bool _loading = true;
  String? _error;

  // Dialog controllers
  final _pillarTitleCtrl = TextEditingController();
  final _pillarDescCtrl = TextEditingController();
  final _habitTitleCtrl = TextEditingController();

  Future<String> _jwt() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('jwt_token') ?? '';
  }

  @override
  void initState() {
    super.initState();
    _fetchPillars();
  }

  Future<void> _fetchPillars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _jwt();
      final res = await http.get(
        Uri.parse('$baseUrl/pillars'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) {
        throw Exception('Failed to load pillars: ${res.body}');
      }
      final data = json.decode(res.body) as List<dynamic>;
      final parsed =
          data.map((e) => Pillar.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _pillars
          ..clear()
          ..addAll(parsed);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createPillar() async {
    final title = _pillarTitleCtrl.text.trim();
    final description = _pillarDescCtrl.text.trim();
    if (title.isEmpty) return;

    try {
      final token = await _jwt();
      final res = await http.post(
        Uri.parse('$baseUrl/pillars'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'title': title, 'description': description}),
      );
      if (res.statusCode != 200) {
        throw Exception('Failed to create pillar: ${res.body}');
      }

      final Map<String, dynamic> body = json.decode(res.body);
      // If server returns full pillar:
      final pillar = body.containsKey('habits')
          ? Pillar.fromJson(body)
          : Pillar(
              id: (body['id'] as num).toInt(),
              title: title,
              description: description,
              progress: 0,
              color: const Color(0xFF3B82F6),
              habits: const [],
            );

      if (!mounted) return;
      setState(() {
        _pillars.insert(0, pillar);
      });

      _pillarTitleCtrl.clear();
      _pillarDescCtrl.clear();
      Navigator.of(context).pop();

      // Optional: resync to get server-calculated fields
      _fetchPillars();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create pillar failed: $e')),
      );
    }
  }

  Future<void> _addHabit(int pillarId) async {
    final title = _habitTitleCtrl.text.trim();
    if (title.isEmpty) return;

    try {
      final token = await _jwt();
      final res = await http.post(
        Uri.parse('$baseUrl/pillars/$pillarId/habits'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'title': title}),
      );
      if (res.statusCode != 200) {
        throw Exception('Failed to add habit: ${res.body}');
      }

      final Map<String, dynamic> body = json.decode(res.body); // e.g. { id: n }
      final newHabit = Habit(
        id: (body['id'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        title: title,
        completed: false,
        streak: 0,
      );

      if (!mounted) return;
      setState(() {
        final idx = _pillars.indexWhere((p) => p.id == pillarId);
        if (idx != -1) {
          final p = _pillars[idx];
          _pillars[idx] = Pillar(
            id: p.id,
            title: p.title,
            description: p.description,
            progress: p.progress,
            color: p.color,
            habits: [newHabit, ...p.habits],
          );
        }
      });

      _habitTitleCtrl.clear();
      Navigator.of(context).pop();

      // Optional: full refresh for authoritative values
      _fetchPillars();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Add habit failed: $e')));
    }
  }

  Future<void> _toggleHabit(int habitId) async {
    try {
      final token = await _jwt();
      final res = await http.patch(
        Uri.parse('$baseUrl/habits/$habitId/toggle'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) {
        throw Exception('Toggle failed: ${res.body}');
      }
      await _fetchPillars();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Toggle failed: $e')));
    }
  }

  void _showAddPillarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create New Pillar"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pillarTitleCtrl,
              decoration: const InputDecoration(labelText: 'Pillar Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pillarDescCtrl,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _createPillar,
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  void _showAddHabitDialog(Pillar p) {
    _habitTitleCtrl.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Habit to ${p.title}"),
        content: TextField(
          controller: _habitTitleCtrl,
          decoration: const InputDecoration(labelText: 'Habit Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => _addHabit(p.id), child: const Text("Add Habit")),
        ],
      ),
    );
  }

  // 👉 NEW: Navigate to graphs & pass all pillars/habits
  void _openGraphs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GraphAwesome(pillars: List<Pillar>.unmodifiable(_pillars)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pillars & Habits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'View Habit Graphs',
            onPressed: _pillars.isEmpty ? null : _openGraphs,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddPillarDialog,
            tooltip: 'Add Pillar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Build your life on strong foundations',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ..._pillars.map(_pillarCard),
                    if (_pillars.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text(
                              "No pillars yet — add one with the + button."),
                        ),
                      ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _pillarTitleCtrl.dispose();
    _pillarDescCtrl.dispose();
    _habitTitleCtrl.dispose();
    super.dispose();
  }

  Widget _pillarCard(Pillar p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.track_changes, color: p.color),
                const SizedBox(width: 8),
                Text(
                  p.title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("${p.progress}%", style: const TextStyle(fontSize: 18)),
                const Text("This week",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          if (p.description.isNotEmpty) Text(p.description),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (p.progress.clamp(0, 100)) / 100.0,
            color: p.color,
            backgroundColor: p.color.withOpacity(0.2),
            minHeight: 6,
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Habits", style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Habit"),
              onPressed: () => _showAddHabitDialog(p),
            ),
          ]),
          const SizedBox(height: 6),
          ...p.habits.map(
            (h) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      IconButton(
                        icon: Icon(
                          h.completed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: h.completed ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _toggleHabit(h.id),
                      ),
                      Text(
                        h.title,
                        style: TextStyle(
                          decoration: h.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: h.completed ? Colors.grey : null,
                        ),
                      ),
                    ]),
                    Chip(label: Text("🔥 ${h.streak}")),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}
