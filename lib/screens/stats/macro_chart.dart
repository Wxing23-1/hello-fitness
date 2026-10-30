import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../services/user_store.dart';
import '../../utils/nutrition_utils.dart';
import 'chart_empty.dart';

/// 营养结构饼图
///
/// 显示期间内三大宏量素的热量占比，并和目标配比对照。
/// 按热量算占比而不是克数 —— 脂肪每克 9 千卡，
/// 按克数算会让人低估它的影响。
class MacroChart extends StatelessWidget {
  final int days;

  const MacroChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    final cutoff = DateTime.now().subtract(Duration(days: days));
    final meals =
        store.meals.where((m) => m.eatenAt.isAfter(cutoff)).toList();

    if (meals.isEmpty) {
      return const ChartEmpty(
        icon: Icons.pie_chart_outline,
        message: '还没有饮食记录',
        hint: '去饮食页记录后这里会显示营养结构',
      );
    }

    final summary = NutritionSummary.from(meals);
    final (p, c, f) = summary.macroPercents;

    // 目标配比，用来对照实际吃的偏不偏
    final t = store.macroTargets;
    final targetTotal = t.protein * 4 + t.carbs * 4 + t.fat * 9;
    final tp = targetTotal > 0 ? t.protein * 4 / targetTotal * 100 : 0.0;
    final tc = targetTotal > 0 ? t.carbs * 4 / targetTotal * 100 : 0.0;
    final tf = targetTotal > 0 ? t.fat * 9 / targetTotal * 100 : 0.0;

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            children: [
              // 饼图
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      _section(p, Colors.red.shade400),
                      _section(c, Colors.blue.shade400),
                      _section(f, Colors.amber.shade600),
                    ],
                  ),
                ),
              ),
              // 右侧对照表
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _row('蛋白质', p, tp, summary.protein,
                        Colors.red.shade400),
                    const SizedBox(height: 10),
                    _row('碳水', c, tc, summary.carbs, Colors.blue.shade400),
                    const SizedBox(height: 10),
                    _row('脂肪', f, tf, summary.fat, Colors.amber.shade600),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '括号内是你的目标配比',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  PieChartSectionData _section(double percent, Color color) {
    return PieChartSectionData(
      value: percent,
      color: color,
      // 占比太小时不显示文字，否则会糊成一团
      title: percent >= 8 ? '${percent.round()}%' : '',
      titleStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      radius: 32,
    );
  }

  /// 一行对照：实际占比 vs 目标占比 + 总克数
  Widget _row(
    String label,
    double actual,
    double target,
    double grams,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11),
              ),
              Text(
                '${actual.round()}% (${target.round()}%)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${formatMacro(grams)}g',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
