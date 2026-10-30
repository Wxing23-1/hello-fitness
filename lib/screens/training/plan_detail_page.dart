import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_plan.dart';
import '../../services/user_store.dart';
import 'day_edit_page.dart';
import 'exercise_guide_sheet.dart';
import 'start_session.dart';

/// 训练计划详情页
///
/// 展示计划的全部训练日和动作列表，可以把计划设为「当前计划」，
/// 设置后会出现在首页，不用每次都来列表里翻。
class PlanDetailPage extends StatefulWidget {
  final TrainingPlan plan;

  const PlanDetailPage({super.key, required this.plan});

  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  /// 当前展示的计划
  ///
  /// 编辑训练日后 store 里会存一份新计划（预置计划还会换 id），
  /// 这里跟着更新，省得用户退出再进才看到改动。
  late TrainingPlan plan = widget.plan;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final isActive = store.activePlanId == plan.id;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(plan.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 计划概览卡
          _buildOverviewCard(),
          const SizedBox(height: 12),

          // 选用／取消选用
          _buildActiveToggle(context, store, isActive),
          const SizedBox(height: 16),

          // 训练日列表
          //
          // 每个训练日都能单独开始 —— 用户可能今天想练腿、明天想练背，
          // 不一定非得按顺序走
          ...plan.days.map((day) => _DayCard(
                day: day,
                onStart: () => _startSession(context, day),
                onEdit: () => _editDay(day),
              )),

          const SizedBox(height: 80), // 给底部按钮留空间
        ],
      ),
      // 底部按钮：快速开始第一天
      floatingActionButton: plan.days.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _startSession(context, plan.days.first),
              icon: const Icon(Icons.play_arrow),
              label: Text('开始${plan.days.first.name}'),
            ),
    );
  }

  /// 选用／取消选用这个计划
  ///
  /// 选用后计划会显示在首页，并提示今天该练哪一天
  Widget _buildActiveToggle(
    BuildContext context,
    UserStore store,
    bool isActive,
  ) {
    if (isActive) {
      // 已经是当前计划，显示状态条和取消入口
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '这是你当前的计划，已显示在首页',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                store.setActivePlan(null);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已取消当前计划'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('取消', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }

    // 还没选用，显示选用按钮
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          // 换计划时直接覆盖旧的 —— 同时跟两份计划容易乱，
          // 想换回来再点一次就行
          final previous = store.activePlan;
          store.setActivePlan(plan.id);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                previous == null
                    ? '已设为当前计划，首页可以直接看到'
                    : '已从「${previous.name}」切换到这个计划',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: const Icon(Icons.push_pin_outlined, size: 18),
        label: const Text('选用这个计划'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// 跳转到训练执行页
  void _startSession(BuildContext context, TrainingDay day) {
    // 没有动作的训练日没法练，给个提示而不是让用户进去看空页面
    if (day.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('这个训练日还没有动作'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 走共用入口，有未完成的草稿会先问要不要接着练
    startWorkout(context, plan: plan, day: day);
  }

  /// 打开训练日编辑页
  ///
  /// 编辑页返回保存后的计划（预置计划会是一份新 id 的副本），
  /// 拿到就替换当前页的 plan，界面立刻反映改动
  void _editDay(TrainingDay day) async {
    final saved = await Navigator.push<TrainingPlan>(
      context,
      MaterialPageRoute(
        builder: (_) => DayEditPage(plan: plan, day: day),
      ),
    );

    // 用户取消编辑时返回 null
    if (saved == null || !mounted) return;

    setState(() => plan = saved);
  }

  /// 计划概览卡
  Widget _buildOverviewCard() {
    // 根据训练类别返回渐变色，和列表页的配色保持一致
    List<Color> gradientColors;
    switch (plan.category) {
      case TrainingCategory.aerobic:
        gradientColors = [Colors.teal.shade400, Colors.teal.shade300];
        break;
      case TrainingCategory.anaerobic:
        gradientColors = [
          Colors.deepPurple.shade400,
          Colors.deepPurple.shade300,
        ];
        break;
      case TrainingCategory.mixed:
        gradientColors = [Colors.orange.shade400, Colors.deepOrange.shade300];
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 类别标签（有氧/无氧/混合）
              _whiteTag(plan.category.label),
              const SizedBox(width: 6),
              _whiteTag(plan.goal.label),
              const SizedBox(width: 6),
              _whiteTag(plan.level.label),
              const Spacer(),
              // AI 生成标记
              if (plan.isAiGenerated)
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'AI 定制',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 类别说明，帮用户理解有氧无氧的区别
          Text(
            plan.category.description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            plan.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _OverviewItem(
                icon: Icons.calendar_today,
                label: '${plan.durationWeeks}周',
              ),
              const SizedBox(width: 16),
              _OverviewItem(
                icon: Icons.repeat,
                label: '每周${plan.workoutsPerWeek}练',
              ),
              const SizedBox(width: 16),
              _OverviewItem(
                icon: Icons.list_alt,
                label: '${plan.totalDays}天',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 半透明白底的小标签
  Widget _whiteTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 概览项
class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverviewItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
      ],
    );
  }
}

/// 训练日卡片
class _DayCard extends StatelessWidget {
  final TrainingDay day;

  /// 点「开始训练」的回调
  final VoidCallback onStart;

  /// 点「编辑」的回调
  final VoidCallback onEdit;

  const _DayCard({
    required this.day,
    required this.onStart,
    required this.onEdit,
  });

  /// 这一天的类别颜色
  Color get _dayCategoryColor {
    switch (day.category) {
      case TrainingCategory.aerobic:
        return Colors.teal;
      case TrainingCategory.anaerobic:
        return Colors.deepPurple;
      case TrainingCategory.mixed:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            // 天数标签
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${day.dayNumber}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 训练日名称 + 类别
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // 这一天属于有氧还是无氧
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _dayCategoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      day.category.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: _dayCategoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 预计时长
            Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '${day.estimatedMinutes}分钟',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        children: [
          const Divider(height: 16),
          // 动作列表
          ...day.exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            return _ExerciseItem(
              exercise: exercise,
              number: index + 1,
            );
          }),

          // 这一天的开始按钮
          //
          // 放在展开内容的底部：用户看完动作列表觉得合适，
          // 顺手就能开始，不用再滑回去找按钮
          const SizedBox(height: 4),
          Row(
            children: [
              // 编辑：改组数次数重量、删动作、调顺序
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('编辑'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text('开始${day.name}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 动作项
class _ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final int number;

  const _ExerciseItem({required this.exercise, required this.number});

  /// 动作类别对应的颜色
  Color get _exerciseCategoryColor {
    switch (exercise.category) {
      case TrainingCategory.aerobic:
        return Colors.teal;
      case TrainingCategory.anaerobic:
        return Colors.deepPurple;
      case TrainingCategory.mixed:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      // 点整行弹详解。做成可点的而不是加个按钮：
      // 列表里动作多，每行再加图标太挤
      onTap: () => showExerciseGuide(context, exercise),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序号
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 动作详情
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 动作名称 + 类别小圆点
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // 用小圆点标出这个动作是有氧还是无氧
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _exerciseCategoryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      exercise.category.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: _exerciseCategoryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 组数次数（targetText 会自动处理「次」还是「秒」）
                // 有建议重量就一起显示，无氧动作主要看这个
                Text(
                  [
                    exercise.targetText,
                    if (exercise.weightText != null) exercise.weightText!,
                    if (exercise.restSeconds > 0)
                      '组间休息 ${exercise.restSeconds}秒',
                  ].join('  |  '),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                // 目标肌群和器械
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 2),
                    Text(
                      exercise.muscleGroup,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (exercise.equipment != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.fitness_center,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text(
                        exercise.equipment!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                // 动作要点
                if (exercise.tips != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb,
                            size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.tips!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade900,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 有分解步骤或常见错误时，提示可以点开看
                if (exercise.hasGuide) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 13,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '点击查看动作详解',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
