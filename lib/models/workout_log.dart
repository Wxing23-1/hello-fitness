import 'package:hive/hive.dart';

/// 训练完成记录
///
/// 用户每完成一次训练就生成一条记录，存到 Hive 本地数据库。
/// Week 3-4 接 Firebase 后会同步到 Firestore。
///
/// Hive 注解：typeId 必须唯一，field 的编号也不能重复
@HiveType(typeId: 1)
class WorkoutLog {
  /// 记录唯一标识
  @HiveField(0)
  final String id;

  /// 完成的训练计划 ID
  @HiveField(1)
  final String planId;

  /// 完成的训练日 ID
  @HiveField(2)
  final String dayId;

  /// 完成时间
  @HiveField(3)
  final DateTime completedAt;

  /// 实际训练时长（分钟）
  @HiveField(4)
  final int durationMinutes;

  /// 每个动作的完成情况
  @HiveField(5)
  final List<ExerciseLog> exercises;

  /// 训练后的感受评分（1-5 星）
  @HiveField(6)
  final int? feeling;

  /// 备注
  @HiveField(7)
  final String? note;

  const WorkoutLog({
    required this.id,
    required this.planId,
    required this.dayId,
    required this.completedAt,
    required this.durationMinutes,
    required this.exercises,
    this.feeling,
    this.note,
  });

  /// 工厂方法：创建一条新记录
  ///
  /// ID 用时间戳生成，保证唯一性
  factory WorkoutLog.create({
    required String planId,
    required String dayId,
    required int durationMinutes,
    required List<ExerciseLog> exercises,
    int? feeling,
    String? note,
  }) {
    return WorkoutLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      planId: planId,
      dayId: dayId,
      completedAt: DateTime.now(),
      durationMinutes: durationMinutes,
      exercises: exercises,
      feeling: feeling,
      note: note,
    );
  }

  /// 序列化成 Map，用于持久化
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'dayId': dayId,
      'completedAt': completedAt.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'feeling': feeling,
      'note': note,
    };
  }

  /// 从 Map 反序列化
  factory WorkoutLog.fromMap(Map map) {
    return WorkoutLog(
      id: map['id'] as String? ?? '',
      planId: map['planId'] as String? ?? '',
      dayId: map['dayId'] as String? ?? '',
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        map['completedAt'] as int? ?? 0,
      ),
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      exercises: (map['exercises'] as List?)
              ?.map((e) => ExerciseLog.fromMap(e as Map))
              .toList() ??
          [],
      feeling: map['feeling'] as int?,
      note: map['note'] as String?,
    );
  }
}

/// 单个动作的完成记录
@HiveType(typeId: 2)
class ExerciseLog {
  /// 动作 ID
  @HiveField(0)
  final String exerciseId;

  /// 实际完成的组数
  @HiveField(1)
  final int completedSets;

  /// 每组的实际次数（长度等于 completedSets）
  @HiveField(2)
  final List<int> repsPerSet;

  /// 使用的重量（公斤），null 表示徒手
  @HiveField(3)
  final double? weight;

  const ExerciseLog({
    required this.exerciseId,
    required this.completedSets,
    required this.repsPerSet,
    this.weight,
  });

  /// 这个动作总共完成了多少次
  int get totalReps => repsPerSet.fold(0, (sum, r) => sum + r);

  /// 序列化成 Map
  Map<String, dynamic> toMap() {
    return {
      'exerciseId': exerciseId,
      'completedSets': completedSets,
      'repsPerSet': repsPerSet,
      'weight': weight,
    };
  }

  /// 从 Map 反序列化
  factory ExerciseLog.fromMap(Map map) {
    return ExerciseLog(
      exerciseId: map['exerciseId'] as String? ?? '',
      completedSets: map['completedSets'] as int? ?? 0,
      repsPerSet: (map['repsPerSet'] as List?)?.cast<int>() ?? [],
      weight: map['weight'] as double?,
    );
  }
}

/// 单组训练数据（训练执行时使用）
///
/// 不存 Hive，只在训练过程中用来跟踪每组的完成情况
class SetLog {
  /// 目标次数（计划里的值）
  final int targetReps;

  /// 实际完成次数（可以在训练时修改）
  int actualReps;

  /// 使用的重量（公斤），0 表示徒手
  double weight;

  /// 是否已完成
  bool completed;

  SetLog({
    required this.targetReps,
    required this.actualReps,
    required this.weight,
    this.completed = false,
  });
}
