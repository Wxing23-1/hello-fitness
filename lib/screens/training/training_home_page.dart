import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/preset_plans.dart';
import '../../models/training_plan.dart';
import '../../services/user_store.dart';
import 'ai_generate_page.dart';
import 'plan_detail_page.dart';
import 'training_log_page.dart';

/// 训练中心主页
///
/// 顶部是 AI 定制入口，下面按有氧/无氧/混合筛选训练计划。
/// 计划分两部分：用户自己 AI 生成的 + 内置的预置计划。
class TrainingHomePage extends StatefulWidget {
  const TrainingHomePage({super.key});

  @override
  State<TrainingHomePage> createState() => _TrainingHomePageState();
}

class _TrainingHomePageState extends State<TrainingHomePage> {
  /// 当前筛选的类别，null 表示「全部」
  TrainingCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    // AI 生成的计划 + 预置计划
    final aiPlans = store.aiPlans;
    final presetPlans = PresetPlans.getAll();

    // 按类别筛选
    final filteredAi = _applyFilter(aiPlans);
    final filteredPreset = _applyFilter(presetPlans);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('训练计划'),
        actions: [
          // 训练打卡记录入口
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: '训练打卡',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrainingLogPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 本周进度 ──
          _buildWeekProgress(context, store),
          const SizedBox(height: 16),

          // ── AI 定制入口 ──
          _buildAiEntry(context, store),
          const SizedBox(height: 16),

          // ── 类别筛选 ──
          _buildCategoryFilter(),
          const SizedBox(height: 16),

          // ── AI 生成的计划 ──
          if (filteredAi.isNotEmpty) ...[
            _sectionTitle('我的 AI 计划', filteredAi.length),
            const SizedBox(height: 8),
            ...filteredAi.map((plan) => _PlanCard(
                  plan: plan,
                  // AI 计划可以删除，预置的不行
                  onDelete: () => _confirmDelete(context, store, plan),
                )),
            const SizedBox(height: 20),
          ],

          // ── 预置计划 ──
          _sectionTitle('推荐计划', filteredPreset.length),
          const SizedBox(height: 8),
          if (filteredPreset.isEmpty)
            _buildEmptyFilter()
          else
            ...filteredPreset.map((plan) => _PlanCard(plan: plan)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 按当前筛选条件过滤计划
  List<TrainingPlan> _applyFilter(List<TrainingPlan> plans) {
    if (_filter == null) return plans;
    return plans.where((p) => p.category == _filter).toList();
  }

  /// 本周训练进度
  ///
  /// 显示本周跟着计划练了几次，和目标对比。
  /// 点进去是打卡记录详情。
  Widget _buildWeekProgress(BuildContext context, UserStore store) {
    final done = store.thisWeekPlanWorkouts;
    final target = store.goal.weeklyWorkouts;

    // clamp 防止超额完成时进度条溢出
    final progress = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    final reached = done >= target;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrainingLogPage()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  reached ? Icons.verified : Icons.flag_outlined,
                  size: 18,
                  color: reached ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text(
                  '本周训练',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                reached
                    ? '本周目标已完成，继续保持'
                    : '还差 ${target - done} 次达成本周目标',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// AI 定制入口卡
  Widget _buildAiEntry(BuildContext context, UserStore store) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AiGeneratePage()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.indigo.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI 定制专属计划',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // 根据有没有登录显示不同文案
                    store.isSignedIn
                        ? '说说你的想法，AI 结合你的运动数据来安排'
                        : '需要先登录才能使用 AI 定制计划',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  /// 类别筛选条
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip(label: '全部', category: null),
          ...TrainingCategory.values.map(
            (c) => _filterChip(label: c.label, category: c),
          ),
        ],
      ),
    );
  }

  /// 单个筛选标签
  Widget _filterChip({required String label, required TrainingCategory? category}) {
    final selected = _filter == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = category),
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue.shade800,
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? Colors.blue.shade800 : Colors.black87,
        ),
      ),
    );
  }

  /// 小节标题
  Widget _sectionTitle(String text, int count) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// 筛选后没结果
  Widget _buildEmptyFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.filter_alt_off, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            '没有「${_filter!.label}」类型的推荐计划',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '可以用 AI 定制一份',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 删除 AI 计划的确认框
  void _confirmDelete(
    BuildContext context,
    UserStore store,
    TrainingPlan plan,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('确定删除「${plan.name}」吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              store.deleteAiPlan(plan.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 训练计划卡片
class _PlanCard extends StatelessWidget {
  final TrainingPlan plan;

  /// 删除回调，null 表示这个计划不能删（预置计划）
  final VoidCallback? onDelete;

  const _PlanCard({required this.plan, this.onDelete});

  /// 类别对应的颜色
  Color get _categoryColor {
    switch (plan.category) {
      case TrainingCategory.aerobic:
        return Colors.teal;
      case TrainingCategory.anaerobic:
        return Colors.deepPurple;
      case TrainingCategory.mixed:
        return Colors.orange;
    }
  }

  /// 类别对应的图标
  IconData get _categoryIcon {
    switch (plan.category) {
      case TrainingCategory.aerobic:
        return Icons.favorite;
      case TrainingCategory.anaerobic:
        return Icons.fitness_center;
      case TrainingCategory.mixed:
        return Icons.sync_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当前计划用蓝色描边突出，省得点进详情才知道选的是哪个
    final isActive = context.watch<UserStore>().activePlanId == plan.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: Colors.blue.shade400, width: 1.5)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlanDetailPage(plan: plan)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：类别标签 + 目标 + 难度
              Row(
                children: [
                  // 类别标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_categoryIcon, size: 13, color: _categoryColor),
                        const SizedBox(width: 4),
                        Text(
                          plan.category.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: _categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 目标标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      plan.goal.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    plan.level.label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  // AI 生成标记
                  if (plan.isAiGenerated)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 10, color: Colors.purple.shade700),
                          const SizedBox(width: 3),
                          Text(
                            'AI',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // 删除按钮（只有 AI 计划有）
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.grey.shade500,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 计划名称，当前计划额外带个标签
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin,
                            size: 11,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // 描述
              Text(
                plan.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),

              // 底部数据
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: '${plan.durationWeeks}周',
                  ),
                  const SizedBox(width: 12),
                  _InfoChip(
                    icon: Icons.repeat,
                    label: '每周${plan.workoutsPerWeek}次',
                  ),
                  const SizedBox(width: 12),
                  // 有氧无氧配比，混合类计划才显示
                  if (plan.category == TrainingCategory.mixed)
                    _InfoChip(
                      icon: Icons.pie_chart_outline,
                      label: '有氧${plan.aerobicDayCount}'
                          ' / 无氧${plan.anaerobicDayCount}',
                    )
                  else
                    _InfoChip(
                      icon: Icons.list_alt,
                      label: '${plan.totalDays}个训练日',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小信息标签
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
