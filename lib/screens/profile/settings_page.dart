import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import '../../services/auth_service.dart';

/// 系统设置中心
///
/// 分4组：通用、提醒、数据、关于。
/// 这一页的开关改完立刻生效（不像资料和目标页需要点保存），
/// 因为开关类设置用户期望的就是「点一下马上变」。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('系统设置'),
      ),
      body: ListView(
        children: [
          // ══════════ 通用 ══════════
          _groupTitle('通用'),

          // 深色模式开关
          _switchTile(
            icon: Icons.dark_mode,
            iconColor: Colors.indigo,
            title: '深色模式',
            subtitle: '切换后整个APP的配色会跟着变',
            value: store.darkMode,
            onChanged: store.setDarkMode,
          ),

          // 单位制选择
          _navTile(
            icon: Icons.straighten,
            iconColor: Colors.teal,
            title: '单位制',
            // 右侧显示当前值
            trailingText: store.unitSystem,
            onTap: () => _showUnitPicker(context, store),
          ),

          // ══════════ AI 配置 ══════════
          _groupTitle('AI 配置'),

          _navTile(
            icon: Icons.auto_awesome,
            iconColor: Colors.purple,
            title: 'DeepSeek API Key',
            // 已配置就显示「已配置」，没配置提示去填
            trailingText: store.hasApiKey ? '已配置' : '未配置',
            onTap: () => _showApiKeyDialog(context, store),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI 定制训练计划需要 Key。到 platform.deepseek.com '
                    '注册获取，国内直连不用代理',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),

          // ══════════ 提醒 ══════════
          _groupTitle('提醒'),

          _switchTile(
            icon: Icons.notifications_active,
            iconColor: Colors.orange,
            title: '训练提醒',
            subtitle: '到了计划训练的时间推送通知',
            value: store.workoutReminder,
            onChanged: store.setWorkoutReminder,
          ),

          _switchTile(
            icon: Icons.water_drop,
            iconColor: Colors.lightBlue,
            title: '喝水提醒',
            subtitle: '每隔两小时提醒补水',
            value: store.waterReminder,
            onChanged: store.setWaterReminder,
          ),

          // 提醒功能需要本地通知插件，还没集成，这里说明一下
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '开关状态已保存，实际推送需要集成本地通知插件',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),

          // ══════════ 数据 ══════════
          _groupTitle('数据'),

          // 显示当前数据量，让用户清楚要清的是什么
          _navTile(
            icon: Icons.delete_sweep,
            iconColor: Colors.deepOrange,
            title: '清除训练记录',
            trailingText: '${store.totalWorkouts} 条',
            onTap: () => _confirmClearRecords(context, store),
          ),

          _navTile(
            icon: Icons.restore,
            iconColor: Colors.brown,
            title: '恢复默认数据',
            trailingText: '',
            onTap: () => _confirmReset(context, store),
          ),

          // ══════════ 关于 ══════════
          _groupTitle('关于'),

          _navTile(
            icon: Icons.info,
            iconColor: Colors.blueGrey,
            title: '关于本应用',
            trailingText: 'v1.0.0',
            onTap: () => _showAbout(context),
          ),

          const SizedBox(height: 24),

          // 退出登录：已登录时真正登出，未登录时提示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () => _handleSignOut(context, store),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('退出登录'),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  可复用的小组件
  // ═══════════════════════════════════════════════════

  /// 退出登录：确认后调 AuthService.signOut()，AuthGate 监听到状态变化会切回登录页
  Future<void> _handleSignOut(BuildContext context, UserStore store) async {
    if (!store.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前未登录'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后本地数据仍会保留，登录后可再次同步。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService.signOut();
    }
  }

  /// 分组标题
  Widget _groupTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  /// 带开关的设置项
  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged, // 就是 void Function(bool)
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: SwitchListTile(
        secondary: _tileIcon(icon, iconColor),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  /// 可点击跳转的设置项
  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: _tileIcon(icon, iconColor),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        // 右侧：当前值 + 箭头
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // 宽度只占内容需要的大小
          children: [
            if (trailingText.isNotEmpty)
              Text(
                trailingText,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  /// 设置项左侧的彩色圆角图标
  Widget _tileIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // ═══════════════════════════════════════════════════
  //  各种对话框
  // ═══════════════════════════════════════════════════

  /// API Key 配置对话框
  void _showApiKeyDialog(BuildContext context, UserStore store) {
    showDialog(
      context: context,
      builder: (_) => const _ApiKeyDialog(),
    );
  }

  /// 单位制选择面板
  void _showUnitPicker(BuildContext context, UserStore store) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text(
              '选择单位制',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // 两个选项：公制和英制
            ...['公制', '英制'].map((unit) {
              final selected = store.unitSystem == unit;
              return ListTile(
                title: Text(unit),
                subtitle: Text(
                  unit == '公制' ? '千克 / 厘米' : '磅 / 英寸',
                  style: const TextStyle(fontSize: 12),
                ),
                // 选中项右侧打勾
                trailing: selected
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  store.setUnitSystem(unit);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 清除训练记录确认框
  void _confirmClearRecords(BuildContext context, UserStore store) {
    // 本来就没记录，没必要弹框
    if (store.totalWorkouts == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前没有训练记录'), duration: Duration(seconds: 2)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除训练记录'),
        content: Text(
          '将删除全部 ${store.totalWorkouts} 条训练记录，此操作无法撤销。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              store.clearAllRecords();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('训练记录已清除'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('确定清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 恢复默认数据确认框
  void _confirmReset(BuildContext context, UserStore store) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认数据'),
        content: const Text(
          '个人资料、健身目标、训练记录、收藏课程和所有设置都会回到初始状态。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              store.resetAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已恢复默认数据'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('确定恢复', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 关于对话框（内容在文件底部的 _ApiKeyDialog 之后）
  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于本应用'),
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('健身助手', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('版本 1.0.0', style: TextStyle(fontSize: 13)),
            SizedBox(height: 12),
            Text(
              '基于 Flutter 开发的健身管理应用，包含训练计划、'
              'AI 食物识别、数据可视化等功能。',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              '当前进度：个人中心、训练中心已完成',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

/// DeepSeek API Key 配置对话框
///
/// 独立的有状态组件：要管理输入框内容和「是否明文显示」的切换状态
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog();

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _controller;

  /// 是否明文显示 Key，默认隐藏
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    // 用已保存的 key 填充，方便用户查看或修改
    _controller = TextEditingController(
      text: context.read<UserStore>().aiApiKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('DeepSeek API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            // obscureText 把输入内容显示成圆点，防止旁人看到
            obscureText: !_visible,
            decoration: InputDecoration(
              hintText: 'sk-...',
              border: const OutlineInputBorder(),
              isDense: true,
              // 右侧眼睛图标切换明文/隐藏
              suffixIcon: IconButton(
                icon: Icon(
                  _visible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '怎么获取：',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '1. 打开 platform.deepseek.com\n'
                  '2. 用手机号或邮箱注册登录\n'
                  '3. 左边菜单「API keys」→ 创建\n'
                  '4. 复制那串 sk- 开头的字符粘贴到上面\n\n'
                  '国内直连，不需要代理。\n'
                  '按用量计费，生成一份计划约几分钱。',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade900,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 安全提示：Key 存在本地明文，告知用户
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Key 只保存在你的设备上，不会上传到任何服务器',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // 已经配置过才显示清除按钮
        if (context.read<UserStore>().hasApiKey)
          TextButton(
            onPressed: () {
              context.read<UserStore>().setAiApiKey('');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清除 API Key'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            context.read<UserStore>().setAiApiKey(_controller.text);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('API Key 已保存'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
