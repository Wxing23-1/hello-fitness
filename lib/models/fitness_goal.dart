/// 健身目标类型
enum GoalType {
  loseWeight('减脂', '降低体脂率，塑造线条'),
  gainMuscle('增肌', '增加肌肉量和力量'),
  keepFit('保持', '维持当前身材和健康状态');

  /// 显示给用户看的中文名
  final String label;

  /// 这个目标的简短说明，显示在选项下方
  final String description;

  const GoalType(this.label, this.description);
}

/// 健身目标数据模型
///
/// 对应「目标设置调整」页面的全部可配置项。
/// 同样设计成不可变类，改数据走 copyWith。
class FitnessGoal {
  /// 目标类型：减脂 / 增肌 / 保持
  final GoalType type;

  /// 目标体重，单位公斤
  final double targetWeightKg;

  /// 每周计划训练次数
  final int weeklyWorkouts;

  /// 每日卡路里摄入目标，单位千卡
  final int dailyCalories;

  /// 每日饮水目标，单位毫升
  final int dailyWaterMl;

  const FitnessGoal({
    required this.type,
    required this.targetWeightKg,
    required this.weeklyWorkouts,
    required this.dailyCalories,
    required this.dailyWaterMl,
  });

  /// 默认目标，APP首次启动时用这份数据
  factory FitnessGoal.initial() {
    return const FitnessGoal(
      type: GoalType.loseWeight,
      targetWeightKg: 65,
      weeklyWorkouts: 4,
      dailyCalories: 1800,
      dailyWaterMl: 2000,
    );
  }

  /// 转成 Map，用于存进 Hive
  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'targetWeightKg': targetWeightKg,
      'weeklyWorkouts': weeklyWorkouts,
      'dailyCalories': dailyCalories,
      'dailyWaterMl': dailyWaterMl,
    };
  }

  /// 从 Map 还原对象
  factory FitnessGoal.fromMap(Map<dynamic, dynamic> map) {
    // 越界时退回第一个枚举值，而不是 clamp 到最后一个
    final typeIndex = map['type'] as int? ?? 0;
    final type = (typeIndex >= 0 && typeIndex < GoalType.values.length)
        ? GoalType.values[typeIndex]
        : GoalType.loseWeight;

    return FitnessGoal(
      type: type,
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble() ?? 65,
      weeklyWorkouts: map['weeklyWorkouts'] as int? ?? 4,
      dailyCalories: map['dailyCalories'] as int? ?? 1800,
      dailyWaterMl: map['dailyWaterMl'] as int? ?? 2000,
    );
  }

  /// 复制当前对象并替换掉指定字段
  FitnessGoal copyWith({
    GoalType? type,
    double? targetWeightKg,
    int? weeklyWorkouts,
    int? dailyCalories,
    int? dailyWaterMl,
  }) {
    return FitnessGoal(
      type: type ?? this.type,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      weeklyWorkouts: weeklyWorkouts ?? this.weeklyWorkouts,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      dailyWaterMl: dailyWaterMl ?? this.dailyWaterMl,
    );
  }
}
