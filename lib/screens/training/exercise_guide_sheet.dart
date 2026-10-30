import 'package:flutter/material.dart';

import '../../models/training_plan.dart';

/// 弹出动作详解
///
/// 做成底部弹窗而不是新页面：训练中途想查一下，看完下滑关掉就继续，
/// 不打断当前流程
void showExerciseGuide(BuildContext context, Exercise exercise) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ExerciseGuideSheet(exercise: exercise),
  );
}

class _ExerciseGuideSheet extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseGuideSheet({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        // 最高占屏幕八成，内容多了内部滚动而不是顶满全屏
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 动作名
              Text(
                exercise.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              // 基本参数
              _buildMeta(),
              const SizedBox(height: 18),

              // 要点
              if (exercise.tips != null) ...[
                _buildTips(),
                const SizedBox(height: 18),
              ],

              // 分解步骤
              if (exercise.steps.isNotEmpty) ...[
                _sectionTitle(Icons.format_list_numbered, '动作分解'),
                const SizedBox(height: 10),
                ...exercise.steps.asMap().entries.map(
                      (e) => _buildStep(e.key + 1, e.value),
                    ),
                const SizedBox(height: 18),
              ],

              // 常见错误
              if (exercise.mistakes.isNotEmpty) ...[
                _sectionTitle(Icons.warning_amber, '常见错误', Colors.orange),
                const SizedBox(height: 10),
                ...exercise.mistakes.map(_buildMistake),
              ],

              // 两份详解都没有时给个说明，而不是留一片空白
              if (!exercise.hasGuide && exercise.tips == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      '这个动作还没有详细说明',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 参数行：组数次数、重量、休息、肌群、器械
  Widget _buildMeta() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _tag(Icons.repeat, exercise.targetText),
        if (exercise.weightText != null)
          _tag(Icons.fitness_center, exercise.weightText!),
        if (exercise.restSeconds > 0)
          _tag(Icons.timer_outlined, '休息 ${exercise.restSeconds}秒'),
        _tag(Icons.my_location, exercise.muscleGroup),
        if (exercise.equipment != null)
          _tag(Icons.sports_gymnastics, exercise.equipment!),
      ],
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  /// 要点提示框
  Widget _buildTips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 17, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exercise.tips!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text, [Color? color]) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color ?? Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  /// 带序号的步骤
  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              // 让文字和圆圈中心对齐
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 常见错误条目
  Widget _buildMistake(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.close, size: 15, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
