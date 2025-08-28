import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SleepMoodCorrelation extends StatefulWidget {
  const SleepMoodCorrelation({super.key});

  @override
  State<SleepMoodCorrelation> createState() => _SleepMoodCorrelationState();
}

class _SleepMoodCorrelationState extends State<SleepMoodCorrelation> {
  final TextEditingController _hoursController = TextEditingController();
  List<Map<String, dynamic>> sleepMoodData = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchSleepData();
  }

  double moodFromSleep(double hours) {
    const baseMood = 8.0; // mood at optimal 8h
    const slope = 0.4; // mood change per hour diff
    return (baseMood + slope * (hours - 8)).clamp(1, 10);
  }

  Future<void> fetchSleepData() async {
    setState(() => loading = true);
    final resp = await http.get(Uri.parse("http://10.0.2.2:3000/sleep/1"));
    if (resp.statusCode == 200) {
      final List data = jsonDecode(resp.body);
      setState(() {
        sleepMoodData = data
            .map((e) => {
                  'sleep': e['hours'] * 1.0,
                  'mood': moodFromSleep(e['hours'] * 1.0),
                  'date': e['date']
                })
            .toList();
        loading = false;
      });
    } else {
      throw Exception("Failed to fetch sleep data");
    }
  }

  Future<void> saveSleep(double hours) async {
    final date = DateTime.now().toIso8601String().split('T').first;
    final resp = await http.post(
      Uri.parse('http://10.0.2.2:3000/sleep'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': 1,
        'date': date,
        'hours': hours,
      }),
    );

    if (resp.statusCode == 200) {
      await fetchSleepData(); // Refresh chart after saving
    } else {
      throw Exception('Failed to save sleep data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.brightness_3, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Sleep vs Mood Correlation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Hours slept",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                final hours = double.tryParse(_hoursController.text);
                if (hours != null) {
                  saveSleep(hours);
                  _hoursController.clear();
                }
              },
              child: const Text("Save Sleep"),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                height: 200,
                child: ScatterChart(
                  ScatterChartData(
                    scatterSpots: sleepMoodData
                        .map((e) => ScatterSpot(
                              e['sleep'] as double,
                              e['mood'] as double,
                            ))
                        .toList(),
                    minX: 4,
                    maxX: 10,
                    minY: 1,
                    maxY: 10,
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
