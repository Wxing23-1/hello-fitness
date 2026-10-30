import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import 'chart_empty.dart';

/// 体重趋势折线图
///
/// 横轴是日期，纵轴是体重。虚线标出目标体重，一眼看出还差多少。
class WeightChart extends StatelessWidget {
  /// 显示最近多少天
  final int days;

  const WeightChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final logs = store.recentWeightLogs(days);

    // 一个点画不出趋势，至少要两条记录
    if (logs.length < 2) {
      return ChartEmpty(
        icon: Icons.monitor_weight_outlined,
        message: logs.isEmpty ? '还没有体重记录' : '再记一次就能看到趋势了',
        hint: '点右上角的秤图标记录体重',
      );
    }

    final target = store.goal.targetWeightKg;

    // 纵轴范围：数据最小最大值外扩一点，不要贴边
    var minW = logs.first.weightKg;
    var maxW = logs.first.weightKg;
    for (final l in logs) {
      if (l.weightKg < minW) minW = l.weightKg;
      if (l.weightKg > maxW) maxW = l.weightKg;
    }
    // 目标线也要在可见范围内
    if (target > 0) {
      if (target < minW) minW = target;
      if (target > maxW) maxW = target;
    }

    final pad = ((maxW - minW) * 0.2).clamp(0.5, 5.0);
    final minY = minW - pad;
    final maxY = maxW + pad;

    // 第一条记录作为 x 轴原点，后面的点按相差天数定位
    final baseDate = DateTime(
      logs.first.date.year,
      logs.first.date.month,
      logs.first.date.day,
    );

    final spots = logs.map((l) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      return FlSpot(
        d.difference(baseDate).inDays.toDouble(),
        l.weightKg,
      );
    }).toList();

    final maxX = spots.last.x;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          // 只有一天跨度时给个最小宽度，否则所有点挤在左边
          maxX: maxX < 1 ? 1 : maxX,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} kg',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ))
                  .toList(),
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
                reservedSize: 34,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // 点多了标签会重叠，按跨度调间隔
                interval: maxX <= 7 ? 1 : (maxX / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final d = baseDate.add(Duration(days: value.toInt()));
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
          // 目标体重虚线
          extraLinesData: target > 0
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target,
                      color: Colors.green.shade400,
                      strokeWidth: 1.5,
                      dashArray: [5, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (_) => '目标 ${target.toStringAsFixed(0)}',
                      ),
                    ),
                  ],
                )
              : null,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              // 曲率别太大，否则两点之间会鼓出去，看着像数据有波动
              curveSmoothness: 0.2,
              color: Colors.deepPurple.shade400,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Colors.deepPurple.shade400,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.deepPurple.shade400.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
