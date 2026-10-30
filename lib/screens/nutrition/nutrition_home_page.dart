import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_entry.dart';
import '../../services/user_store.dart';
import '../../utils/nutrition_utils.dart';
import 'food_picker_page.dart';
import 'nutrition_history_page.dart';

/// 饮食记录首页
///
/// 核心是回答「今天还能吃多少」：顶部热量环显示已摄入 / 目标，
/// 下面按三餐分组列出吃了什么，每餐都能直接加。
class NutritionHomePage extends StatefulWidget {
  const NutritionHomePage({super.key});

  @override
  State<NutritionHomePage> createState() => _NutritionHomePageState();
}

class _NutritionHomePageState extends State<NutritionHomePage> {
  /// 当前查看的日期，默认今天
  ///
  /// 允许翻看前几天：晚上才想起补记中午吃的很常见
  DateTime _day = DateTime.now();

  /// 是不是在看今天
  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year &&
        _day.month == now.month &&
        _day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final meals = store.mealsOn(_day);
    final summary = store.summaryOn(_day);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('饮食记录'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NutritionHistoryPage(),
              ),
            ),
            icon: const Icon(Icons.history),
            tooltip: '历史记录',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDateBar(),
          const SizedBox(height: 14),
          _CalorieRing(summary: summary, store: store),
          const SizedBox(height: 14),
          _MacroBars(summary: summary, store: store),
          const SizedBox(height: 18),

          // 按三餐 + 加餐分组
          ...MealType.values.map(
            (type) => _MealSection(
              type: type,
              entries: meals.where((m) => m.mealType == type).toList(),
              onAdd: () => _addFood(type),
              onDelete: (id) => _confirmDelete(store, id),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 日期切换条
  Widget _buildDateBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(
            () => _day = _day.subtract(const Duration(days: 1)),
          ),
          icon: const Icon(Icons.chevron_left),
          tooltip: '前一天',
        ),
        Expanded(
          child: Center(
            child: Text(
              _isToday ? '今天' : '${_day.month}月${_day.day}日',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        IconButton(
          // 不让翻到未来：还没发生的事没什么可记的
          onPressed: _isToday
              ? null
              : () => setState(
                    () => _day = _day.add(const Duration(days: 1)),
                  ),
          icon: const Icon(Icons.chevron_right),
          tooltip: '后一天',
        ),
      ],
    );
  }

  /// 去选食物并记录
  void _addFood(MealType type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodPickerPage(mealType: type, day: _day),
      ),
    );
  }

  /// 删除前确认
  void _confirmDelete(UserStore store, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条饮食记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) store.deleteMeal(id);
  }
}
/// 今日热量环
///
/// 中间显示「还能吃多少」而不是「吃了多少」—— 剩余量才是
/// 决定下一餐吃什么的依据
class _CalorieRing extends StatelessWidget {
  final NutritionSummary summary;
  final UserStore store;

  const _CalorieRing({required this.summary, required this.store});

  @override
  Widget build(BuildContext context) {
    final target = store.dailyCalorieTarget;
    final eaten = summary.calories.round();
    final left = target - eaten;
    final over = left < 0;

    // 超了就满环，不要画出圈外
    final progress = target <= 0 ? 0.0 : (eaten / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // 环形进度
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      over ? Colors.deepOrange : Colors.green,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      over ? '${-left}' : '$left',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.bold,
                        color: over ? Colors.deepOrange : Colors.black87,
                      ),
                    ),
                    Text(
                      over ? '超出(千卡)' : '剩余(千卡)',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // 右侧数字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('目标', '$target', Colors.grey.shade700),
                const SizedBox(height: 8),
                _row('已摄入', '$eaten', Colors.green.shade700),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // 基础代谢给个参考，让用户理解目标是怎么来的
                _row(
                  '基础代谢',
                  '${store.bmr}',
                  Colors.grey.shade500,
                  small: true,
                ),
                const SizedBox(height: 4),
                _row(
                  '每日消耗',
                  '${store.tdee}',
                  Colors.grey.shade500,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool small = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: small ? 11 : 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: small ? 12 : 15,
            fontWeight: small ? FontWeight.normal : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 三大宏量素进度条
class _MacroBars extends StatelessWidget {
  final NutritionSummary summary;
  final UserStore store;

  const _MacroBars({required this.summary, required this.store});

  @override
  Widget build(BuildContext context) {
    final t = store.macroTargets;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _bar('蛋白质', summary.protein, t.protein, Colors.red.shade400),
          const SizedBox(height: 12),
          _bar('碳水', summary.carbs, t.carbs, Colors.blue.shade400),
          const SizedBox(height: 12),
          _bar('脂肪', summary.fat, t.fat, Colors.amber.shade600),
        ],
      ),
    );
  }

  Widget _bar(String label, double current, int target, Color color) {
    final progress = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(
              '${formatMacro(current)} / $target g',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// 一个餐次的区块
class _MealSection extends StatelessWidget {
  final MealType type;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;

  const _MealSection({
    required this.type,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = NutritionSummary.from(entries).calories.round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐次标题行
          Row(
            children: [
              Text(type.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (entries.isNotEmpty)
                Text(
                  '$kcal 千卡',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              const Spacer(),
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline, size: 22),
                color: Colors.green.shade600,
                tooltip: '添加${type.label}',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // 食物列表
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 4),
              child: Text(
                '还没记录',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            )
          else
            ...entries.map((e) => _FoodRow(entry: e, onDelete: onDelete)),
        ],
      ),
    );
  }
}

/// 一条食物记录
class _FoodRow extends StatelessWidget {
  final MealEntry entry;
  final void Function(String id) onDelete;

  const _FoodRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.foodName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // AI 估算的数据准确度不如查表，标出来
                    if (entry.fromAi) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: Colors.deepPurple.shade300,
                      ),
                    ],
                  ],
                ),
                Text(
                  '${formatGrams(entry.grams)} g · '
                  '蛋白 ${formatMacro(entry.protein)}g · '
                  '碳水 ${formatMacro(entry.carbs)}g · '
                  '脂肪 ${formatMacro(entry.fat)}g',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.calories.round()}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            ' kcal',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          IconButton(
            onPressed: () => onDelete(entry.id),
            icon: const Icon(Icons.close, size: 15),
            color: Colors.grey.shade400,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
