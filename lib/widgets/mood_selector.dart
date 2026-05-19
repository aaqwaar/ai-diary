import 'package:flutter/material.dart';

class MoodSelector extends StatelessWidget {
  final int selectedMood;
  final ValueChanged<int> onMoodSelected;

  const MoodSelector({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
  });

  static const moods = [
    {'emoji': '😢', 'label': 'Veľmi zle'},
    {'emoji': '😕', 'label': 'Zle'},
    {'emoji': '😐', 'label': 'Neutrálne'},
    {'emoji': '🙂', 'label': 'Dobre'},
    {'emoji': '😄', 'label': 'Skvelo'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Ako sa cítiš?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(5, (index) {
            final moodValue = index + 1;
            final isSelected = selectedMood == moodValue;
            return GestureDetector(
              onTap: () => onMoodSelected(moodValue),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepPurple.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.deepPurple : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  moods[index]['emoji']!,
                  style: TextStyle(fontSize: isSelected ? 36 : 28),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          moods[selectedMood - 1]['label']!,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}