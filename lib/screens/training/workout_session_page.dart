import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/session_draft.dart';
import '../../models/training_plan.dart';
import '../../models/workout_log.dart';
import '../../services/user_store.dart';
import 'exercise_guide_sheet.dart';
import 'session_summary_page.dart';

/// 训练执行页
///
/// 引导式逐组执行：全屏展示当前动作，完成一组后自动弹休息倒计时，
/// 倒完进下一组。可以修改实际次数和重量，最后保存成 WorkoutLog。
class WorkoutSessionPage extends StatefulWidget {
  /// 要执行的训练日
  final TrainingDay day;

  /// 所属计划（用来拿计划名和描述，记录时用）
  final TrainingPlan plan;

  /// 要恢复的草稿，null 表示从头开始练
  ///
  /// 由调用方（详情页／首页）决定是否恢复：那边弹确认框问过用户了
  final SessionDraft? resumeFrom;

  const WorkoutSessionPage({
    super.key,
    required this.day,
    required this.plan,
    this.resumeFrom,
  });

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  /// 当前执行到第几个动作（从 0 开始）
  int _currentExerciseIndex = 0;

  /// 当前动作执行到第几组（从 0 开始）
  int _currentSetIndex = 0;

  /// 每个动作实际完成的组数据
  ///
  /// 外层 List 对应 day.exercises，内层 List 是各组的实际数据。
  /// 初始化时复制计划的目标值，执行时可以修改。
  late List<List<SetLog>> _completedSets;

  /// 训练开始时间
  late DateTime _startTime;

  /// 是否正在休息
  bool _isResting = false;

  @override
  void initState() {
    super.initState();

    final draft = widget.resumeFrom;

    // 为每个动作创建初始的 SetLog，用计划里的目标值填充
    _completedSets = widget.day.exercises.map((ex) {
      return List.generate(
        ex.sets,
        (i) => SetLog(
          // 如果动作是基于时间的（平板支撑），用秒数；否则用次数
          targetReps: ex.reps,
          actualReps: ex.reps,
          // 用计划里的建议重量预填，省得每组手动输。
          // 没建议重量（徒手／有氧）就是 0，执行时可改
          weight: ex.targetWeightKg ?? 0,
          completed: false,
        ),
      );
    }).toList();

    if (draft == null) {
      _startTime = DateTime.now();
      return;
    }

    // 恢复草稿：沿用原来的开始时间，这样总时长包含中断前练的部分
    _startTime = draft.startTime;

    // 逐组覆盖而不是整体替换 _completedSets：
    // 计划可能在中断期间被改过（动作增删、组数调整），
    // 直接替换会让数组长度和当前计划不匹配，后面索引就越界了
    for (var i = 0; i < _completedSets.length; i++) {
      if (i >= draft.completedSets.length) break;

      final saved = draft.completedSets[i];
      for (var j = 0; j < _completedSets[i].length; j++) {
        if (j >= saved.length) break;

        _completedSets[i][j]
          ..actualReps = saved[j].actualReps
          ..weight = saved[j].weight
          ..completed = saved[j].completed;
      }
    }

    // 位置也要防越界 —— 同样是怕计划改小了
    _currentExerciseIndex =
        draft.exerciseIndex.clamp(0, widget.day.exercises.length - 1);
    _currentSetIndex = draft.setIndex
        .clamp(0, widget.day.exercises[_currentExerciseIndex].sets - 1);
  }

  /// 把当前进度写进草稿
  ///
  /// 每完成一组调一次，所以最多只会丢当前这一组
  void _saveDraft() {
    context.read<UserStore>().saveDraft(
          SessionDraft(
            planId: widget.plan.id,
            dayId: widget.day.id,
            startTime: _startTime,
            savedAt: DateTime.now(),
            exerciseIndex: _currentExerciseIndex,
            setIndex: _currentSetIndex,
            completedSets: _completedSets,
          ),
        );
  }

  /// 当前正在执行的动作
  Exercise get _currentExercise =>
      widget.day.exercises[_currentExerciseIndex];

  /// 当前组的数据
  SetLog get _currentSet =>
      _completedSets[_currentExerciseIndex][_currentSetIndex];

  /// 还剩几组（包括当前这组）
  int get _remainingSets =>
      _currentExercise.sets - _currentSetIndex;

  /// 已完成的总组数，退出确认框里用
  int get _completedSetCount {
    var n = 0;
    for (final sets in _completedSets) {
      for (final s in sets) {
        if (s.completed) n++;
      }
    }
    return n;
  }

  /// 标记当前组完成，弹休息倒计时
  void _completeSet() {
    setState(() {
      _currentSet.completed = true;
    });

    // 每完成一组落盘一次，中断最多只丢这一组
    _saveDraft();

    // 是不是当前动作的最后一组
    final isLastSetOfExercise = _currentSetIndex == _currentExercise.sets - 1;

    if (isLastSetOfExercise) {
      // 最后一组，直接进下一个动作，不用休息
      _goNextExercise();
    } else {
      // 还有下一组，弹休息倒计时
      _startRest();
    }
  }

  /// 弹出休息倒计时
  void _startRest() {
    setState(() => _isResting = true);

    showModalBottomSheet(
      context: context,
      isDismissible: false, // 不能点外面关掉，必须等倒计时完或手动跳过
      enableDrag: false,
      builder: (ctx) => _RestTimer(
        duration: _currentExercise.restSeconds,
        onComplete: () {
          Navigator.pop(ctx);
          _goNextSet();
        },
        onSkip: () {
          Navigator.pop(ctx);
          _goNextSet();
        },
      ),
    ).then((_) {
      // BottomSheet 关闭后
      if (mounted) setState(() => _isResting = false);
    });
  }

  /// 进入下一组
  void _goNextSet() {
    setState(() {
      _currentSetIndex++;
    });
  }

  /// 进入下一个动作
  void _goNextExercise() {
    // 是不是最后一个动作
    if (_currentExerciseIndex == widget.day.exercises.length - 1) {
      // 全部完成，跳到总结页
      _finish();
    } else {
      // 还有下一个动作
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0; // 新动作从第一组开始
      });
    }
  }

  /// 完成训练，跳到总结页
  void _finish() {
    final duration = DateTime.now().difference(_startTime);

    // 练完了，草稿没用了。不清掉下次进来还会提示恢复一场已完成的训练
    context.read<UserStore>().clearDraft();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(
          plan: widget.plan,
          day: widget.day,
          completedSets: _completedSets,
          duration: duration,
          startTime: _startTime,
        ),
      ),
    );
  }

  /// 修改当前组的实际次数
  void _editReps() async {
    final controller = TextEditingController(
      text: _currentSet.actualReps.toString(),
    );

    final newReps = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('实际完成次数'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            suffix: Text('次'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newReps != null && newReps > 0) {
      setState(() => _currentSet.actualReps = newReps);
    }
  }

  /// 修改当前组的重量
  void _editWeight() async {
    final controller = TextEditingController(
      text: _currentSet.weight.toString(),
    );

    final newWeight = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('实际使用重量'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            suffix: Text('kg'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              Navigator.pop(ctx, val);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (newWeight != null && newWeight >= 0) {
      setState(() => _currentSet.weight = newWeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: false 拦住返回手势，改由 onPopInvoked 里弹确认框决定去留
      // 这是 WillPopScope 的替代写法（Flutter 3.12 后推荐）
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        // didPop 为 true 说明已经弹出了，不用再处理
        if (didPop) return;

        // 三个选项：继续练 / 存着下次接 / 直接丢弃
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('退出训练'),
            content: Text(
              _completedSetCount > 0
                  ? '已完成 $_completedSetCount 组。保存进度后，下次可以接着练。'
                  : '还没有完成任何一组，退出不会留下记录。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'stay'),
                child: const Text('继续训练'),
              ),
              // 一组都没练就没什么可存的，不显示这个选项
              if (_completedSetCount > 0)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'save'),
                  child: const Text('保存并退出'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'discard'),
                child: const Text(
                  '放弃',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (choice == null || choice == 'stay' || !context.mounted) return;

        if (choice == 'save') {
          _saveDraft();
        } else {
          // 放弃就清掉草稿，不然下次还会提示恢复这场已经被放弃的训练
          context.read<UserStore>().clearDraft();
        }

        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.day.name),
          // 右上角显示进度：第几个动作 / 总共几个
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentExerciseIndex + 1}/${widget.day.exercises.length}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
        body: _isResting
            ? const Center(child: Text('休息中...'))
            : _buildExerciseView(),
      ),
    );
  }

  /// 当前动作的执行视图
  Widget _buildExerciseView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── 动作名称 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _currentExercise.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // 训练中途最需要查动作怎么做，放在名字旁边
              IconButton(
                onPressed: () =>
                    showExerciseGuide(context, _currentExercise),
                icon: const Icon(Icons.help_outline),
                color: Colors.blue.shade600,
                tooltip: '动作详解',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── 第几组 / 总共几组 ──
          Text(
            '第 ${_currentSetIndex + 1} 组 / 共 ${_currentExercise.sets} 组',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 24),

          // ── 目标值（只读展示）──
          _buildInfoCard(),

          const SizedBox(height: 20),

          // ── 修改实际值的按钮 ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editReps,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('改次数'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editWeight,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('改重量'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── 完成按钮 ──
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _completeSet,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(_remainingSets == 1 ? '完成，下一个动作' : '完成本组'),
            ),
          ),

          const SizedBox(height: 12),

          // ── 跳过当前动作（紧急情况用）──
          TextButton(
            onPressed: _goNextExercise,
            child: const Text('跳过这个动作'),
          ),
        ],
      ),
    );
  }

  /// 展示当前组的目标和实际值
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          // ── 次数 ──
          _infoRow(
            icon: Icons.repeat,
            label: '次数',
            target: '${_currentSet.targetReps}',
            actual: '${_currentSet.actualReps}',
          ),
          const Divider(height: 24),

          // ── 重量 ──
          _infoRow(
            icon: Icons.fitness_center,
            label: '重量',
            target: _currentSet.weight == 0
                ? '徒手'
                : '${_currentSet.weight} kg',
            actual: _currentSet.weight == 0
                ? '徒手'
                : '${_currentSet.weight} kg',
          ),
        ],
      ),
    );
  }

  /// 一行信息：图标 + 标签 + 目标值 + 实际值
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String target,
    required String actual,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '目标: $target',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              '实际: $actual',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 休息倒计时 BottomSheet
///
/// 环形进度 + 剩余秒数，可以提前跳过
class _RestTimer extends StatefulWidget {
  /// 休息时长（秒）
  final int duration;

  /// 倒计时完成回调
  final VoidCallback onComplete;

  /// 跳过休息回调
  final VoidCallback onSkip;

  const _RestTimer({
    required this.duration,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<_RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<_RestTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    );

    // 每秒更新一次剩余秒数
    _controller.addListener(() {
      final newRemaining =
          (widget.duration * (1 - _controller.value)).ceil();
      if (newRemaining != _remaining) {
        setState(() => _remaining = newRemaining);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '休息中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // ── 环形进度 + 剩余秒数 ──
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 环形进度
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.blue.shade600,
                      ),
                    );
                  },
                ),
                // 剩余秒数
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 跳过按钮 ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onSkip,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('跳过休息'),
            ),
          ),
        ],
      ),
    );
  }
}
