import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/preset_plans.dart';
import '../../models/training_plan.dart';
import '../../services/user_store.dart';

/// 训练日编辑页
///
/// 支持调组数／次数／重量／休息、删动作、拖动排序。
/// 改预置计划会存成一份副本（store.savePlan 里处理），原预置不动。
class DayEditPage extends StatefulWidget {
  /// 所属计划
  final TrainingPlan plan;

  /// 要编辑的训练日
  final TrainingDay day;

  const DayEditPage({
    super.key,
    required this.plan,
    required this.day,
  });

  @override
  State<DayEditPage> createState() => _DayEditPageState();
}

class _DayEditPageState extends State<DayEditPage> {
  /// 编辑中的动作列表，保存时才写回 store
  late List<Exercise> _exercises;

  /// 有没有改过，用来决定退出时是否提示
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    // 复制一份再改，取消时原数据不受影响
    _exercises = [...widget.day.exercises];
  }

  /// 保存回 store 并退出
  void _save() {
    final store = context.read<UserStore>();

    // 预估时长按动作数重算一下，不然删了一半动作还显示原来的时间
    final minutes = _estimateMinutes();

    final updatedDay = widget.day.copyWith(
      exercises: _exercises,
      estimatedMinutes: minutes,
    );

    final updatedDays = widget.plan.days
        .map((d) => d.id == updatedDay.id ? updatedDay : d)
        .toList();

    final saved = store.savePlan(widget.plan.copyWith(days: updatedDays));

    if (!mounted) return;

    // 预置计划存成了副本，告诉用户一声，否则会困惑为什么多了个计划
    final isCopy = saved.id != widget.plan.id;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isCopy ? '已另存为「${saved.name}」' : '已保存'),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context, saved);
  }

  /// 按动作的组数和休息时间粗算总时长（分钟）
  ///
  /// 每组按 45 秒估，加上组间休息。只是个参考值
  int _estimateMinutes() {
    var seconds = 0;
    for (final ex in _exercises) {
      // 按时间计的动作用 reps 当秒数，按次数的估 45 秒一组
      final perSet = ex.isTimeBased ? ex.reps : 45;
      seconds += ex.sets * perSet;
      // 最后一组后面不用休息
      seconds += (ex.sets - 1).clamp(0, 99) * ex.restSeconds;
    }
    // 向上取整到分钟，至少 1 分钟
    return (seconds / 60).ceil().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('放弃修改'),
            content: const Text('有未保存的修改，确定要退出吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('继续编辑'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('放弃', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (discard == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('编辑 ${widget.day.name}'),
          actions: [
            TextButton(
              // 没改过就禁用，避免白存一份副本；
              // 动作全删完也不能存，空训练日没法练
              onPressed: (_dirty && _exercises.isNotEmpty) ? _save : null,
              child: const Text('保存'),
            ),
          ],
        ),
        body: _exercises.isEmpty
            ? _buildEmpty()
            : Column(
                children: [
                  // 顶部提示：预置计划会另存。
                  // 判断要查 PresetPlans 而不是看 isAiGenerated ——
                  // 预置的副本存进来后 isAiGenerated 还是 false，
                  // 用那个判断会对已经是副本的计划继续显示提示
                  if (PresetPlans.getById(widget.plan.id) != null)
                    _buildPresetHint(),
                  Expanded(child: _buildList()),
                ],
              ),
      ),
    );
  }

  /// 预置计划的另存提示
  Widget _buildPresetHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '保存后会创建一份你的版本，原计划不受影响',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  /// 动作全删完了的空状态
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '这一天没有动作了',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '至少留一个动作才能保存',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// 可拖动排序的动作列表
  Widget _buildList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _exercises.length,
      onReorder: (from, to) {
        setState(() {
          // ReorderableListView 的 to 是移除前的下标，往后拖要减 1
          if (to > from) to -= 1;
          final item = _exercises.removeAt(from);
          _exercises.insert(to, item);
          _dirty = true;
        });
      },
      itemBuilder: (ctx, i) => _buildCard(_exercises[i], i),
    );
  }

  /// 单个动作卡
  Widget _buildCard(Exercise ex, int index) {
    return Card(
      // ReorderableListView 要求每项有稳定的 key
      key: ValueKey(ex.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 删除
                IconButton(
                  onPressed: () => _deleteAt(index),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.shade400,
                  tooltip: '删除这个动作',
                ),
                // 拖动手柄
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 四个可调参数
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: '组数',
                  value: '${ex.sets}',
                  onTap: () => _editNumber(
                    index: index,
                    title: '组数',
                    current: ex.sets.toDouble(),
                    min: 1,
                    max: 20,
                    isInt: true,
                    apply: (v) => ex.copyWith(sets: v.toInt()),
                  ),
                ),
                _chip(
                  label: ex.isTimeBased ? '秒数' : '次数',
                  value: ex.reps == -1 ? '力竭' : '${ex.reps}',
                  onTap: () => _editNumber(
                    index: index,
                    title: ex.isTimeBased ? '每组秒数' : '每组次数',
                    current: ex.reps == -1 ? 10 : ex.reps.toDouble(),
                    min: 1,
                    max: ex.isTimeBased ? 3600 : 100,
                    isInt: true,
                    apply: (v) => ex.copyWith(reps: v.toInt()),
                  ),
                ),
                _chip(
                  label: '休息',
                  value: '${ex.restSeconds}秒',
                  onTap: () => _editNumber(
                    index: index,
                    title: '组间休息（秒）',
                    current: ex.restSeconds.toDouble(),
                    min: 0,
                    max: 600,
                    isInt: true,
                    apply: (v) => ex.copyWith(restSeconds: v.toInt()),
                  ),
                ),
                _chip(
                  label: '重量',
                  value: ex.weightText ?? '徒手',
                  onTap: () => _editNumber(
                    index: index,
                    title: '建议重量（公斤，0 表示徒手）',
                    current: ex.targetWeightKg ?? 0,
                    min: 0,
                    max: 500,
                    isInt: false,
                    // 填 0 表示徒手，要真的清空而不是存成 0
                    apply: (v) => v <= 0
                        ? ex.copyWith(clearTargetWeight: true)
                        : ex.copyWith(targetWeightKg: v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 参数小按钮
  Widget _chip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.edit, size: 12, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  /// 删除一个动作
  void _deleteAt(int index) async {
    final ex = _exercises[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除动作'),
        content: Text('确定要从这一天移除「${ex.name}」吗？'),
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

    if (confirm != true) return;

    setState(() {
      _exercises.removeAt(index);
      _dirty = true;
    });
  }

  /// 弹出数字输入框改某个参数
  void _editNumber({
    required int index,
    required String title,
    required double current,
    required double min,
    required double max,
    required bool isInt,
    required Exercise Function(double) apply,
  }) async {
    final controller = TextEditingController(
      text: isInt ? current.toInt().toString() : _trimZero(current),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              isInt ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '${_trimZero(min)} ~ ${_trimZero(max)}',
          ),
          onSubmitted: (_) {
            final v = double.tryParse(controller.text.trim());
            if (v != null) Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    // 夹到合法范围，防止输入 999 组这种离谱值
    final clamped = result.clamp(min, max);

    setState(() {
      _exercises[index] = apply(clamped);
      _dirty = true;
    });
  }

  /// 去掉整数的小数尾巴：20.0 显示成 20
  String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
