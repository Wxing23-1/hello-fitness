import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import 'calorie_chart.dart';
import 'macro_chart.dart';
import 'weight_chart.dart';
import 'weight_log_page.dart';
import 'workout_chart.dart';

/// 数据统计首页
///
/// 四块图表：体重趋势、热量收支、营养结构、训练量。
/// 顶部可切时间范围 —— 7 天看细节，30 天看趋势。
class StatsHomePage extends StatefulWidget {
  const StatsHomePage({super.key});

  @override
  State<StatsHomePage> createState() => _StatsHomePageState();
}

class _StatsHomePageState extends State<StatsHomePage> {
  /// 当前时间范围（天）
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('数据统计'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WeightLogPage()),
            ),
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: '记录体重',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRangeSelector(),
          const SizedBox(height: 16),

          _buildOverview(store),
          const SizedBox(height: 18),

          _ChartCard(
            title: '体重趋势',
            icon: Icons.show_chart,
            color: Colors.deepPurple,
            // 没记录时提示去记，而不是显示一张空图
            action: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeightLogPage()),
              ),
              child: const Text('记录', style: TextStyle(fontSize: 12)),
            ),
            child: WeightChart(days: _days),
          ),
          const SizedBox(height: 14),

          _ChartCard(
            title: '热量收支',
            icon: Icons.local_fire_department,
            color: Colors.deepOrange,
            subtitle: '摄入 vs 消耗（训练消耗 + 基础代谢）',
            child: CalorieChart(days: _days),
          ),
          const SizedBox(height: 14),

          _ChartCard(
            title: '营养结构',
            icon: Icons.pie_chart,
            color: Colors.green,
            subtitle: '三大宏量素的热量占比',
            child: MacroChart(days: _days),
          ),
          const SizedBox(height: 14),

          _ChartCard(
            title: '训练量',
            icon: Icons.fitness_center,
            color: Colors.blue,
            subtitle: '每天的训练时长',
            child: WorkoutChart(days: _days),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 时间范围切换
  Widget _buildRangeSelector() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7天')),
        ButtonSegment(value: 14, label: Text('14天')),
        ButtonSegment(value: 30, label: Text('30天')),
      ],
      selected: {_days},
      onSelectionChanged: (s) => setState(() => _days = s.first),
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }

  /// 顶部关键数字
  Widget _buildOverview(UserStore store) {
    final logs = store.recentWeightLogs(_days);
    final meals = store.meals;

    // 体重变化：最新减最早
    String weightChange = '--';
    Color changeColor = Colors.grey;
    if (logs.length >= 2) {
      final diff = logs.last.weightKg - logs.first.weightKg;
      final sign = diff > 0 ? '+' : '';
      weightChange = '$sign${diff.toStringAsFixed(1)}';
      // 看目标方向判断好坏：减脂时掉秤是好事
      changeColor = diff.abs() < 0.2
          ? Colors.grey
          : (diff < 0 ? Colors.green : Colors.deepOrange);
    }

    // 期间日均摄入
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final recent = meals.where((m) => m.eatenAt.isAfter(cutoff)).toList();

    final dayKeys = recent
        .map((m) => '${m.eatenAt.year}-${m.eatenAt.month}-${m.eatenAt.day}')
        .toSet();

    var totalKcal = 0.0;
    for (final m in recent) {
      totalKcal += m.calories;
    }
    final avgKcal =
        dayKeys.isEmpty ? 0 : (totalKcal / dayKeys.length).round();

    // 期间训练次数
    final workouts = store.workoutLogs
        .where((l) => l.completedAt.isAfter(cutoff))
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade400, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(weightChange, '体重变化(kg)', highlight: changeColor),
          _stat('$avgKcal', '日均摄入'),
          _stat('$workouts', '训练次数'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, {Color? highlight}) {
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
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    );
  }
}

/// 图表卡片外壳
///
/// 四张图的标题栏样式一样，抽出来省重复
class _ChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Widget? action;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
