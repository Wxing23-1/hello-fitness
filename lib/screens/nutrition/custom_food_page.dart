import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_item.dart';
import '../../services/user_store.dart';

/// 手动添加食物
///
/// 内置库 70 条覆盖不了所有情况（自制菜、地方小吃、进口商品）。
/// 填一次存进自己的库，以后直接选。
///
/// 保存成功后 pop 回创建好的 FoodItem，调用方可以直接进份量输入。
class CustomFoodPage extends StatefulWidget {
  const CustomFoodPage({super.key});

  @override
  State<CustomFoodPage> createState() => _CustomFoodPageState();
}

class _CustomFoodPageState extends State<CustomFoodPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _gramsController = TextEditingController(text: '100');

  FoodCategory _category = FoodCategory.other;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('添加食物'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHint(),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '食物名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
            ),
            const SizedBox(height: 16),

            // 分类
            DropdownButtonFormField<FoodCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: FoodCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.emoji} ${c.label}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 20),

            Text(
              '每 100 克的营养成分',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '看包装上的营养成分表，通常标的就是每 100 克',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 12),

            _numberField(_caloriesController, '热量', '千卡', required: true),
            const SizedBox(height: 12),
            _numberField(_proteinController, '蛋白质', '克'),
            const SizedBox(height: 12),
            _numberField(_carbsController, '碳水化合物', '克'),
            const SizedBox(height: 12),
            _numberField(_fatController, '脂肪', '克'),

            const SizedBox(height: 20),
            _numberField(
              _gramsController,
              '常见份量',
              '克',
              required: true,
              helper: '记录时会预填这个值，比如一个鸡蛋填 50',
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存到我的食物库'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 17, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '只有名称、热量和份量是必填的，宏量素不确定可以留空',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 数字输入框
  ///
  /// 非必填的留空算 0 —— 用户常常只知道热量不知道宏量素，
  /// 强制填会让他们瞎猜，不如留空
  Widget _numberField(
    TextEditingController controller,
    String label,
    String unit, {
    bool required = false,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        suffixText: unit,
        helperText: helper,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) {
        final text = v?.trim() ?? '';

        if (text.isEmpty) {
          return required ? '$label不能为空' : null;
        }

        final n = double.tryParse(text);
        if (n == null) return '请填数字';
        if (n < 0) return '不能是负数';
        // 每 100 克热量超过 900 不合理（纯油脂约 900）
        if (required && label == '热量' && n > 900) return '热量数值过大';

        return null;
      },
    );
  }

  /// 把输入框里的值读成 double，空值算 0
  double _read(TextEditingController c) =>
      double.tryParse(c.text.trim()) ?? 0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final food = FoodItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _category,
      caloriesPer100g: _read(_caloriesController),
      proteinPer100g: _read(_proteinController),
      carbsPer100g: _read(_carbsController),
      fatPer100g: _read(_fatController),
      defaultGrams: _read(_gramsController),
    );

    context.read<UserStore>().addCustomFood(food);

    Navigator.pop(context, food);
  }
}
