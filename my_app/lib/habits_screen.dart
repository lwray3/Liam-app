import 'package:flutter/material.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final List<Map<String, dynamic>> _habits = [];

  final TextEditingController _habitController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  void _addHabit() {
    if (_habits.length >= 5) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Habit"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _habitController,
                decoration: const InputDecoration(labelText: "Habit Name"),
              ),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: "Progress Note"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _habitController.clear();
                _noteController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (_habitController.text.trim().isNotEmpty) {
                  setState(() {
                    _habits.add({
                      'habit': _habitController.text.trim(),
                      'note': _noteController.text.trim(),
                    });
                  });
                }
                _habitController.clear();
                _noteController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _habitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE0E0),
      floatingActionButton: null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const Center(
                  child: Text(
                    'My Habits',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCC4E4E),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEFEF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, color: Colors.black12)
                  ],
                ),
                child: _habits.isEmpty
                    ? const Center(child: Text("No habits added yet."))
                    : ListView.separated(
                        itemCount: _habits.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final habit = _habits[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Habit ${index + 1}: ${habit['habit']}",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text("Progress: ${habit['note']}"),
                            ],
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 12), // spacing below the box
            if (_habits.length < 5)
              Center(
                child: FloatingActionButton(
                  onPressed: _addHabit,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.orange),
                ),
              ),

            const SizedBox(height: 12),
            const Text(
              'Make sure you allow the user to add new habits as well as add progress to old ones',
              style: TextStyle(fontSize: 12, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
