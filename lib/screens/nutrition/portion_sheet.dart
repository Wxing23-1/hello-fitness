import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../utils/nutrition_utils.dart';

/// 弹出份量输入，返回用户填的克数；取消返回 null
///
/// 做成底部弹窗而不是新页面：选完食物马上填量，一气呵成
Future<double?> showPortionSheet(BuildContext context, FoodItem food) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PortionSheet(food: food),
  );
}

class _PortionSheet extends StatefulWidget {
  final FoodItem food;

  const _PortionSheet({required this.food});

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late final TextEditingController _controller;

  /// 当前克数，实时算营养用
  late double _grams;

  @override
  void initState() {
    super.initState();
    // 预填默认份量，多数情况用户直接确认就行
    _grams = widget.food.defaultGrams;
    _controller = TextEditingController(text: formatGrams(_grams));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 输入变化时重算
  void _onChanged(String v) {
    final parsed = double.tryParse(v.trim());
    setState(() => _grams = (parsed ?? 0).clamp(0, 5000));
  }

  /// 快捷份量按钮
  void _setGrams(double g) {
    _controller.text = formatGrams(g);
    setState(() => _grams = g);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;

    return SafeArea(
      child: Padding(
        // 键盘弹起时把内容顶上去，不然输入框被挡住
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食物名 + 分类
            Row(
              children: [
                Text(
                  food.category.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    food.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // 份量参考，用户往往不知道一份多少克
            if (food.portionHint != null) ...[
              const SizedBox(height: 6),
              Text(
                food.portionHint!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],

            const SizedBox(height: 16),

            // 克数输入
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _onChanged,
              decoration: const InputDecoration(
                labelText: '份量',
                suffixText: '克',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 10),

            // 快捷份量
            Wrap(
              spacing: 7,
              children: [
                // 默认份量和它的倍数 —— 吃一份半、两份很常见
                _quickChip(food.defaultGrams, '1份'),
                _quickChip(food.defaultGrams * 0.5, '半份'),
                _quickChip(food.defaultGrams * 2, '2份'),
                _quickChip(100, '100g'),
                _quickChip(200, '200g'),
              ],
            ),

            const SizedBox(height: 18),

            // 实时营养预览
            _buildPreview(food),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // 份量为 0 没意义，挡住
                onPressed: _grams > 0
                    ? () => Navigator.pop(context, _grams)
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('确认记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(double grams, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => _setGrams(grams),
      visualDensity: VisualDensity.compact,
    );
  }

  /// 按当前克数算出的营养值
  Widget _buildPreview(FoodItem food) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(
            formatCalories(food.caloriesFor(_grams)),
            '千卡',
            Colors.green.shade800,
            big: true,
          ),
          _divider(),
          _item(
            formatMacro(food.proteinFor(_grams)),
            '蛋白(g)',
            Colors.red.shade400,
          ),
          _divider(),
          _item(
            formatMacro(food.carbsFor(_grams)),
            '碳水(g)',
            Colors.blue.shade400,
          ),
          _divider(),
          _item(
            formatMacro(food.fatFor(_grams)),
            '脂肪(g)',
            Colors.amber.shade700,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 28,
        color: Colors.green.shade100,
      );

  Widget _item(String value, String label, Color color, {bool big = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: big ? 19 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
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
