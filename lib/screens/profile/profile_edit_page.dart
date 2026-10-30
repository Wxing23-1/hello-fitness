import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';

/// 个人资料管理页
///
/// 带校验的编辑表单。有状态组件，因为要持有输入框控制器
/// 和用户还没保存的临时选择（性别）。
///
/// 交互设计：改动不会实时生效，必须点「保存」才写回 store。
/// 中途想放弃就直接返回，这样误操作不会污染数据。
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  /// 表单的全局key，用来触发校验和读取校验结果
  final _formKey = GlobalKey<FormState>();

  // 四个文本输入框的控制器
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _bioController;

  /// 当前选中的性别（还没保存的临时值）
  late Gender _gender;

  @override
  void initState() {
    super.initState();

    // 用 store 里的现有资料填充表单初始值
    // 这里用 read 而不是 watch：initState 阶段组件还没挂载完，
    // 不能订阅；而且初始值只需要读一次
    final profile = context.read<UserStore>().profile;

    _nameController = TextEditingController(text: profile.name);
    _ageController = TextEditingController(text: profile.age.toString());
    // 身高体重去掉多余小数：175.0 显示成 175
    _heightController = TextEditingController(
      text: profile.heightCm.toStringAsFixed(0),
    );
    _weightController = TextEditingController(
      text: profile.weightKg.toStringAsFixed(1),
    );
    _bioController = TextEditingController(text: profile.bio);
    _gender = profile.gender;
  }

  @override
  void dispose() {
    // 所有控制器都要释放，否则内存泄漏
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// 保存资料
  void _save() {
    // 先跑一遍所有输入框的 validator，有任何一项不合法就返回 false
    if (!_formKey.currentState!.validate()) {
      return; // 校验不通过，错误提示会自动显示在对应输入框下方
    }

    // 校验已通过，这里的 parse 不会抛异常
    context.read<UserStore>().updateProfile(
          name: _nameController.text.trim(), // trim 去掉首尾空格
          gender: _gender,
          age: int.parse(_ageController.text),
          heightCm: double.parse(_heightController.text),
          weightKg: double.parse(_weightController.text),
          bio: _bioController.text.trim(),
        );

    // 弹一个底部提示条告诉用户保存成功
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('资料已保存'),
        duration: Duration(seconds: 2),
      ),
    );

    // 返回上一页
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('个人资料管理'),
        actions: [
          // 右上角保存按钮
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      // Form 包住所有输入框，才能用 _formKey 统一校验
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头像（点击换头像要等 Week 8 的 image_picker，先占位）
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 48, color: Colors.white),
                  ),
                  // 右下角的小相机图标，暗示这里可以改头像
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '头像上传功能在 Week 8 实现',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 24),

            // ── 昵称 ──
            TextFormField(
              controller: _nameController,
              maxLength: 12, // 限制长度，右下角会自动显示字数计数器
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              // validator 返回 null 表示通过，返回字符串表示错误提示
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '昵称不能为空';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── 性别（分段按钮，比下拉菜单更直观）──
            const Text('性别', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            SegmentedButton<Gender>(
              // 当前选中项，SegmentedButton 支持多选所以要传集合
              selected: {_gender},
              segments: Gender.values.map((g) {
                return ButtonSegment<Gender>(
                  value: g,
                  label: Text(g.label),
                  icon: Icon(g == Gender.male ? Icons.male : Icons.female),
                );
              }).toList(),
              onSelectionChanged: (selected) {
                setState(() {
                  _gender = selected.first; // 单选模式下集合里只有一个元素
                });
              },
            ),
            const SizedBox(height: 20),

            // ── 年龄 ──
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '年龄',
                suffixText: '岁', // 右侧单位
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.cake),
              ),
              validator: (value) {
                final age = int.tryParse(value ?? '');
                if (age == null) return '请输入数字';
                // 范围检查：太离谱的数值挡掉
                if (age < 10 || age > 100) return '年龄应在 10-100 之间';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── 身高 ──
            TextFormField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '身高',
                suffixText: 'cm',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.height),
              ),
              // onChanged 让下方的BMI预览实时更新
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final h = double.tryParse(value ?? '');
                if (h == null) return '请输入数字';
                if (h < 100 || h > 250) return '身高应在 100-250cm 之间';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── 体重 ──
            TextFormField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '体重',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monitor_weight),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final w = double.tryParse(value ?? '');
                if (w == null) return '请输入数字';
                if (w < 30 || w > 300) return '体重应在 30-300kg 之间';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── BMI 实时预览 ──
            // 改身高体重时立刻能看到BMI变化，不用保存后再回去看
            _buildBmiPreview(),
            const SizedBox(height: 16),

            // ── 个人简介 ──
            TextFormField(
              controller: _bioController,
              maxLines: 3, // 多行输入框
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '个人简介',
                alignLabelWithHint: true, // 多行时标签对齐到顶部而不是居中
                border: OutlineInputBorder(),
              ),
              // 简介允许为空，所以不需要 validator
            ),
            const SizedBox(height: 24),

            // 底部保存按钮（和右上角功能相同，方便长表单滑到底直接点）
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('保存资料', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  /// BMI实时预览条
  Widget _buildBmiPreview() {
    // 读取当前输入框里的值（可能还没保存）
    final h = double.tryParse(_heightController.text) ?? 0;
    final w = double.tryParse(_weightController.text) ?? 0;
    final bmi = calculateBmi(h, w);
    final level = bmiLevelOf(bmi);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.analytics, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 10),
          const Text('当前 BMI', style: TextStyle(fontSize: 14)),
          const Spacer(), // 把后面的内容推到最右边
          Text(
            bmi > 0 ? bmi.toStringAsFixed(1) : '--',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: bmi > 0 ? level.color : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          // 状态标签
          if (bmi > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                level.label,
                style: TextStyle(
                  fontSize: 12,
                  color: level.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
