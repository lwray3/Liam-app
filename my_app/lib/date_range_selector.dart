// File: date_range_selector.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelector extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;

  const DateRangeSelector({
    super.key,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
  });

  Future<void> _selectDate(BuildContext context, DateTime? initialDate,
      ValueChanged<DateTime?> onChanged) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () => _selectDate(context, from, onFromChanged),
          icon: const Icon(Icons.calendar_today),
          label:
              Text(from != null ? DateFormat('MMM dd').format(from!) : 'From'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text("to"),
        ),
        ElevatedButton.icon(
          onPressed: () => _selectDate(context, to, onToChanged),
          icon: const Icon(Icons.calendar_today),
          label: Text(to != null ? DateFormat('MMM dd').format(to!) : 'To'),
        ),
      ],
    );
  }
}
