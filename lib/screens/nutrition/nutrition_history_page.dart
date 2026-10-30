import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../services/user_store.dart';

/// 饮食历史
///
/// 按天汇总列出过去的摄入，看出饮食规律和达标情况。
/// 想看某天吃了什么，回饮食首页用日期切换条翻过去。
class NutritionHistoryPage extends StatelessWidget {
  const NutritionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final days = _groupByDay(store.meals);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('饮食历史'),
      ),
      body: days.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildOverview(store, days),
                const SizedBox(height: 18),
                ...days.map((d) => _DayCard(day: d, store: store)),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  /// 按天分组，最近的在前
  List<_DayGroup> _groupByDay(List<MealEntry> meals) {
    final map = <DateTime, List<MealEntry>>{};

    for (final m in meals) {
      final day = DateTime(m.eatenAt.year, m.eatenAt.month, m.eatenAt.day);
      map.putIfAbsent(day, () => []).add(m);
    }

    final groups = map.entries
        .map((e) => _DayGroup(date: e.key, entries: e.value))
        .toList();

    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '还没有饮食记录',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            '回饮食页记录第一餐吧',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 顶部总览
  Widget _buildOverview(UserStore store, List<_DayGroup> days) {
    final target = store.dailyCalorieTarget;

    // 平均每日摄入
    var total = 0.0;
    for (final d in days) {
      total += NutritionSummary.from(d.entries).calories;
    }
    final avg = days.isEmpty ? 0 : (total / days.length).round();

    // 达标天数：在目标的 ±10% 以内算达标
    var onTarget = 0;
    for (final d in days) {
      final kcal = NutritionSummary.from(d.entries).calories;
      if (target > 0 && (kcal - target).abs() <= target * 0.1) onTarget++;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade400, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('${days.length}', '记录天数'),
          _stat('$avg', '日均千卡'),
          _stat('$onTarget', '达标天数'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    );
  }
}

/// 一天的记录分组
class _DayGroup {
  final DateTime date;
  final List<MealEntry> entries;

  const _DayGroup({required this.date, required this.entries});
}

/// 一天的汇总卡
class _DayCard extends StatelessWidget {
  final _DayGroup day;
  final UserStore store;

  const _DayCard({required this.day, required this.store});

  @override
  Widget build(BuildContext context) {
    final summary = NutritionSummary.from(day.entries);
    final target = store.dailyCalorieTarget;
    final kcal = summary.calories.round();

    // 超目标 10% 以上标橙色，差 10% 以上标蓝色，否则绿色
    final Color color;
    if (target <= 0) {
      color = Colors.grey;
    } else if (kcal > target * 1.1) {
      color = Colors.deepOrange;
    } else if (kcal < target * 0.9) {
      color = Colors.blue;
    } else {
      color = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _label(day.date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${day.entries.length} 条记录',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const Spacer(),
              Text(
                '$kcal',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                target > 0 ? ' / $target' : '',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 宏量素占比条
          _buildMacroBar(summary),

          const SizedBox(height: 8),
          Row(
            children: [
              _legend('蛋白', summary.protein, Colors.red.shade400),
              const SizedBox(width: 12),
              _legend('碳水', summary.carbs, Colors.blue.shade400),
              const SizedBox(width: 12),
              _legend('脂肪', summary.fat, Colors.amber.shade600),
            ],
          ),
        ],
      ),
    );
  }

  /// 三色占比条
  ///
  /// 按热量占比分段，一眼看出这天的营养结构
  Widget _buildMacroBar(NutritionSummary s) {
    final (p, c, f) = s.macroPercents;

    // 没有数据时显示灰条，不要除零
    if (p + c + f <= 0) {
      return Container(
        height: 7,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          // flex 要整数，百分比乘 10 保留一位精度
          Expanded(
            flex: (p * 10).round().clamp(1, 1000),
            child: Container(height: 7, color: Colors.red.shade400),
          ),
          Expanded(
            flex: (c * 10).round().clamp(1, 1000),
            child: Container(height: 7, color: Colors.blue.shade400),
          ),
          Expanded(
            flex: (f * 10).round().clamp(1, 1000),
            child: Container(height: 7, color: Colors.amber.shade600),
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, double grams, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ${grams.round()}g',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// 日期标签：今天 / 昨天 / 10月28日
  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${d.month}月${d.day}日';
  }
}
