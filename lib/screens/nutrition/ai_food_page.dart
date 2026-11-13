import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../services/ai_food_service.dart';
import '../../services/user_store.dart';
import 'portion_sheet.dart';

/// AI 估算食物营养
///
/// 用在内置库查不到的时候：用户用自己的话描述吃了什么，
/// AI 返回估算的营养成分，确认后记录。
class AiFoodPage extends StatefulWidget {
  final MealType mealType;
  final DateTime day;

  /// 从食物选择页带过来的搜索词，省得重新输
  final String initialQuery;

  const AiFoodPage({
    super.key,
    required this.mealType,
    required this.day,
    this.initialQuery = '',
  });

  @override
  State<AiFoodPage> createState() => _AiFoodPageState();
}

class _AiFoodPageState extends State<AiFoodPage> {
  late final TextEditingController _controller;

  bool _loading = false;
  String? _error;

  /// AI 返回的估算结果
  AiFoodEstimate? _result;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final store = context.read<UserStore>();

    if (!store.isSignedIn) {
      setState(() {
        _error = '请先登录后再使用 AI 估算';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    final res = await AiFoodService.estimate(
      description: _controller.text,
    );

    // await 期间用户可能已经返回了
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res.success) {
        _result = res.estimate;
      } else {
        _error = res.error;
      }
    });
  }

  /// 确认记录
  Future<void> _record() async {
    final est = _result;
    if (est == null) return;

    final grams = await showPortionSheet(context, est.food);
    if (grams == null || !mounted) return;

    final now = DateTime.now();

    context.read<UserStore>().addMeal(
          MealEntry.fromFood(
            food: est.food,
            mealType: widget.mealType,
            grams: grams,
            // 日期用用户选的那天，时刻用现在
            eatenAt: DateTime(
              widget.day.year,
              widget.day.month,
              widget.day.day,
              now.hour,
              now.minute,
            ),
            // 标记来源，界面上会显示 AI 图标提示数据是估算的
            fromAi: true,
          ),
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录 ${est.food.name}'),
        duration: const Duration(seconds: 2),
      ),
    );

    // 关掉 AI 页和食物选择页，回到饮食首页看结果
    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('AI 估算营养'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntro(),
          const SizedBox(height: 16),

          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 100,
            autofocus: widget.initialQuery.isEmpty,
            decoration: InputDecoration(
              labelText: '你吃了什么',
              hintText: '比如：食堂的番茄炒蛋一盘\n麻辣烫，加了豆皮和青菜\n一个肉夹饼',
              hintStyle: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey.shade400,
              ),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _loading ? null : _estimate,
            icon: _loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_loading ? '估算中...' : '让 AI 估算'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),

          if (!store.isSignedIn) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '需要先登录才能使用 AI 估算',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 14),
            _buildError(),
          ],

          if (_result != null) ...[
            const SizedBox(height: 18),
            _buildResult(),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '食物库里没有的，描述一下让 AI 估算。\n'
              '说得越具体越准，比如提一下做法和份量。',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 估算结果卡
  Widget _buildResult() {
    final est = _result!;
    final f = est.food;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(f.category.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'AI 估算',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            '每 100 克',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macro('${f.caloriesPer100g.round()}', '千卡'),
              _macro('${f.proteinPer100g}', '蛋白(g)'),
              _macro('${f.carbsPer100g}', '碳水(g)'),
              _macro('${f.fatPer100g}', '脂肪(g)'),
            ],
          ),

          // AI 的估算说明，让用户知道它假设了什么
          if (est.note != null && est.note!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      est.note!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              // 结果不满意可以改描述重试
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _estimate,
                  child: const Text('重新估算'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _record,
                  child: const Text('确认并记录'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macro(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
