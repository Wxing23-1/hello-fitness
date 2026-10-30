import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import '../../utils/health_utils.dart';
import 'chart_empty.dart';

/// 训练量柱状图
///
/// 每天一根柱子，高度是训练时长。空白的那天就是没练，
/// 一眼看出训练规律和断档。
class WorkoutChart extends StatelessWidget {
  final int days;

  const WorkoutChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final data = _collect(store);

    final hasData = data.any((d) => d.minutes > 0);
    if (!hasData) {
      return const ChartEmpty(
        icon: Icons.fitness_center,
        message: '这段时间还没有训练记录',
        hint: '去训练页开始第一次训练',
      );
    }

    var maxMin = 0;
    var totalMin = 0;
    var trainedDays = 0;
    for (final d in data) {
      if (d.minutes > maxMin) maxMin = d.minutes;
      totalMin += d.minutes;
      if (d.minutes > 0) trainedDays++;
    }

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              maxY: maxMin * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    // 没练的那天不弹提示
                    if (rod.toY <= 0) return null;
                    return BarTooltipItem(
                      formatDuration(rod.toY.round()),
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.round().toString(),
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length) {
                        return const SizedBox.shrink();
                      }

                      final step =
                          data.length <= 7 ? 1 : (data.length / 5).ceil();
                      if (i % step != 0) return const SizedBox.shrink();

                      final d = data[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${d.month}/${d.day}',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.minutes.toDouble(),
                      color: Colors.blue.shade400,
                      width: data.length > 14 ? 5 : 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 期间小结
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('$trainedDays', '训练天数'),
            _stat(formatDuration(totalMin), '总时长'),
            _stat(
              trainedDays > 0
                  ? formatDuration((totalMin / trainedDays).round())
                  : '--',
              '平均每次',
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// 按天汇总训练时长
  ///
  /// 用 WorkoutRecord 而不是 WorkoutLog：前者包含手动添加的运动
  /// （跑步、游泳这些不在计划里的），统计训练量应该都算上
  List<_DayWorkout> _collect(UserStore store) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final result = <_DayWorkout>[];

    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));

      var minutes = 0;
      for (final r in store.records) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        if (d == day) minutes += r.durationMinutes;
      }

      result.add(_DayWorkout(date: day, minutes: minutes));
    }

    return result;
  }
}

/// 一天的训练量
class _DayWorkout {
  final DateTime date;

  /// 训练时长（分钟），0 表示没练
  final int minutes;

  const _DayWorkout({required this.date, required this.minutes});
}
