import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JournalEntry {
  final int? id; // not returned by your GET, but handy if you add later
  final String title;
  final String entry; // "content" in your UI; server expects "entry"
  final DateTime timestamp;

  JournalEntry({
    this.id,
    required this.title,
    required this.entry,
    required this.timestamp,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    // Your GET /journal returns: [{ title, entry, timestamp }]
    return JournalEntry(
      title: json['title'] ?? '',
      entry: json['entry'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  // CHANGE THIS to your server base URL
  static const String baseUrl = 'http://10.0.2.2:3000';

  final List<JournalEntry> _entries = [];
  bool _loading = false;
  String? _error;

  Future<String> _getJwtToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token') ?? '';
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getJwtToken();
      final resp = await http.get(
        Uri.parse('$baseUrl/journal'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        final items = data
            .map((e) => JournalEntry.fromJson(e))
            .toList()
            .cast<JournalEntry>();
        setState(() {
          _entries
            ..clear()
            ..addAll(items);
        });
      } else {
        setState(() => _error = 'Failed to load entries (${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Failed to load entries: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveEntry(
      {required String title, required String content}) async {
    try {
      final token = await _getJwtToken();
      final body = {
        'title': title,
        'entry': content, // server expects "entry"
        'timestamp': DateTime.now().toIso8601String(),
      };

      final resp = await http.post(
        Uri.parse('$baseUrl/journal'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (resp.statusCode == 200) {
        // Optimistically add to list without another GET
        setState(() {
          _entries.insert(
            0,
            JournalEntry(
              title: title,
              entry: content,
              timestamp: DateTime.parse(body['timestamp']!),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed (${resp.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  void _showNewEntryDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 24,
            right: 24,
          ),
          child: Wrap(
            children: [
              const Text(
                "New Journal Entry",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: "Your thoughts",
                  alignLabelWithHint: true,
                  hintText: "What's on your mind?",
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isEmpty || content.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Title and content required')),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  await _saveEntry(title: title, content: content);
                },
                child: const Text("Save Entry"),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _fmt(DateTime dt) {
    // yyyy-MM-dd
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  int _entriesThisMonth() {
    final now = DateTime.now();
    return _entries
        .where((e) =>
            e.timestamp.year == now.year && e.timestamp.month == now.month)
        .length;
  }

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE0E0),
      appBar: AppBar(
        title: const Text("Journal"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewEntryDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : ListView(
                    children: [
                      const Text(
                        "Recent Entries",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_entries.isEmpty)
                        const Text(
                            'No entries yet. Tap + to add your first one.'),
                      ..._entries.map((e) => Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.book_outlined),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(e.title,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(_fmt(e.timestamp),
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today,
                                          size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    e.entry,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                      const Text(
                        "Journal Stats",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _StatRow(
                                  label: "This month",
                                  value: "${_entriesThisMonth()} entries"),
                              // keep your other stats if you compute them client-side
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
