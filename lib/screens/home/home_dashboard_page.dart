import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_plan.dart';
import '../../models/workout_log.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';
import '../../widgets/user_avatar.dart';
import 'ai_analysis_page.dart';
import '../training/ai_generate_page.dart';
import '../training/plan_detail_page.dart';
import '../training/start_session.dart';
import '../training/training_log_page.dart';

/// 首页数据看板
///
/// 打开 APP 第一眼看到的页面，回答三个问题：
///   我现在什么状态（BMI、离目标体重还差多少）
///   本周练得够不够（进度条 + 今日建议）
///   接下来干什么（快捷入口）
class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('今日概览'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _GreetingCard(store: store),
          const SizedBox(height: 14),
          _ActivePlanCard(store: store),
          const SizedBox(height: 14),
          _WeekProgressCard(store: store),
          const SizedBox(height: 14),
          _SuggestionCard(store: store),
          const SizedBox(height: 14),
          _AiAnalysisCard(store: store),
          const SizedBox(height: 14),
          _WeightGoalCard(store: store),
          const SizedBox(height: 14),
          _TotalStatsCard(store: store),
          const SizedBox(height: 14),
          _QuickActions(store: store),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
/// 顶部问候卡：按时段打招呼 + BMI 状态
class _GreetingCard extends StatelessWidget {
  final UserStore store;

  const _GreetingCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final profile = store.profile;
    final bmi = calculateBmi(profile.heightCm, profile.weightKg);
    final level = bmiLevelOf(bmi);

    // 名字可能没填，用「健身达人」兜底
    final name = profile.name.trim().isEmpty ? '健身达人' : profile.name.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // 头像（只读展示，上传入口在「我的」页）
          UserAvatar(avatarUrl: profile.avatarUrl, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()}，$name',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${profile.heightCm.toStringAsFixed(0)}cm · '
                  '${profile.weightKg.toStringAsFixed(1)}kg · '
                  '${profile.age}岁',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // BMI 圆环
          Container(
            width: 68,
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // 中文字形自带行距，不压 height 两行会顶出圆外
              children: [
                Text(
                  bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  bmi > 0 ? level.label : 'BMI',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 按当前时刻选问候语
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }
}

/// 当前计划卡
///
/// 没选计划时显示引导去挑一个；
/// 选了就显示计划名和「今天建议练哪一天」，点一下直接开始。
class _ActivePlanCard extends StatelessWidget {
  final UserStore store;

  const _ActivePlanCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final plan = store.activePlan;

    // 还没选计划 —— 给个引导入口，别让首页空着
    if (plan == null) {
      return _buildEmpty(context);
    }

    final day = _suggestDay(plan);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(Icons.push_pin, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                '我的计划',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              // 进详情页能换计划、看全部训练日
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlanDetailPage(plan: plan),
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                ),
                child: const Text('详情', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 计划名
          Text(
            plan.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            '${plan.days.length} 个训练日 · ${plan.goal.label}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          // 今天建议练哪一天
          if (day != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今天练',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.exercises.length} 个动作 · '
                        '${day.category.label} · '
                        '约 ${day.estimatedMinutes} 分钟',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  // 走共用入口，有草稿会先问要不要接着练
                  onPressed: () =>
                      startWorkout(context, plan: plan, day: day),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 没选计划时的引导卡
  Widget _buildEmpty(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 26,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          const Text(
            '还没有选定计划',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '去训练页挑一个，选用后就固定显示在这里',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  /// 推荐今天练哪一天
  ///
  /// 按「上次练的下一天」循环推进 —— 比永远推第一天有用。
  /// 用户想练别的，进详情页每天都能单独开始。
  TrainingDay? _suggestDay(TrainingPlan plan) {
    if (plan.days.isEmpty) return null;

    // 找这个计划最近一次练的是哪一天
    for (final log in store.workoutLogs) {
      if (log.planId != plan.id) continue;

      final lastIndex = plan.days.indexWhere((d) => d.id == log.dayId);
      if (lastIndex == -1) break;

      // 练到最后一天就绕回第一天
      return plan.days[(lastIndex + 1) % plan.days.length];
    }

    // 这个计划还没练过，从第一天开始
    return plan.days.first;
  }
}

/// 本周训练进度卡
class _WeekProgressCard extends StatelessWidget {
  final UserStore store;

  const _WeekProgressCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final done = store.thisWeekPlanWorkouts;
    final target = store.goal.weeklyWorkouts;
    // clamp 防止超额完成时进度条溢出
    final progress = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    final reached = target > 0 && done >= target;

    // 本周每天练没练，用来画七个圆点
    final weekDots = _buildWeekDots(store.workoutLogs);

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.verified : Icons.calendar_today_outlined,
                size: 17,
                color: reached ? Colors.green : Colors.blue,
              ),
              const SizedBox(width: 7),
              const Text(
                '本周训练',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$done / $target 次',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: reached ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 周一到周日七个点，练过的填实心
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDots,
          ),

          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                reached ? Colors.green : Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 生成周一到周日的打卡圆点
  List<Widget> _buildWeekDots(List<WorkoutLog> logs) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    // 本周一
    final monday = todayOnly.subtract(Duration(days: now.weekday - 1));

    // 本周练过的日期集合
    final trainedDays = logs
        .map((l) => DateTime(
              l.completedAt.year,
              l.completedAt.month,
              l.completedAt.day,
            ))
        .toSet();

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final trained = trainedDays.contains(day);
      final isToday = day == todayOnly;
      // 还没到的日期显示得更淡
      final isFuture = day.isAfter(todayOnly);

      return Column(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: trained
                  ? Colors.blue
                  : (isFuture ? Colors.grey.shade100 : Colors.grey.shade200),
              shape: BoxShape.circle,
              // 今天加个蓝圈标出来
              border: isToday
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: trained
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: isFuture
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
          ),
        ],
      );
    });
  }
}

/// 今日建议卡
///
/// 根据距上次训练多久、本周完成度，给一句可执行的建议。
/// 比干巴巴的数字更有推动力。
class _SuggestionCard extends StatelessWidget {
  final UserStore store;

  const _SuggestionCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, detail) = _suggest();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 决定今天给什么建议
  ///
  /// 优先级：今天练过 > 从没练过 > 休太久 > 本周达标 > 正常推进
  (IconData, Color, String, String) _suggest() {
    final logs = store.workoutLogs;
    final done = store.thisWeekPlanWorkouts;
    final target = store.goal.weeklyWorkouts;

    // 一次都没练过
    if (logs.isEmpty) {
      return (
        Icons.rocket_launch,
        Colors.indigo,
        '开始第一次训练',
        '去训练页挑一个计划，或者让 AI 按你的情况定制一份',
      );
    }

    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);
    final last = logs.first.completedAt;
    final lastDay = DateTime(last.year, last.month, last.day);
    final daysSince = todayOnly.difference(lastDay).inDays;

    // 今天已经练了
    if (daysSince == 0) {
      return (
        Icons.check_circle,
        Colors.green,
        '今天已完成训练',
        '记得补充蛋白质和水分，肌肉在休息时才会增长',
      );
    }

    // 超过 4 天没练
    if (daysSince >= 4) {
      return (
        Icons.self_improvement,
        Colors.deepOrange,
        '$daysSince 天没训练了',
        '间隔太久会掉状态，今天从轻量的开始，先动起来',
      );
    }

    // 本周已达标
    if (target > 0 && done >= target) {
      return (
        Icons.emoji_events,
        Colors.amber.shade800,
        '本周目标已达成',
        '完成 $done 次训练，想加练就选强度低一点的',
      );
    }

    // 昨天刚练过，建议今天练不同部位
    if (daysSince == 1) {
      return (
        Icons.sync_alt,
        Colors.teal,
        '今天适合换个部位',
        '昨天练过了，今天挑不同肌群，让昨天用到的肌肉恢复',
      );
    }

    // 正常推进
    final left = target - done;
    return (
      Icons.fitness_center,
      Colors.blue,
      '今天该训练了',
      left > 0 ? '本周还差 $left 次达成目标' : '保持节奏，坚持下去',
    );
  }
}

/// AI 今日分析入口卡
///
/// 把今天的训练+饮食+体重数据交给 AI 做复盘，是首页的「每日复盘」入口。
class _AiAnalysisCard extends StatelessWidget {
  final UserStore store;

  const _AiAnalysisCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 今日分析',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '复盘今天的训练和饮食，安排明天的计划',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiAnalysisPage()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo.shade600,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('去分析', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// 目标体重进度卡
class _WeightGoalCard extends StatelessWidget {
  final UserStore store;

  const _WeightGoalCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = store.profile.weightKg;
    final targetW = store.goal.targetWeightKg;
    final gap = store.weightGap;

    // 差距小于 0.5kg 就算到了
    final reached = gap < 0.5;
    final needLose = current > targetW;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                reached ? Icons.flag : Icons.monitor_weight_outlined,
                size: 17,
                color: reached ? Colors.green : Colors.deepPurple,
              ),
              const SizedBox(width: 7),
              const Text(
                '体重目标',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                store.goal.type.label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _col(current.toStringAsFixed(1), '当前', Colors.black87),
              Icon(
                needLose ? Icons.arrow_downward : Icons.arrow_forward,
                size: 18,
                color: Colors.grey.shade400,
              ),
              _col(
                targetW.toStringAsFixed(1),
                '目标',
                Colors.deepPurple,
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              _col(
                reached ? '达成' : gap.toStringAsFixed(1),
                reached ? '状态' : '还差(kg)',
                reached ? Colors.green : Colors.deepOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _col(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// 累计数据卡
class _TotalStatsCard extends StatelessWidget {
  final UserStore store;

  const _TotalStatsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                size: 17,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 7),
              const Text(
                '累计数据',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _item(
                Icons.fitness_center,
                '${store.totalWorkouts}',
                '总训练',
                Colors.blue,
              ),
              _item(
                Icons.timer_outlined,
                formatDuration(store.totalMinutes),
                '总时长',
                Colors.teal,
              ),
              _item(
                Icons.local_fire_department,
                '${store.totalCalories}',
                '千卡',
                Colors.deepOrange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// 快捷入口
class _QuickActions extends StatelessWidget {
  final UserStore store;

  const _QuickActions({required this.store});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _button(
            context,
            icon: Icons.auto_awesome,
            label: 'AI 定制计划',
            color: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiGeneratePage()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _button(
            context,
            icon: Icons.assignment_outlined,
            label: '训练打卡',
            color: Colors.indigo,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrainingLogPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _button(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一的白底卡片外壳
///
/// 几张卡的边框圆角内边距都一样，抽出来避免重复
Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );
}
