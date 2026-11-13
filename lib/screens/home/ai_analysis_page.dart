import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ai_analysis_service.dart';
import '../../services/user_store.dart';

/// AI 今日健身效果分析页
///
/// 打开就自动把今天的训练、饮食、体重数据发给 AI 分析，
/// 结果分几块展示：总体评价 / 训练 / 饮食 / 建议 / 明天安排。
/// 没有用户输入项，所以进页即分析。
class AiAnalysisPage extends StatefulWidget {
  const AiAnalysisPage({super.key});

  @override
  State<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends State<AiAnalysisPage> {
  bool _loading = false;
  String? _error;
  AiDailyAnalysis? _analysis;

  @override
  void initState() {
    super.initState();
    // 等首帧渲染完再触发，避免在 build 期间读 provider 报错
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  Future<void> _analyze() async {
    final store = context.read<UserStore>();

    if (!store.isSignedIn) {
      setState(() {
        _error = '请先登录后再使用 AI 分析';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _analysis = null;
    });

    final result = await AiAnalysisService.analyze(
      profile: store.profile,
      goal: store.goal,
      activityLevel: store.activityLevel,
      dailyCalorieTarget: store.dailyCalorieTarget,
      workoutLogs: store.workoutLogs,
      meals: store.meals,
      weightLogs: store.weightLogs,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.success) {
        _analysis = result.analysis;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AI 今日分析'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),

          if (_loading) ...[
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'AI 正在分析你今天的训练和饮食...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],

          if (_error != null) ...[
            _buildErrorCard(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],

          if (_analysis != null) ...[
            _buildResult(_analysis!),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.refresh),
              label: const Text('重新分析'),
            ),
          ],
        ],
      ),
    );
  }

  /// 顶部说明卡
  Widget _buildHeader() {
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
      child: const Row(
        children: [
          Icon(Icons.insights, color: Colors.white, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '结合你今天真实的训练、饮食和体重数据，'
              'AI 给你一份专属复盘和明天的安排。',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
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
                fontSize: 13,
                height: 1.4,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(AiDailyAnalysis a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 总体评价（高亮）──
        _sectionCard(
          icon: Icons.summarize,
          iconColor: Colors.indigo,
          title: '今日总结',
          child: Text(
            a.summary.isEmpty ? '（无内容）' : a.summary,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 训练分析 ──
        _sectionCard(
          icon: Icons.fitness_center,
          iconColor: Colors.blue,
          title: '训练效果',
          child: Text(
            a.workoutReview.isEmpty ? '（无内容）' : a.workoutReview,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),

        // ── 饮食分析 ──
        _sectionCard(
          icon: Icons.restaurant,
          iconColor: Colors.orange,
          title: '饮食分析',
          child: Text(
            a.dietReview.isEmpty ? '（无内容）' : a.dietReview,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),

        // ── 建议 ──
        if (a.suggestions.isNotEmpty) ...[
          _sectionCard(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber.shade800,
            title: '给今天的建议',
            child: Column(
              children: a.suggestions
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.suggestions.indexOf(s) + 1}. ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── 明天安排 ──
        _sectionCard(
          icon: Icons.event_available,
          iconColor: Colors.teal,
          title: '明天的安排',
          child: Text(
            a.tomorrowPlan.isEmpty ? '（无内容）' : a.tomorrowPlan,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  /// 统一的分段卡片
  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
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
              Icon(icon, size: 17, color: iconColor),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
