/// 训练目标类型
enum TrainingGoal {
  loseWeight('减脂', '降低体脂率，提升心肺'),
  gainMuscle('增肌', '增加肌肉量和力量'),
  keepFit('保持', '维持当前身材和体能');

  final String label;
  final String description;

  const TrainingGoal(this.label, this.description);
}

/// 训练难度等级
enum TrainingLevel {
  beginner('初级', '适合刚开始健身的人'),
  intermediate('中级', '有一定训练基础'),
  advanced('高级', '健身老手，追求突破');

  final String label;
  final String description;

  const TrainingLevel(this.label, this.description);
}

/// 训练类别：有氧 / 无氧 / 混合
///
/// 有氧（Aerobic）：中低强度持续性运动，靠氧气分解糖和脂肪供能。
///   心率一般在最大心率的 60-80%，能持续较长时间。
///   典型：慢跑、骑行、游泳、跳绳、椭圆机。
///   作用：消耗脂肪、提升心肺耐力。
///
/// 无氧（Anaerobic）：高强度短时运动，靠肌糖原无氧分解供能。
///   做不了太久，会产生乳酸导致肌肉酸痛。
///   典型：举铁、深蹲、卧推、短跑冲刺。
///   作用：增长肌肉、提升力量和基础代谢。
///
/// 混合（Mixed）：两者交替，比如 HIIT（高强度间歇训练），
///   冲刺时无氧、间歇时有氧，兼顾燃脂和保肌。
enum TrainingCategory {
  aerobic('有氧', '燃脂塑形、提升心肺', '中低强度持续运动，靠氧气供能', 7.0),
  anaerobic('无氧', '增肌塑形、提升力量', '高强度短时运动，靠肌糖原供能', 5.0),
  mixed('混合', '燃脂保肌、全面提升', '有氧无氧交替，兼顾两者优势', 8.0);

  /// 显示名
  final String label;

  /// 主要作用，用在卡片副标题
  final String benefit;

  /// 原理说明，用在详情页或帮助文案
  final String description;

  /// MET 代谢当量，用来估算卡路里消耗
  ///
  /// 取自《运动能量消耗概要》(Compendium of Physical Activities) 的经验值：
  /// 有氧类（慢跑、骑行）约 7、器械力量约 5、HIIT 循环约 8
  final double met;

  const TrainingCategory(
    this.label,
    this.benefit,
    this.description,
    this.met,
  );
}

/// 安全地把存储的 index 转回枚举值
///
/// 存储的数据可能因为版本升级或损坏而越界，这时退回 fallback，
/// 而不是用 clamp 夹到最后一个值（那样会得到一个语义完全错误的枚举）
T _enumFromIndex<T>(int? index, List<T> values, T fallback) {
  if (index == null || index < 0 || index >= values.length) return fallback;
  return values[index];
}

/// 训练计划
///
/// 一个计划包含多个训练日（比如 4 周 × 4 天/周 = 16 个训练日）。
/// 预置计划见 PresetPlans，AI 生成见 AiPlanService。
class TrainingPlan {
  /// 计划唯一标识
  final String id;

  /// 计划名称，比如「4周减脂塑形」
  final String name;

  /// 简短介绍
  final String description;

  /// 训练目标
  final TrainingGoal goal;

  /// 难度等级
  final TrainingLevel level;

  /// 训练类别：有氧 / 无氧 / 混合
  final TrainingCategory category;

  /// 计划总时长，单位周
  final int durationWeeks;

  /// 每周训练次数
  final int workoutsPerWeek;

  /// 这个计划包含的全部训练日
  final List<TrainingDay> days;

  /// 是否由 AI 生成（区别于预置计划）
  final bool isAiGenerated;

  const TrainingPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.goal,
    required this.level,
    required this.category,
    required this.durationWeeks,
    required this.workoutsPerWeek,
    required this.days,
    this.isAiGenerated = false,
  });

  /// 复制并替换部分字段
  ///
  /// 编辑计划时用。id 可以替换：把预置计划改成可编辑副本时需要换新 id
  TrainingPlan copyWith({
    String? id,
    String? name,
    String? description,
    TrainingGoal? goal,
    TrainingLevel? level,
    TrainingCategory? category,
    int? durationWeeks,
    int? workoutsPerWeek,
    List<TrainingDay>? days,
    bool? isAiGenerated,
  }) {
    return TrainingPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      category: category ?? this.category,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      days: days ?? this.days,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }

  /// 计划总共多少个训练日
  int get totalDays => days.length;

  /// 有氧训练日的数量
  int get aerobicDayCount =>
      days.where((d) => d.category == TrainingCategory.aerobic).length;

  /// 无氧训练日的数量
  int get anaerobicDayCount =>
      days.where((d) => d.category == TrainingCategory.anaerobic).length;

  /// 转成 Map，用于把 AI 生成的计划存到本地
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'goal': goal.index,
      'level': level.index,
      'category': category.index,
      'durationWeeks': durationWeeks,
      'workoutsPerWeek': workoutsPerWeek,
      'isAiGenerated': isAiGenerated,
      'days': days.map((d) => d.toMap()).toList(),
    };
  }

  /// 从 Map 还原
  factory TrainingPlan.fromMap(Map<dynamic, dynamic> map) {
    return TrainingPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      goal: _enumFromIndex(
        map['goal'] as int?,
        TrainingGoal.values,
        TrainingGoal.keepFit,
      ),
      level: _enumFromIndex(
        map['level'] as int?,
        TrainingLevel.values,
        TrainingLevel.intermediate,
      ),
      category: _enumFromIndex(
        map['category'] as int?,
        TrainingCategory.values,
        TrainingCategory.mixed,
      ),
      durationWeeks: map['durationWeeks'] as int? ?? 4,
      workoutsPerWeek: map['workoutsPerWeek'] as int? ?? 3,
      isAiGenerated: map['isAiGenerated'] as bool? ?? false,
      days: (map['days'] as List? ?? [])
          .map((d) => TrainingDay.fromMap(d as Map))
          .toList(),
    );
  }
}

/// 训练日
///
/// 一次训练包含多个动作，比如「胸肩日」包含卧推、推举、飞鸟等。
class TrainingDay {
  /// 训练日唯一标识
  final String id;

  /// 所属计划的 ID
  final String planId;

  /// 第几天（从 1 开始）
  final int dayNumber;

  /// 训练日名称，比如「胸肩日」「腿部力量」
  final String name;

  /// 这一天属于有氧还是无氧
  final TrainingCategory category;

  /// 这次训练的全部动作
  final List<Exercise> exercises;

  /// 预计总时长（分钟）
  ///
  /// 动作时间 + 组间休息 + 动作间休息的估算值
  final int estimatedMinutes;

  const TrainingDay({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.name,
    required this.category,
    required this.exercises,
    required this.estimatedMinutes,
  });

  /// 复制并替换部分字段
  ///
  /// 编辑训练日（改名、增删动作、调顺序）时用
  TrainingDay copyWith({
    String? planId,
    int? dayNumber,
    String? name,
    TrainingCategory? category,
    List<Exercise>? exercises,
    int? estimatedMinutes,
  }) {
    return TrainingDay(
      id: id,
      planId: planId ?? this.planId,
      dayNumber: dayNumber ?? this.dayNumber,
      name: name ?? this.name,
      category: category ?? this.category,
      exercises: exercises ?? this.exercises,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  /// 转成 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'dayNumber': dayNumber,
      'name': name,
      'category': category.index,
      'estimatedMinutes': estimatedMinutes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
    };
  }

  /// 从 Map 还原
  factory TrainingDay.fromMap(Map<dynamic, dynamic> map) {
    return TrainingDay(
      id: map['id'] as String,
      planId: map['planId'] as String? ?? '',
      dayNumber: map['dayNumber'] as int? ?? 1,
      name: map['name'] as String? ?? '训练日',
      category: _enumFromIndex(
        map['category'] as int?,
        TrainingCategory.values,
        TrainingCategory.mixed,
      ),
      estimatedMinutes: map['estimatedMinutes'] as int? ?? 30,
      exercises: (map['exercises'] as List? ?? [])
          .map((e) => Exercise.fromMap(e as Map))
          .toList(),
    );
  }
}

/// 训练动作
///
/// 一个具体的健身动作，比如「杠铃卧推 4组×10次」。
class Exercise {
  /// 动作唯一标识
  final String id;

  /// 动作名称
  final String name;

  /// 这个动作属于有氧还是无氧
  final TrainingCategory category;

  /// 目标组数
  final int sets;

  /// 目标次数（每组），-1 表示「做到力竭」
  final int reps;

  /// 计量单位是「次」还是「秒」
  ///
  /// 平板支撑、开合跳这类动作按时间算，举铁按次数算。
  /// 之前是靠备注写「次数改为秒数」，太容易被忽略，现在明确区分
  final bool isTimeBased;

  /// 组间休息时间（秒）
  final int restSeconds;

  /// 目标肌群，比如「胸肌」「股四头肌」
  final String muscleGroup;

  /// 需要的器械，null 表示徒手
  final String? equipment;

  /// 动作要点提示
  final String? tips;

  /// 建议重量（公斤），null 表示徒手或不限定
  ///
  /// 只是个起点参考，实际用多少在执行时记到 SetLog 里。
  /// 徒手动作和有氧动作留 null
  final double? targetWeightKg;

  /// 动作分解步骤
  ///
  /// 比 tips 更详细，按顺序描述怎么做。空列表表示没有分解说明，
  /// 界面上就只显示 tips
  final List<String> steps;

  /// 常见错误
  ///
  /// 新手最容易做错的地方，单独列出来比混在 tips 里显眼。
  /// 练错动作比不练更伤，这块值得单独占位置
  final List<String> mistakes;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.muscleGroup,
    this.isTimeBased = false,
    this.equipment,
    this.tips,
    this.targetWeightKg,
    this.steps = const [],
    this.mistakes = const [],
  });

  /// 有没有详细说明（分解步骤或常见错误）
  ///
  /// 决定界面上要不要显示「查看详解」入口
  bool get hasGuide => steps.isNotEmpty || mistakes.isNotEmpty;

  /// 目标描述，比如「4组 × 10次」或「3组 × 30秒」
  String get targetText {
    if (reps == -1) return '$sets组 × 力竭';
    return '$sets组 × $reps${isTimeBased ? '秒' : '次'}';
  }

  /// 复制并替换部分字段
  ///
  /// 编辑动作时用。可选字段（equipment/tips/targetWeightKg）用
  /// `clearXxx` 开关来区分「不改」和「改成 null」—— 不然没法把
  /// 建议重量清空
  Exercise copyWith({
    String? name,
    TrainingCategory? category,
    int? sets,
    int? reps,
    bool? isTimeBased,
    int? restSeconds,
    String? muscleGroup,
    String? equipment,
    String? tips,
    double? targetWeightKg,
    List<String>? steps,
    List<String>? mistakes,
    bool clearEquipment = false,
    bool clearTips = false,
    bool clearTargetWeight = false,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      isTimeBased: isTimeBased ?? this.isTimeBased,
      restSeconds: restSeconds ?? this.restSeconds,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: clearEquipment ? null : (equipment ?? this.equipment),
      tips: clearTips ? null : (tips ?? this.tips),
      targetWeightKg:
          clearTargetWeight ? null : (targetWeightKg ?? this.targetWeightKg),
      // 编辑动作时不能把详解丢了，所以默认继承原值
      steps: steps ?? this.steps,
      mistakes: mistakes ?? this.mistakes,
    );
  }

  /// 建议重量的显示文本，没有建议重量时返回 null
  ///
  /// 整数不显示小数点：20kg 比 20.0kg 干净
  String? get weightText {
    final w = targetWeightKg;
    if (w == null || w <= 0) return null;
    return w == w.roundToDouble() ? '${w.toInt()}kg' : '${w}kg';
  }

  /// 转成 Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category.index,
      'sets': sets,
      'reps': reps,
      'isTimeBased': isTimeBased,
      'restSeconds': restSeconds,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'tips': tips,
      'targetWeightKg': targetWeightKg,
      'steps': steps,
      'mistakes': mistakes,
    };
  }

  /// 从 Map 还原
  factory Exercise.fromMap(Map<dynamic, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String? ?? '动作',
      category: _enumFromIndex(
        map['category'] as int?,
        TrainingCategory.values,
        TrainingCategory.mixed,
      ),
      sets: map['sets'] as int? ?? 3,
      reps: map['reps'] as int? ?? 10,
      isTimeBased: map['isTimeBased'] as bool? ?? false,
      restSeconds: map['restSeconds'] as int? ?? 60,
      muscleGroup: map['muscleGroup'] as String? ?? '全身',
      equipment: map['equipment'] as String?,
      tips: map['tips'] as String?,
      // 旧记录没这个字段，读出来是 null 正好表示不限定重量。
      // 用 num 兜住：jsonDecode 会把 40.0 读成 int
      targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble(),
      // 旧记录没这两个字段，读不到就是空列表
      steps: (map['steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
      mistakes:
          (map['mistakes'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  /// 这个动作预计耗时（分钟）
  ///
  /// 粗略估算：假设每组做 30 秒，加上组间休息
  int get estimatedMinutes {
    final workTime = sets * 0.5; // 每组 30 秒
    final restTime = (sets - 1) * restSeconds / 60; // 组间休息
    return (workTime + restTime).ceil();
  }
}
