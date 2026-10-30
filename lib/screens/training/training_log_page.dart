import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/preset_plans.dart';
import '../../models/training_plan.dart';
import '../../models/workout_log.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';
import 'workout_log_detail_page.dart';

/// 训练打卡记录页
///
/// 列出按计划完成的训练，按日期分组。
/// 和个人中心的「训练历史记录」区别：
///   那个是 WorkoutRecord，手动添加的概要记录（跑了30分钟）
///   这个是 WorkoutLog，跟着计划练完自动生成的详细记录（每组做了几次）
class TrainingLogPage extends StatelessWidget {
  const TrainingLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final logs = store.workoutLogs;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('训练打卡'),
      ),
      body: logs.isEmpty
          ? _buildEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 顶部统计
                _buildStatsCard(store, logs),
                const SizedBox(height: 20),

                // 按日期分组的记录
                ..._buildGroupedList(context, store, logs),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  /// 空状态
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '还没有训练打卡记录',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            '去训练计划里选一个开始练吧',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 顶部统计卡
  Widget _buildStatsCard(UserStore store, List<WorkoutLog> logs) {
    // 总时长和总组数
    final totalMinutes = logs.fold(0, (s, l) => s + l.durationMinutes);
    final totalSets = logs.fold(
      0,
      (s, l) => s + l.exercises.fold(0, (a, e) => a + e.completedSets),
    );

    // 本周完成次数
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final thisWeek = logs.where((l) => l.completedAt.isAfter(monday)).length;

    // 连续打卡天数
    final streak = _calcStreak(logs);

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('${logs.length}', '总打卡'),
              _stat('$thisWeek', '本周'),
              _stat(formatDuration(totalMinutes), '总时长'),
              _stat('$totalSets', '总组数'),
            ],
          ),

          // 连续打卡提示，有连续记录才显示
          if (streak > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '连续打卡 $streak 天',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 统计数据块
  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  /// 算连续打卡天数
  ///
  /// 从今天（或最近一次打卡那天）往前推，连续有记录的天数。
  /// 同一天练两次算一天。
  int _calcStreak(List<WorkoutLog> logs) {
    if (logs.isEmpty) return 0;

    // 把打卡日期抹掉时刻，去重后降序
    final days = logs
        .map((l) => DateTime(
              l.completedAt.year,
              l.completedAt.month,
              l.completedAt.day,
            ))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // 最近一次打卡距今超过1天，连续就断了
    final gap = todayOnly.difference(days.first).inDays;
    if (gap > 1) return 0;

    // 从最近那天往前数连续的
    var streak = 1;
    for (var i = 0; i < days.length - 1; i++) {
      final diff = days[i].difference(days[i + 1]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// 按日期分组生成列表
  ///
  /// 分成「今天」「昨天」「本周」「更早」四组，
  /// 比一条条平铺更容易看出训练节奏
  List<Widget> _buildGroupedList(
    BuildContext context,
    UserStore store,
    List<WorkoutLog> logs,
  ) {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final monday = todayOnly.subtract(Duration(days: now.weekday - 1));

    // 四个分组
    final today = <WorkoutLog>[];
    final yesterday = <WorkoutLog>[];
    final thisWeek = <WorkoutLog>[];
    final earlier = <WorkoutLog>[];

    for (final log in logs) {
      final logDay = DateTime(
        log.completedAt.year,
        log.completedAt.month,
        log.completedAt.day,
      );
      final daysAgo = todayOnly.difference(logDay).inDays;

      if (daysAgo == 0) {
        today.add(log);
      } else if (daysAgo == 1) {
        yesterday.add(log);
      } else if (logDay.isAfter(monday) || logDay == monday) {
        thisWeek.add(log);
      } else {
        earlier.add(log);
      }
    }

    final widgets = <Widget>[];

    // 每个非空分组生成「标题 + 卡片列表」
    void addGroup(String title, List<WorkoutLog> items) {
      if (items.isEmpty) return;

      widgets.add(_groupTitle(title, items.length));
      widgets.add(const SizedBox(height: 8));
      widgets.addAll(
        items.map((log) => _LogCard(
              log: log,
              store: store,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutLogDetailPage(log: log),
                ),
              ),
              onDelete: () => _confirmDelete(context, store, log),
            )),
      );
      widgets.add(const SizedBox(height: 16));
    }

    addGroup('今天', today);
    addGroup('昨天', yesterday);
    addGroup('本周', thisWeek);
    addGroup('更早', earlier);

    return widgets;
  }

  /// 分组标题
  Widget _groupTitle(String text, int count) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// 删除确认
  void _confirmDelete(
    BuildContext context,
    UserStore store,
    WorkoutLog log,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除打卡记录'),
        content: const Text('确定删除这条训练记录吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              store.deleteWorkoutLog(log.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('记录已删除'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 单条打卡记录卡片
class _LogCard extends StatelessWidget {
  final WorkoutLog log;
  final UserStore store;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LogCard({
    required this.log,
    required this.store,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 查这条记录对应的计划和训练日
    final plan = _findPlan();
    final day = _findDay(plan);

    final category = day?.category ?? TrainingCategory.mixed;
    final totalSets = log.exercises.fold(0, (s, e) => s + e.completedSets);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 左侧类别图标
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _categoryColor(category).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: _categoryColor(category),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // 中间信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 训练日名称
                    Text(
                      day?.name ?? '训练记录',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 时长 · 组数 · 动作数
                    Text(
                      '${formatDuration(log.durationMinutes)} · '
                      '$totalSets组 · '
                      '${log.exercises.length}个动作',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // 完成时刻
                        Icon(
                          Icons.access_time,
                          size: 11,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatTime(log.completedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),

                        // 星级评分
                        if (log.feeling != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.star,
                            size: 11,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${log.feeling}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],

                        // 所属计划
                        if (plan != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 右侧删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.grey.shade400,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 查找所属计划
  TrainingPlan? _findPlan() {
    final preset = PresetPlans.getById(log.planId);
    if (preset != null) return preset;

    for (final p in store.aiPlans) {
      if (p.id == log.planId) return p;
    }
    return null;
  }

  /// 查找训练日
  TrainingDay? _findDay(TrainingPlan? plan) {
    if (plan == null) return null;

    for (final d in plan.days) {
      if (d.id == log.dayId) return d;
    }
    return null;
  }

  /// 类别颜色
  Color _categoryColor(TrainingCategory c) {
    switch (c) {
      case TrainingCategory.aerobic:
        return Colors.teal;
      case TrainingCategory.anaerobic:
        return Colors.deepPurple;
      case TrainingCategory.mixed:
        return Colors.orange;
    }
  }

  /// 类别图标
  IconData _categoryIcon(TrainingCategory c) {
    switch (c) {
      case TrainingCategory.aerobic:
        return Icons.favorite;
      case TrainingCategory.anaerobic:
        return Icons.fitness_center;
      case TrainingCategory.mixed:
        return Icons.sync_alt;
    }
  }

  /// 格式化时刻：19:30
  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
