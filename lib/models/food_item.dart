/// 食物条目
///
/// 表示「一份食物的营养成分」，是食物库里的一条数据。
/// 用户记录饮食时选中某个 FoodItem，再填实际吃了多少克，
/// 就生成一条 MealEntry（见 meal_entry.dart）。
///
/// 营养成分统一按「每 100 克」存储，这是食物营养表的通用口径，
/// 换算成实际份量时按比例乘。
class FoodItem {
  /// 唯一标识
  final String id;

  /// 食物名称
  final String name;

  /// 所属分类
  final FoodCategory category;

  /// 每 100 克的热量（千卡）
  final double caloriesPer100g;

  /// 每 100 克的蛋白质（克）
  final double proteinPer100g;

  /// 每 100 克的碳水化合物（克）
  final double carbsPer100g;

  /// 每 100 克的脂肪（克）
  final double fatPer100g;

  /// 常见份量描述，比如「一个鸡蛋约 50 克」
  ///
  /// 用户往往不知道一份是多少克，给个参考比让他们猜更好
  final String? portionHint;

  /// 这一份的默认克数
  ///
  /// 记录时预填这个值，减少输入。比如鸡蛋默认 50 克
  final double defaultGrams;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.portionHint,
    this.defaultGrams = 100,
  });

  /// 按实际克数算热量
  double caloriesFor(double grams) => caloriesPer100g * grams / 100;

  /// 按实际克数算蛋白质
  double proteinFor(double grams) => proteinPer100g * grams / 100;

  /// 按实际克数算碳水
  double carbsFor(double grams) => carbsPer100g * grams / 100;

  /// 按实际克数算脂肪
  double fatFor(double grams) => fatPer100g * grams / 100;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'portionHint': portionHint,
      'defaultGrams': defaultGrams,
    };
  }

  factory FoodItem.fromMap(Map map) {
    // 枚举存的是 index，越界时退回默认分类而不是崩溃
    final idx = map['category'] as int?;
    final category = (idx != null && idx >= 0 && idx < FoodCategory.values.length)
        ? FoodCategory.values[idx]
        : FoodCategory.other;

    return FoodItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '未知食物',
      category: category,
      // 用 num 兜住：jsonDecode 会把 50.0 读成 int
      caloriesPer100g: (map['caloriesPer100g'] as num?)?.toDouble() ?? 0,
      proteinPer100g: (map['proteinPer100g'] as num?)?.toDouble() ?? 0,
      carbsPer100g: (map['carbsPer100g'] as num?)?.toDouble() ?? 0,
      fatPer100g: (map['fatPer100g'] as num?)?.toDouble() ?? 0,
      portionHint: map['portionHint'] as String?,
      defaultGrams: (map['defaultGrams'] as num?)?.toDouble() ?? 100,
    );
  }
}

/// 食物分类
///
/// 分类主要用于食物库的筛选和浏览。
/// 带 emoji 是为了在列表里快速区分，比纯文字好认
enum FoodCategory {
  staple('主食', '🍚', '米饭、面条、馒头、薯类'),
  protein('蛋白类', '🥩', '肉、蛋、奶、豆制品'),
  vegetable('蔬菜', '🥬', '绿叶菜、瓜茄、菌菇'),
  fruit('水果', '🍎', '各类新鲜水果'),
  nut('坚果', '🥜', '坚果和种子'),
  drink('饮品', '🥤', '饮料、奶茶、酒水'),
  snack('零食', '🍪', '饼干、糖果、油炸食品'),
  other('其他', '🍽️', '未分类食物');

  final String label;
  final String emoji;
  final String description;

  const FoodCategory(this.label, this.emoji, this.description);
}
