import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import 'chart_empty.dart';

/// 热量收支柱状图
///
/// 每天两根柱子：绿色是摄入，橙色是消耗。
/// 减脂要让绿柱低于橙柱，增肌反过来 —— 这张图就是看这个的。
class CalorieChart extends StatelessWidget {
  final int days;

  const CalorieChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final data = _collect(store);

    // 全是 0 说明既没记饮食也没训练
    final hasData = data.any((d) => d.intake > 0 || d.burned > 0);
    if (!hasData) {
      return const ChartEmpty(
        icon: Icons.local_fire_department_outlined,
        message: '还没有热量数据',
        hint: '记录饮食和训练后这里会显示收支对比',
      );
    }

    // 纵轴上限取最大值外扩 15%，让柱子顶部不贴边
    var maxVal = 0.0;
    for (final d in data) {
      if (d.intake > maxVal) maxVal = d.intake;
      if (d.burned > maxVal) maxVal = d.burned;
    }
    final maxY = maxVal * 1.15;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                    '${rod.toY.round()} 千卡',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      // 超过 1000 显示成 1.5k，省横向空间
                      final label = value >= 1000
                          ? '${(value / 1000).toStringAsFixed(1)}k'
                          : value.round().toString();
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
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

                      // 天数多了就隔几天显示一个标签
                      final step = data.length <= 7
                          ? 1
                          : (data.length / 5).ceil();
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
                final i = e.key;
                final d = e.value;

                return BarChartGroupData(
                  x: i,
                  // 两根柱子并排，宽度随天数缩小
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(
                      toY: d.intake,
                      color: Colors.green.shade400,
                      width: data.length > 14 ? 3 : 7,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                    BarChartRodData(
                      toY: d.burned,
                      color: Colors.deepOrange.shade300,
                      width: data.length > 14 ? 3 : 7,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(2),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend('摄入', Colors.green.shade400),
            const SizedBox(width: 18),
            _legend('消耗', Colors.deepOrange.shade300),
          ],
        ),
      ],
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// 按天汇总摄入和消耗
  List<_DayCalorie> _collect(UserStore store) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final result = <_DayCalorie>[];

    // 从最早的一天往今天推，这样图表从左到右是时间顺序
    for (var i = days - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));

      // 摄入：那天的饮食记录总热量
      var intake = 0.0;
      for (final m in store.mealsOn(day)) {
        intake += m.calories;
      }

      // 消耗：基础代谢 + 那天的训练消耗
      //
      // 只算训练消耗的话柱子会特别矮（练一次约 300 千卡，
      // 而吃进去 2000），对比没有意义。
      // 加上 BMR 才是真实的「今天烧掉多少」
      var burned = store.bmr.toDouble();
      for (final r in store.records) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        if (d == day) burned += r.calories;
      }

      // 完全没数据的那天不画基础代谢，避免误导
      // （用户那天可能根本没用这个 app）
      final hasAny = intake > 0 ||
          store.records.any((r) {
            final d = DateTime(r.date.year, r.date.month, r.date.day);
            return d == day;
          });

      result.add(_DayCalorie(
        date: day,
        intake: intake,
        burned: hasAny ? burned : 0,
      ));
    }

    return result;
  }
}

/// 一天的热量收支
class _DayCalorie {
  final DateTime date;

  /// 摄入（千卡）
  final double intake;

  /// 消耗（千卡）
  final double burned;

  const _DayCalorie({
    required this.date,
    required this.intake,
    required this.burned,
  });
}
