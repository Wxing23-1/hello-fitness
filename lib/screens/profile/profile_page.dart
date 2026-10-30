import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/user_store.dart';
import '../../services/auth_service.dart';
import '../../services/cloud_sync_service.dart';
import '../../utils/health_utils.dart';
import '../../widgets/user_avatar.dart';
import '../auth/auth_page.dart';
import 'profile_edit_page.dart';
import 'goal_setting_page.dart';
import 'workout_history_page.dart';
import 'favorite_courses_page.dart';
import 'settings_page.dart';

/// 个人中心主页
///
/// 这一页本身不编辑数据，只做两件事：
/// 1. 顶部展示用户概况（头像、昵称、BMI、累计数据）
/// 2. 下面列出5个功能入口，点进去是各自的子页面
///
/// 无状态组件就够了 —— 数据全部来自 UserStore，
/// 由 provider 负责在数据变化时触发重建。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch 订阅 UserStore：store 里调 notifyListeners 时这里会重建
    // 对应的 context.read 只读一次不订阅，用在按钮回调里
    final store = context.watch<UserStore>();
    final profile = store.profile;

    // 实时算出当前BMI和对应等级
    final bmi = calculateBmi(profile.heightCm, profile.weightKg);
    final level = bmiLevelOf(bmi);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('个人中心'),
      ),
      body: ListView(
        children: [
          // ── 顶部用户信息卡 ──
          _buildHeaderCard(context, store, bmi, level),

          const SizedBox(height: 8),

          // ── 账号（登录 / 退出）入口 ──
          _buildAccountTile(context, store),

          const SizedBox(height: 8),

          // ── 累计数据条 ──
          _buildStatsBar(store),

          const SizedBox(height: 8),

          // ── 5个功能入口 ──
          _MenuTile(
            icon: Icons.edit_note,
            iconColor: Colors.blue,
            title: '个人资料管理',
            subtitle: '昵称、性别、年龄、身高体重',
            // 点击后压入新页面，返回时 provider 会自动刷新这一页
            onTap: () => _push(context, const ProfileEditPage()),
          ),
          _MenuTile(
            icon: Icons.flag,
            iconColor: Colors.orange,
            title: '目标设置调整',
            // 副标题动态显示当前目标，不用点进去也能看到
            subtitle: '${store.goal.type.label} · 目标 ${store.goal.targetWeightKg.toStringAsFixed(0)}kg',
            onTap: () => _push(context, const GoalSettingPage()),
          ),
          _MenuTile(
            icon: Icons.history,
            iconColor: Colors.green,
            title: '训练历史记录',
            subtitle: '共 ${store.totalWorkouts} 条记录',
            onTap: () => _push(context, const WorkoutHistoryPage()),
          ),
          _MenuTile(
            icon: Icons.favorite,
            iconColor: Colors.pink,
            title: '收藏课程',
            subtitle: '已收藏 ${store.favoriteCourses.length} 门课程',
            onTap: () => _push(context, const FavoriteCoursesPage()),
          ),
          _MenuTile(
            icon: Icons.settings,
            iconColor: Colors.grey,
            title: '系统设置',
            subtitle: '提醒、单位、深色模式、关于',
            onTap: () => _push(context, const SettingsPage()),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 跳转到子页面的快捷方法
  ///
  /// 抽出来是因为上面要用5次，写成一行更清楚
  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  /// 账号入口：未登录提示登录，已登录显示邮箱 + 退出
  Widget _buildAccountTile(BuildContext context, UserStore store) {
    final signedIn = store.isSignedIn;
    final email = AuthService.currentUser?.email;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (signedIn ? Colors.green : Colors.orange).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            signedIn ? Icons.cloud_done : Icons.cloud_off,
            color: signedIn ? Colors.green : Colors.orange,
            size: 22,
          ),
        ),
        title: Text(
          signedIn ? (email ?? '已登录') : '登录 / 注册',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          signedIn ? '数据已开启云端同步' : '登录后数据云端同步，换设备不丢',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: signedIn
            ? TextButton(
                onPressed: () => _confirmSignOut(context),
                child: const Text('退出'),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: signedIn
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                ),
      ),
    );
  }

  /// 退出登录前确认一下，避免误触
  Future<void> _confirmSignOut(BuildContext context) async {
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

  /// 头像操作菜单：拍照 / 相册 / 移除
  Future<void> _showAvatarMenu(BuildContext context, UserStore store) async {
    if (!store.isSignedIn) {
      final goLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('请先登录'),
          content: const Text('头像存在云端，需要先登录账号才能上传。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
      if (goLogin == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
        );
      }
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (store.profile.avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title:
                    const Text('移除头像', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'remove') {
      await CloudSyncService.deleteAvatar();
      store.setAvatarUrl(null);
      return;
    }

    // 拍照或选图
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null || !context.mounted) return;

    final bytes = await file.readAsBytes();
    final url = await CloudSyncService.uploadAvatar(bytes);
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，请稍后再试')),
        );
      }
      return;
    }

    store.setAvatarUrl(url);
  }

  /// 顶部用户信息卡：头像 + 昵称 + 简介 + BMI
  Widget _buildHeaderCard(
    BuildContext context,
    UserStore store,
    double bmi,
    BmiLevel level,
  ) {
    final profile = store.profile;

    return Container(
      width: double.infinity, // 占满横向宽度
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 渐变背景，从深蓝到浅蓝，比纯色好看一点
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // 头像：点击可拍照/选图上传，没登录会先引导去登录
              UserAvatar(
                avatarUrl: profile.avatarUrl,
                radius: 36,
                onTap: () => _showAvatarMenu(context, store),
              ),
              const SizedBox(width: 16),
              // 昵称、性别年龄、简介
              // Expanded 让这一块吃掉剩余宽度，简介太长时才能正确换行
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.gender.label} · ${profile.age}岁 · ${profile.heightCm.toStringAsFixed(0)}cm',
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    // 简介为空就不占地方
                    if (profile.bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        profile.bio,
                        maxLines: 2, // 最多两行
                        overflow: TextOverflow.ellipsis, // 超出显示省略号
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70, // 半透明白，弱化显示
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // BMI 小卡片
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, // 三块平均分布
              children: [
                _MiniStat(
                  label: 'BMI',
                  value: bmi > 0 ? bmi.toStringAsFixed(1) : '--',
                  valueColor: level.color,
                ),
                _MiniStat(
                  label: '状态',
                  value: bmi > 0 ? level.label : '--',
                  valueColor: level.color,
                ),
                _MiniStat(
                  label: '体重',
                  value: '${profile.weightKg.toStringAsFixed(1)}kg',
                  valueColor: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 累计数据条：训练次数 / 总时长 / 总消耗
  Widget _buildStatsBar(UserStore store) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(
            label: '累计训练',
            value: '${store.totalWorkouts}次',
            valueColor: Colors.black87,
          ),
          _MiniStat(
            label: '总时长',
            value: formatDuration(store.totalMinutes),
            valueColor: Colors.black87,
          ),
          _MiniStat(
            label: '总消耗',
            value: '${store.totalCalories}千卡',
            valueColor: Colors.black87,
          ),
        ],
      ),
    );
  }
}

/// 小数据块：上面是数值，下面是标签
///
/// 顶部卡片和累计数据条都用到，所以抽成独立组件
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// 功能入口行：左边彩色图标，中间标题和副标题，右边箭头
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap; // 点击回调，VoidCallback 就是 void Function()

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      // 用 Border 画一条底部细线做分隔，比 Divider 组件少一层嵌套
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        // 图标套一个浅色圆角背景，视觉上更像按钮
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1), // 同色系10%透明度
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
