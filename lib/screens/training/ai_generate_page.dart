import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/training_plan.dart';
import '../../services/ai_plan_service.dart';
import '../../services/user_store.dart';
import 'plan_detail_page.dart';

/// AI 生成训练计划页
///
/// 用户填写想法和偏好，连同他的真实资料与近期运动量一起发给 DeepSeek，
/// 生成个性化计划。
class AiGeneratePage extends StatefulWidget {
  const AiGeneratePage({super.key});

  @override
  State<AiGeneratePage> createState() => _AiGeneratePageState();
}

class _AiGeneratePageState extends State<AiGeneratePage> {
  /// 用户自由描述的想法
  final _thoughtsController = TextEditingController();

  /// 可用器械描述
  final _equipmentController = TextEditingController(text: '哑铃、瑜伽垫');

  /// 期望每周训练次数
  int _weeklyWorkouts = 3;

  /// 偏好的训练类别，null 表示让 AI 自己决定
  TrainingCategory? _preferredCategory;

  /// 是否正在生成中
  bool _loading = false;

  /// 生成失败的错误信息
  String? _error;

  @override
  void initState() {
    super.initState();

    // 用用户在目标设置里填的每周次数作为默认值
    _weeklyWorkouts = context.read<UserStore>().goal.weeklyWorkouts;
  }

  @override
  void dispose() {
    _thoughtsController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  /// 调用 AI 生成计划
  Future<void> _generate() async {
    final store = context.read<UserStore>();

    // 没填 key 直接提示，别浪费一次请求
    if (!store.hasApiKey) {
      setState(() {
        _error = '还没配置 DeepSeek API Key，请到「我的 → 系统设置 → AI 配置」填写';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AiPlanService.generate(
      apiKey: store.aiApiKey,
      profile: store.profile,
      goal: store.goal,
      // 把真实训练记录传进去，这是「根据当前运动量定强度」的关键
      recentRecords: store.records,
      userThoughts: _thoughtsController.text,
      weeklyWorkouts: _weeklyWorkouts,
      preferredCategory: _preferredCategory,
      equipment: _equipmentController.text.trim().isEmpty
          ? '无器械，只能做徒手训练'
          : _equipmentController.text.trim(),
    );

    // await 期间用户可能已经返回上一页了，这时不能再碰 setState
    if (!mounted) return;

    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.error);
      return;
    }

    // 生成成功，存起来并跳到详情页
    final plan = result.plan!;
    store.addAiPlan(plan);

    if (!mounted) return;

    // 用 pushReplacement：生成页没必要留在返回栈里，
    // 用户从详情页返回应该直接回到计划列表
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PlanDetailPage(plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final stats = _recentStats(store);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AI 定制计划'),
      ),
      body: AbsorbPointer(
        // 生成中禁止交互，避免重复提交
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── AI 会参考的数据 ──
            _buildDataCard(store, stats),
            const SizedBox(height: 20),

            // ── 想法输入 ──
            const Text(
              '你的想法',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '说说你的情况和诉求，越具体 AI 给的计划越贴合',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _thoughtsController,
              maxLines: 5,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: '比如：\n'
                    '想练出腹肌，但晚上只有半小时\n'
                    '膝盖以前受过伤，不能做深蹲和跳跃\n'
                    '只有一对哑铃，在家练\n'
                    '上班久坐腰不舒服，想改善体态',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // ── 每周训练次数 ──
            const Text(
              '每周训练次数',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _weeklyWorkouts.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$_weeklyWorkouts次',
                    onChanged: (v) =>
                        setState(() => _weeklyWorkouts = v.round()),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_weeklyWorkouts 次',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            // 如果用户设的次数明显超过他的实际运动量，提前提醒
            if (stats.weeklyAvg > 0 && _weeklyWorkouts > stats.weeklyAvg * 2)
              _buildWarning(
                '你最近平均每周练 ${stats.weeklyAvg.toStringAsFixed(1)} 次，'
                '一下提到 $_weeklyWorkouts 次跨度较大。AI 会帮你安排渐进过渡。',
              ),
            const SizedBox(height: 16),

            // ── 训练偏好 ──
            const Text(
              '训练偏好',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 16),

            // ── 可用器械 ──
            const Text(
              '可用器械',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _equipmentController,
              decoration: const InputDecoration(
                hintText: '比如：健身房全套 / 哑铃+弹力带 / 什么都没有',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 20),

            // ── 错误提示 ──
            if (_error != null) _buildError(),

            // ── 生成按钮 ──
            FilledButton.icon(
              onPressed: _loading ? null : _generate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading ? 'AI 正在制定计划...' : '生成我的专属计划',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),

            // 没配 key 时给个入口提示
            if (!store.hasApiKey)
              Center(
                child: Text(
                  '需要先在「我的 → 系统设置 → AI 配置」填写 DeepSeek API Key',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// AI 会参考的数据概览
  ///
  /// 让用户知道 AI 不是凭空瞎编，而是看了他的真实数据
  Widget _buildDataCard(UserStore store, _RecentStats stats) {
    final profile = store.profile;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'AI 会参考这些数据',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '· ${profile.gender.label} · ${profile.age}岁 · '
            '${profile.heightCm.toStringAsFixed(0)}cm · '
            '${profile.weightKg.toStringAsFixed(1)}kg\n'
            '· 目标：${store.goal.type.label}，'
            '目标体重 ${store.goal.targetWeightKg.toStringAsFixed(0)}kg\n'
            '· 最近30天：${stats.text}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 训练类别选择器
  Widget _buildCategorySelector() {
    // 四个选项：三种类别 + 让 AI 决定
    final options = <(TrainingCategory?, String, String, IconData)>[
      (null, '让 AI 决定', '根据我的目标自动搭配', Icons.auto_awesome),
      (
        TrainingCategory.aerobic,
        '有氧为主',
        TrainingCategory.aerobic.benefit,
        Icons.favorite,
      ),
      (
        TrainingCategory.anaerobic,
        '无氧为主',
        TrainingCategory.anaerobic.benefit,
        Icons.fitness_center,
      ),
      (
        TrainingCategory.mixed,
        '有氧无氧结合',
        TrainingCategory.mixed.benefit,
        Icons.sync_alt,
      ),
    ];

    return Column(
      children: options.map((opt) {
        final (category, label, benefit, icon) = opt;
        final selected = _preferredCategory == category;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _preferredCategory = category),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                color: selected ? Colors.blue.shade50 : null,
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? Colors.blue : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          benefit,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: selected ? Colors.blue : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 黄色提醒条
  Widget _buildWarning(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 红色错误提示
  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 统计最近 30 天的训练情况
  _RecentStats _recentStats(UserStore store) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = store.records.where((r) => r.date.isAfter(cutoff)).toList();

    if (recent.isEmpty) {
      return const _RecentStats(
        count: 0,
        weeklyAvg: 0,
        text: '没有训练记录（AI 会从低强度起步）',
      );
    }

    final minutes = recent.fold(0, (s, r) => s + r.durationMinutes);
    // 30 天约等于 4.3 周
    final weeklyAvg = recent.length / 4.3;

    return _RecentStats(
      count: recent.length,
      weeklyAvg: weeklyAvg,
      text: '训练 ${recent.length} 次，'
          '平均每周 ${weeklyAvg.toStringAsFixed(1)} 次，'
          '共 $minutes 分钟',
    );
  }
}

/// 近期训练统计
class _RecentStats {
  final int count;
  final double weeklyAvg;
  final String text;

  const _RecentStats({
    required this.count,
    required this.weeklyAvg,
    required this.text,
  });
}
