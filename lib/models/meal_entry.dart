import 'food_item.dart';

/// 一条饮食记录
///
/// 表示「某个时间吃了某种食物多少克」。
/// 营养数据在记录时从 FoodItem 快照下来，不存引用 ——
/// 食物库的数据以后可能修正，但已经吃掉的那顿不该跟着变。
class MealEntry {
  /// 唯一标识
  final String id;

  /// 哪一餐
  final MealType mealType;

  /// 吃的时间
  final DateTime eatenAt;

  /// 食物名称（快照）
  final String foodName;

  /// 实际吃了多少克
  final double grams;

  /// 这一份的热量（千卡，已按克数换算好）
  final double calories;

  /// 这一份的蛋白质（克）
  final double protein;

  /// 这一份的碳水（克）
  final double carbs;

  /// 这一份的脂肪（克）
  final double fat;

  /// 食物分类（快照，用于统计各类占比）
  final FoodCategory category;

  /// 备注，比如「在外面吃的，估算」
  final String? note;

  /// 这条记录是不是 AI 识别出来的
  ///
  /// AI 估算的数据准确度不如手动查表，界面上标出来让用户知道
  final bool fromAi;

  const MealEntry({
    required this.id,
    required this.mealType,
    required this.eatenAt,
    required this.foodName,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.category,
    this.note,
    this.fromAi = false,
  });

  /// 从食物库条目创建记录
  ///
  /// 自动按克数换算营养成分，省得调用方手算
  factory MealEntry.fromFood({
    required FoodItem food,
    required MealType mealType,
    required double grams,
    DateTime? eatenAt,
    String? note,
    bool fromAi = false,
  }) {
    final now = eatenAt ?? DateTime.now();

    return MealEntry(
      id: 'meal_${now.millisecondsSinceEpoch}_${food.id}',
      mealType: mealType,
      eatenAt: now,
      foodName: food.name,
      grams: grams,
      calories: food.caloriesFor(grams),
      protein: food.proteinFor(grams),
      carbs: food.carbsFor(grams),
      fat: food.fatFor(grams),
      category: food.category,
      note: note,
      fromAi: fromAi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mealType': mealType.index,
      'eatenAt': eatenAt.millisecondsSinceEpoch,
      'foodName': foodName,
      'grams': grams,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'category': category.index,
      'note': note,
      'fromAi': fromAi,
    };
  }

  factory MealEntry.fromMap(Map map) {
    // 两个枚举都按 index 存，越界退回默认值
    final mealIdx = map['mealType'] as int?;
    final mealType =
        (mealIdx != null && mealIdx >= 0 && mealIdx < MealType.values.length)
            ? MealType.values[mealIdx]
            : MealType.snack;

    final catIdx = map['category'] as int?;
    final category =
        (catIdx != null && catIdx >= 0 && catIdx < FoodCategory.values.length)
            ? FoodCategory.values[catIdx]
            : FoodCategory.other;

    return MealEntry(
      id: map['id'] as String? ?? '',
      mealType: mealType,
      eatenAt: DateTime.fromMillisecondsSinceEpoch(
        map['eatenAt'] as int? ?? 0,
      ),
      foodName: map['foodName'] as String? ?? '未知食物',
      grams: (map['grams'] as num?)?.toDouble() ?? 0,
      calories: (map['calories'] as num?)?.toDouble() ?? 0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0,
      category: category,
      note: map['note'] as String?,
      fromAi: map['fromAi'] as bool? ?? false,
    );
  }
}

/// 一组饮食记录的营养汇总
///
/// 把「这一天吃了多少热量和宏量素」算出来。
/// 做成独立类而不是散落的几个 getter，方便整体传给图表组件。
class NutritionSummary {
  /// 总热量（千卡）
  final double calories;

  /// 总蛋白质（克）
  final double protein;

  /// 总碳水（克）
  final double carbs;

  /// 总脂肪（克）
  final double fat;

  /// 记录条数
  final int entryCount;

  const NutritionSummary({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.entryCount,
  });

  /// 空汇总，没有记录时用
  static const empty = NutritionSummary(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
    entryCount: 0,
  );

  /// 汇总一组记录
  factory NutritionSummary.from(List<MealEntry> entries) {
    if (entries.isEmpty) return empty;

    var kcal = 0.0;
    var p = 0.0;
    var c = 0.0;
    var f = 0.0;

    for (final e in entries) {
      kcal += e.calories;
      p += e.protein;
      c += e.carbs;
      f += e.fat;
    }

    return NutritionSummary(
      calories: kcal,
      protein: p,
      carbs: c,
      fat: f,
      entryCount: entries.length,
    );
  }

  /// 按餐次分组汇总
  ///
  /// 饮食首页要按三餐分别显示小计
  static Map<MealType, NutritionSummary> groupByMeal(
    List<MealEntry> entries,
  ) {
    final result = <MealType, NutritionSummary>{};

    for (final type in MealType.values) {
      final ofType = entries.where((e) => e.mealType == type).toList();
      result[type] = NutritionSummary.from(ofType);
    }

    return result;
  }

  /// 三大宏量素各占总热量的百分比
  ///
  /// 返回 (蛋白, 碳水, 脂肪) 三个 0-100 的值。
  /// 用实际热量而不是克数算占比 —— 脂肪每克 9 千卡，
  /// 按克数算会严重低估它的热量贡献
  (double, double, double) get macroPercents {
    final pKcal = protein * 4;
    final cKcal = carbs * 4;
    final fKcal = fat * 9;
    final total = pKcal + cKcal + fKcal;

    if (total <= 0) return (0, 0, 0);

    return (
      pKcal / total * 100,
      cKcal / total * 100,
      fKcal / total * 100,
    );
  }
}

/// 餐次
///
/// 带建议时段：记录时按当前时间自动选中对应餐次，减少操作
enum MealType {
  breakfast('早餐', '🌅', 5, 10),
  lunch('午餐', '☀️', 10, 15),
  dinner('晚餐', '🌙', 16, 21),
  snack('加餐', '🍎', 0, 24);

  final String label;
  final String emoji;

  /// 建议时段的起止小时（24 小时制）
  final int startHour;
  final int endHour;

  const MealType(this.label, this.emoji, this.startHour, this.endHour);

  /// 按当前时刻猜是哪一餐
  ///
  /// 不在三餐时段内就算加餐
  static MealType guessByHour(int hour) {
    for (final t in [breakfast, lunch, dinner]) {
      if (hour >= t.startHour && hour < t.endHour) return t;
    }
    return snack;
  }
}
