import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/entry_model.dart';
import '../services/firestore_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _firestoreService = FirestoreService();

  Color _getMoodColor(double mood) {
    if (mood >= 4.5) return Colors.green;
    if (mood >= 3.5) return Colors.lightGreen;
    if (mood >= 2.5) return Colors.orange;
    return Colors.red;
  }

  List<_ChartPoint> _buildChartData(List<Entry> entries) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recent = entries.where((e) => e.date.isAfter(cutoff)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (recent.isEmpty) return [];

    final byDay = <String, List<int>>{};
    for (final entry in recent) {
      final key = DateFormat('dd.MM').format(entry.date);
      byDay.putIfAbsent(key, () => []).add(entry.mood);
    }

    return byDay.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return _ChartPoint(label: e.key, mood: avg);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Entry>>(
      stream: _firestoreService.entriesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('Zatiaľ žiadne zápisky',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Pridaj zápisky a uvidíš štatistiky',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        final totalEntries = entries.length;
        final avgMood = entries.map((e) => e.mood).reduce((a, b) => a + b) /
            totalEntries;
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final weekEntries =
            entries.where((e) => e.date.isAfter(weekAgo)).toList();
        final chartData = _buildChartData(entries);

        final allTags = entries.expand((e) => e.tags).toList();
        final tagCounts = <String, int>{};
        for (final tag in allTags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
        final sortedTags = tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topTags = sortedTags.take(5).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary karty
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.book,
                      label: 'Celkom zápiskov',
                      value: totalEntries.toString(),
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.sentiment_satisfied_alt,
                      label: 'Priem. nálada',
                      value: '${avgMood.toStringAsFixed(1)}/5',
                      color: _getMoodColor(avgMood),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_today,
                      label: 'Tento týždeň',
                      value: '${weekEntries.length} zápiskov',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_emotions,
                      label: 'Najlepšia nálada',
                      value:
                          '${entries.map((e) => e.mood).reduce((a, b) => a > b ? a : b)}/5',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Graf nálady
              if (chartData.isNotEmpty) ...[
                const Text('Nálada za posledných 14 dní',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                reservedSize: 36,
                                getTitlesWidget: (value, meta) {
                                  const emojis = {
                                    1: '😢',
                                    2: '😕',
                                    3: '😐',
                                    4: '🙂',
                                    5: '😄'
                                  };
                                  return Text(
                                    emojis[value.toInt()] ?? '',
                                    style: const TextStyle(fontSize: 14),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 ||
                                      index >= chartData.length ||
                                      index % 2 != 0) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      chartData[index].label,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: (chartData.length - 1).toDouble(),
                          minY: 1,
                          maxY: 5,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData.asMap().entries
                                  .map((e) => FlSpot(
                                      e.key.toDouble(), e.value.mood))
                                  .toList(),
                              isCurved: true,
                              color: Colors.deepPurple,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) =>
                                    FlDotCirclePainter(
                                  radius: 5,
                                  color: Colors.deepPurple,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.deepPurple.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Najčastejšie témy (tagy)
              if (topTags.isNotEmpty) ...[
                const Text('Najčastejšie témy',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: topTags.map((entry) {
                        final maxCount = sortedTags.first.value;
                        final percentage = entry.value / maxCount;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.grey.shade200,
                                    color: Colors.deepPurple,
                                    minHeight: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${entry.value}×',
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChartPoint {
  final String label;
  final double mood;
  _ChartPoint({required this.label, required this.mood});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}