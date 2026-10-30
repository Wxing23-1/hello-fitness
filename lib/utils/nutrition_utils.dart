import '../models/fitness_goal.dart';
import '../models/user_profile.dart';

/// 营养计算工具
///
/// 把「每天该吃多少」这类计算从页面里抽出来，方便单独测试。
/// 所有公式都是运动营养学里的通用经验公式，不是精确医学结论。

// ═══════════════════════════════════════════════════════
//  基础代谢与每日消耗
// ═══════════════════════════════════════════════════════

/// 计算基础代谢率（BMR，千卡/天）
///
/// 用 Mifflin-St Jeor 公式 —— 比老的 Harris-Benedict 更准，
/// 是现在运动营养领域的通用选择。
///
/// 男：10×体重(kg) + 6.25×身高(cm) − 5×年龄 + 5
/// 女：10×体重(kg) + 6.25×身高(cm) − 5×年龄 − 161
int calculateBmr(UserProfile profile) {
  if (profile.weightKg <= 0 || profile.heightCm <= 0 || profile.age <= 0) {
    return 0;
  }

  final base = 10 * profile.weightKg +
      6.25 * profile.heightCm -
      5 * profile.age;

  // 性别只影响最后那个常数项
  final offset = profile.gender == Gender.female ? -161.0 : 5.0;

  return (base + offset).round();
}

/// 活动强度等级
///
/// 用来把 BMR 放大成实际每日消耗（TDEE）。
/// 系数是运动营养学的通用取值
enum ActivityLevel {
  sedentary('久坐', '几乎不运动，办公室工作', 1.2),
  light('轻度活动', '每周运动 1-3 次', 1.375),
  moderate('中度活动', '每周运动 3-5 次', 1.55),
  active('高度活动', '每周运动 6-7 次', 1.725),
  veryActive('运动员级', '每天高强度训练或体力劳动', 1.9);

  final String label;
  final String description;

  /// 乘在 BMR 上的系数
  final double factor;

  const ActivityLevel(this.label, this.description, this.factor);
}

/// 计算每日总消耗（TDEE，千卡/天）
///
/// TDEE = BMR × 活动系数。这是「吃多少不胖不瘦」的基准线
int calculateTdee(UserProfile profile, ActivityLevel level) {
  final bmr = calculateBmr(profile);
  if (bmr == 0) return 0;

  return (bmr * level.factor).round();
}

/// 按健身目标算每日摄入建议（千卡/天）
///
/// 减脂留 20% 缺口，增肌加 15% 盈余 —— 这两个幅度比较温和，
/// 缺口太大会掉肌肉，盈余太多会长脂肪。
int recommendedCalories(UserProfile profile, ActivityLevel level, GoalType goal) {
  final tdee = calculateTdee(profile, level);
  if (tdee == 0) return 0;

  switch (goal) {
    case GoalType.loseWeight:
      return (tdee * 0.8).round();
    case GoalType.gainMuscle:
      return (tdee * 1.15).round();
    case GoalType.keepFit:
      return tdee;
  }
}

// ═══════════════════════════════════════════════════════
//  宏量营养素
// ═══════════════════════════════════════════════════════

/// 三大宏量素的每日目标（克）
class MacroTargets {
  /// 蛋白质（克）
  final int protein;

  /// 碳水化合物（克）
  final int carbs;

  /// 脂肪（克）
  final int fat;

  /// 对应的总热量（千卡）
  final int calories;

  const MacroTargets({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
  });
}

/// 每克宏量素的热量（千卡）
///
/// 蛋白质和碳水 4，脂肪 9 —— 营养学的标准换算值
const double kcalPerGramProtein = 4;
const double kcalPerGramCarbs = 4;
const double kcalPerGramFat = 9;

/// 按目标分配三大宏量素
///
/// 分配思路：
///   蛋白质按体重定（减脂 2.0 g/kg 保肌肉，增肌 1.8，维持 1.5）
///   脂肪占总热量的 25%（低于 20% 会影响激素水平）
///   剩下的热量全给碳水
///
/// 先定蛋白和脂肪再算碳水，因为前两者有生理下限，碳水是弹性项
MacroTargets calculateMacros({
  required double weightKg,
  required int dailyCalories,
  required GoalType goal,
}) {
  if (weightKg <= 0 || dailyCalories <= 0) {
    return const MacroTargets(protein: 0, carbs: 0, fat: 0, calories: 0);
  }

  // 蛋白质按体重算
  final double proteinPerKg;
  switch (goal) {
    case GoalType.loseWeight:
      // 减脂期热量不足，蛋白要高一点才不掉肌肉
      proteinPerKg = 2.0;
      break;
    case GoalType.gainMuscle:
      proteinPerKg = 1.8;
      break;
    case GoalType.keepFit:
      proteinPerKg = 1.5;
      break;
  }

  final protein = (weightKg * proteinPerKg).round();
  final proteinKcal = protein * kcalPerGramProtein;

  // 脂肪占 25% 总热量
  final fatKcal = dailyCalories * 0.25;
  final fat = (fatKcal / kcalPerGramFat).round();

  // 剩下的给碳水，不够就归零（极低热量目标下可能出现）
  final carbsKcal = dailyCalories - proteinKcal - fatKcal;
  final carbs = carbsKcal > 0 ? (carbsKcal / kcalPerGramCarbs).round() : 0;

  return MacroTargets(
    protein: protein,
    carbs: carbs,
    fat: fat,
    calories: dailyCalories,
  );
}

/// 每日饮水建议（毫升）
///
/// 按体重 35 ml/kg 估，训练日额外加 500 ml 补汗液流失
int recommendedWaterMl(double weightKg, {bool isTrainingDay = false}) {
  if (weightKg <= 0) return 0;

  final base = (weightKg * 35).round();
  return isTrainingDay ? base + 500 : base;
}

// ═══════════════════════════════════════════════════════
//  格式化
// ═══════════════════════════════════════════════════════

/// 格式化热量，去掉无意义的小数
///
/// 342.7 千卡 显示成「343」—— 食物热量本来就是估算，
/// 显示小数位反而给人虚假的精确感
String formatCalories(double kcal) => kcal.round().toString();

/// 格式化宏量素克数
///
/// 保留一位小数：蛋白质 23.5 克和 23 克在控量时有区别
String formatMacro(double grams) {
  if (grams >= 100) return grams.round().toString();
  return grams.toStringAsFixed(1);
}

/// 格式化重量，整数不显示小数点
String formatGrams(double grams) {
  if (grams == grams.roundToDouble()) return grams.toInt().toString();
  return grams.toStringAsFixed(1);
}
