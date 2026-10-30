import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fitness_goal.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';

/// 目标设置调整页
///
/// 用滑块调数值，比让用户敲键盘输入体验好，也不用做输入校验
/// （滑块的 min/max 天然限制了范围，不可能出现非法值）。
///
/// 同样是「改完要点保存才生效」。
class GoalSettingPage extends StatefulWidget {
  const GoalSettingPage({super.key});

  @override
  State<GoalSettingPage> createState() => _GoalSettingPageState();
}

class _GoalSettingPageState extends State<GoalSettingPage> {
  // 页面内的临时值，保存时才一次性写回 store
  late GoalType _type;
  late double _targetWeight;
  late int _weeklyWorkouts;
  late int _dailyCalories;
  late int _dailyWaterMl;

  @override
  void initState() {
    super.initState();

    // 用 store 里的现有目标初始化
    final goal = context.read<UserStore>().goal;
    _type = goal.type;
    _targetWeight = goal.targetWeightKg;
    _weeklyWorkouts = goal.weeklyWorkouts;
    _dailyCalories = goal.dailyCalories;
    _dailyWaterMl = goal.dailyWaterMl;
  }

  /// 保存目标
  void _save() {
    context.read<UserStore>().updateGoal(
          type: _type,
          targetWeightKg: _targetWeight,
          weeklyWorkouts: _weeklyWorkouts,
          dailyCalories: _dailyCalories,
          dailyWaterMl: _dailyWaterMl,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('目标已更新'), duration: Duration(seconds: 2)),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 需要当前身高体重来给建议，所以要读 profile
    final profile = context.read<UserStore>().profile;
    // 算出健康体重区间，用来提示目标体重定得合不合理
    final (minW, maxW) = healthyWeightRange(profile.heightCm);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('目标设置调整'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ══ 目标类型 ══
          _sectionTitle('健身目标'),
          // 三个目标类型做成可点击的卡片，比单选框更好点
          ...GoalType.values.map((type) {
            final selected = type == _type;
            return Card(
              // 选中项用蓝色边框高亮
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: selected ? Colors.blue : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              elevation: 0, // 去掉阴影，用边框区分
              child: ListTile(
                title: Text(
                  type.label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  type.description,
                  style: const TextStyle(fontSize: 12),
                ),
                // 选中显示勾，未选中显示空心圈
                trailing: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? Colors.blue : Colors.grey.shade400,
                ),
                onTap: () => setState(() => _type = type),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ══ 目标体重 ══
          _sectionTitle('目标体重'),
          _buildSliderCard(
            icon: Icons.monitor_weight,
            iconColor: Colors.blue,
            label: '目标体重',
            // 显示目标值，以及和当前体重的差距
            valueText: '${_targetWeight.toStringAsFixed(1)} kg',
            // 副标题说明还要减/增多少
            hint: _weightHint(profile.weightKg),
            slider: Slider(
              value: _targetWeight,
              min: 40,
              max: 120,
              // divisions 把滑块切成固定档位，这里每档0.5kg
              divisions: (120 - 40) * 2,
              label: '${_targetWeight.toStringAsFixed(1)}kg', // 拖动时气泡显示
              onChanged: (v) => setState(() => _targetWeight = v),
            ),
          ),
          // 健康区间提示
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 14, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '身高 ${profile.heightCm.toStringAsFixed(0)}cm 的健康体重约为 '
                    '${minW.toStringAsFixed(1)} - ${maxW.toStringAsFixed(1)}kg',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ══ 每周训练次数 ══
          _sectionTitle('训练频率'),
          _buildSliderCard(
            icon: Icons.event_repeat,
            iconColor: Colors.green,
            label: '每周训练',
            valueText: '$_weeklyWorkouts 次',
            hint: _frequencyHint(),
            slider: Slider(
              // Slider 只接受 double，int 要转一下
              value: _weeklyWorkouts.toDouble(),
              min: 1,
              max: 7,
              divisions: 6, // 1到7共7档，所以是6个间隔
              label: '$_weeklyWorkouts次',
              onChanged: (v) => setState(() => _weeklyWorkouts = v.round()),
            ),
          ),

          const SizedBox(height: 16),

          // ══ 每日卡路里 ══
          _sectionTitle('饮食目标'),
          _buildSliderCard(
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
            label: '每日摄入',
            valueText: '$_dailyCalories 千卡',
            hint: '成年人日常推荐 1600-2400 千卡，减脂期可适当下调',
            slider: Slider(
              value: _dailyCalories.toDouble(),
              min: 1200,
              max: 3000,
              divisions: 36, // 每档50千卡
              label: '$_dailyCalories千卡',
              onChanged: (v) => setState(() => _dailyCalories = v.round()),
            ),
          ),

          const SizedBox(height: 16),

          // ══ 每日饮水 ══
          _buildSliderCard(
            icon: Icons.water_drop,
            iconColor: Colors.lightBlue,
            label: '每日饮水',
            // 毫升换算成升显示，2000ml 显示成 2.0L 更好读
            valueText: '${(_dailyWaterMl / 1000).toStringAsFixed(1)} L',
            hint: '一般建议每天 1500-2500ml，运动日可以再多一些',
            slider: Slider(
              value: _dailyWaterMl.toDouble(),
              min: 1000,
              max: 4000,
              divisions: 12, // 每档250ml
              label: '${_dailyWaterMl}ml',
              onChanged: (v) => setState(() => _dailyWaterMl = v.round()),
            ),
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('保存目标', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 根据当前体重和目标体重，生成「还要减X公斤」这样的提示
  String _weightHint(double currentWeight) {
    final gap = _targetWeight - currentWeight;

    // 差距小于0.5kg当作已达成（滑块精度是0.5）
    if (gap.abs() < 0.5) return '已达到目标体重';

    if (gap < 0) {
      return '当前 ${currentWeight.toStringAsFixed(1)}kg，还需减 ${(-gap).toStringAsFixed(1)}kg';
    }
    return '当前 ${currentWeight.toStringAsFixed(1)}kg，还需增 ${gap.toStringAsFixed(1)}kg';
  }

  /// 根据训练频率给出强度评价
  String _frequencyHint() {
    if (_weeklyWorkouts <= 2) return '强度偏低，适合刚开始养成习惯';
    if (_weeklyWorkouts <= 4) return '强度适中，大多数人能长期坚持';
    if (_weeklyWorkouts <= 6) return '强度较高，注意安排休息日';
    return '每天都练，务必留意身体恢复情况';
  }

  /// 小节标题
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  /// 带滑块的设置卡片
  ///
  /// 上面一行是图标+名称+当前值，中间是滑块，底部是说明文字
  Widget _buildSliderCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String valueText,
    required String hint,
    required Slider slider,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                valueText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          // 滑块左右有默认内边距，这里用负边距抵消一点，让它和图标对齐
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: slider,
          ),
          Text(
            hint,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
