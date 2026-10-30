import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import '../../services/user_store.dart';
import 'ai_food_page.dart';
import 'custom_food_page.dart';
import 'portion_sheet.dart';

/// 食物选择页
///
/// 搜索或按分类浏览食物库，选中后弹出份量输入，确认即记录。
/// 库里没有的可以让 AI 估算，或手动添加成自定义食物。
class FoodPickerPage extends StatefulWidget {
  /// 要记到哪一餐
  final MealType mealType;

  /// 要记到哪一天
  final DateTime day;

  const FoodPickerPage({
    super.key,
    required this.mealType,
    required this.day,
  });

  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  final _searchController = TextEditingController();

  /// 搜索关键词
  String _keyword = '';

  /// 当前筛选的分类，null 表示全部
  FoodCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final foods = _filtered(store);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('添加${widget.mealType.label}'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          const Divider(height: 1),
          Expanded(
            child: foods.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    itemCount: foods.length,
                    itemBuilder: (ctx, i) => _FoodTile(
                      food: foods[i],
                      onTap: () => _pickPortion(foods[i]),
                      // 自定义食物可以删，内置的不行
                      onDelete: store.customFoods.contains(foods[i])
                          ? () => _deleteCustom(store, foods[i])
                          : null,
                    ),
                  ),
          ),
        ],
      ),
      // 两个兜底入口：AI 估算和手动添加
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            onPressed: _addCustom,
            heroTag: 'custom',
            tooltip: '手动添加食物',
            child: const Icon(Icons.edit),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            onPressed: _askAi,
            heroTag: 'ai',
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 识别'),
          ),
        ],
      ),
    );
  }

  /// 按关键词和分类筛选
  List<FoodItem> _filtered(UserStore store) {
    var list = store.searchFoods(_keyword);

    if (_category != null) {
      list = list.where((f) => f.category == _category).toList();
    }

    return list;
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _keyword = v),
        decoration: InputDecoration(
          hintText: '搜索食物名称',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _keyword.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
                  },
                  icon: const Icon(Icons.clear, size: 18),
                ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  /// 分类筛选横向滚动条
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(null, '全部'),
          ...FoodCategory.values.map(
            (c) => _chip(c, '${c.emoji} ${c.label}'),
          ),
        ],
      ),
    );
  }

  Widget _chip(FoodCategory? value, String label) {
    final selected = _category == value;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              '没找到「$_keyword」',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '可以用右下角的 AI 识别估算，\n或手动添加到自己的食物库',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出份量输入，确认后记录并返回
  void _pickPortion(FoodItem food) async {
    final grams = await showPortionSheet(context, food);
    if (grams == null || !mounted) return;

    context.read<UserStore>().addMeal(
          MealEntry.fromFood(
            food: food,
            mealType: widget.mealType,
            grams: grams,
            // 记到用户正在看的那一天，而不是永远记到今天
            eatenAt: _mergeDayWithNow(widget.day),
          ),
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已记录 ${food.name}'),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
  }

  /// 把目标日期和当前时刻拼起来
  ///
  /// 补记前几天的饭时，日期用选中那天，时间用现在 ——
  /// 时间只影响同一餐内的排序，不需要精确
  DateTime _mergeDayWithNow(DateTime day) {
    final now = DateTime.now();
    return DateTime(day.year, day.month, day.day, now.hour, now.minute);
  }

  /// 去 AI 识别页
  void _askAi() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiFoodPage(
          mealType: widget.mealType,
          day: widget.day,
          // 搜索框里打了字就带过去，省得重新输
          initialQuery: _keyword,
        ),
      ),
    );

    // AI 页记录成功后会自己 pop，这里跟着关掉选择页回到饮食首页
    if (mounted && context.read<UserStore>().todayMeals.isNotEmpty) {
      // 不强制 pop —— 用户可能想继续加别的
    }
  }

  /// 手动添加自定义食物
  void _addCustom() async {
    final created = await Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const CustomFoodPage()),
    );

    if (created == null || !mounted) return;

    // 加完直接进份量输入，省一步操作
    _pickPortion(created);
  }

  /// 删除自定义食物
  void _deleteCustom(UserStore store, FoodItem food) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除食物'),
        content: Text('从你的食物库移除「${food.name}」？\n已记录的饮食不受影响。'),
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

    if (confirm == true) store.deleteCustomFood(food.id);
  }
}

/// 食物列表项
class _FoodTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;

  /// 删除回调，null 表示不能删（内置食物）
  final VoidCallback? onDelete;

  const _FoodTile({
    required this.food,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Text(
        food.category.emoji,
        style: const TextStyle(fontSize: 22),
      ),
      title: Text(food.name, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        '${food.caloriesPer100g.round()} 千卡/100g · '
        '蛋白 ${food.proteinPer100g}g · '
        '碳水 ${food.carbsPer100g}g · '
        '脂肪 ${food.fatPer100g}g',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: onDelete == null
          ? const Icon(Icons.chevron_right, size: 20)
          : IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 19),
              color: Colors.red.shade300,
            ),
      dense: true,
    );
  }
}
