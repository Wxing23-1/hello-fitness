import 'workout_log.dart';

/// 训练中断草稿
///
/// 练到一半退出（手误关页面、web 端刷新、来电打断）时保存现场，
/// 下次进来可以接着练。每完成一组写一次，所以最多只丢当前这一组。
///
/// 不用 Hive 注解：草稿是临时数据，用 JSON 存一个 key 就够了，
/// 不值得为它再加一个 typeId 和 adapter。
class SessionDraft {
  /// 所属计划 id
  final String planId;

  /// 所属训练日 id
  final String dayId;

  /// 训练开始时间（恢复后继续累计时长用）
  final DateTime startTime;

  /// 草稿最后一次更新的时间，用来判断是否过期
  final DateTime savedAt;

  /// 当前执行到第几个动作
  final int exerciseIndex;

  /// 当前动作执行到第几组
  final int setIndex;

  /// 已经记录的组数据
  ///
  /// 外层对应训练日的动作列表，内层是各组的实际数据
  final List<List<SetLog>> completedSets;

  const SessionDraft({
    required this.planId,
    required this.dayId,
    required this.startTime,
    required this.savedAt,
    required this.exerciseIndex,
    required this.setIndex,
    required this.completedSets,
  });

  /// 草稿是否已过期
  ///
  /// 超过 12 小时的草稿不再提示恢复 —— 隔天醒来接着练昨天的半场
  /// 没有意义，时长统计也会离谱（会把睡觉的时间算进去）
  bool get isExpired =>
      DateTime.now().difference(savedAt).inHours >= 12;

  /// 已完成的总组数，用来给用户显示「上次练到第几组」
  int get completedSetCount {
    var n = 0;
    for (final sets in completedSets) {
      for (final s in sets) {
        if (s.completed) n++;
      }
    }
    return n;
  }

  Map<String, dynamic> toMap() {
    return {
      'planId': planId,
      'dayId': dayId,
      'startTime': startTime.millisecondsSinceEpoch,
      'savedAt': savedAt.millisecondsSinceEpoch,
      'exerciseIndex': exerciseIndex,
      'setIndex': setIndex,
      // SetLog 本身不带序列化（原来只在内存里用），这里手动展开
      'completedSets': completedSets
          .map((sets) => sets
              .map((s) => {
                    'targetReps': s.targetReps,
                    'actualReps': s.actualReps,
                    'weight': s.weight,
                    'completed': s.completed,
                  })
              .toList())
          .toList(),
    };
  }

  factory SessionDraft.fromMap(Map map) {
    return SessionDraft(
      planId: map['planId'] as String? ?? '',
      dayId: map['dayId'] as String? ?? '',
      startTime: DateTime.fromMillisecondsSinceEpoch(
        map['startTime'] as int? ?? 0,
      ),
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        map['savedAt'] as int? ?? 0,
      ),
      exerciseIndex: map['exerciseIndex'] as int? ?? 0,
      setIndex: map['setIndex'] as int? ?? 0,
      completedSets: (map['completedSets'] as List?)
              ?.map((sets) => (sets as List)
                  .map((s) => SetLog(
                        targetReps: (s as Map)['targetReps'] as int? ?? 0,
                        actualReps: s['actualReps'] as int? ?? 0,
                        // 旧数据可能把 weight 存成 int，用 num 兜住
                        weight: (s['weight'] as num?)?.toDouble() ?? 0,
                        completed: s['completed'] as bool? ?? false,
                      ))
                  .toList())
              .toList() ??
          [],
    );
  }
}
