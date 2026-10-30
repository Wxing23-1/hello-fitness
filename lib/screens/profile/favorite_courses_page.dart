import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/course.dart';
import '../../services/user_store.dart';

/// 收藏课程列表页
///
/// 功能：展示已收藏课程、取消收藏、从全部课程里添加收藏。
/// 无状态组件就够了 —— 收藏数据在 store 里，这页只负责展示和转发操作。
class FavoriteCoursesPage extends StatelessWidget {
  const FavoriteCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    final favorites = store.favoriteCourses;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('收藏课程'),
        actions: [
          // 右上角「添加」：从全部课程里挑
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '从课程库添加',
            onPressed: () => _showCoursePicker(context),
          ),
        ],
      ),
      body: favorites.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 顶部统计条
                _buildSummary(favorites),
                const SizedBox(height: 12),
                // 课程卡片列表
                ...favorites.map(
                  (course) => _CourseCard(
                    course: course,
                    // 已经在收藏页了，所以按钮是「取消收藏」
                    isFavorite: true,
                    onToggle: () => _unfavorite(context, course),
                  ),
                ),
              ],
            ),
    );
  }

  /// 顶部统计：收藏数量、总时长、总消耗
  Widget _buildSummary(List<Course> favorites) {
    // 把所有收藏课程的时长和卡路里加起来
    final totalMinutes = favorites.fold(
      0,
      (sum, c) => sum + c.durationMinutes,
    );
    final totalCalories = favorites.fold(0, (sum, c) => sum + c.calories);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${favorites.length}', '门课程'),
          _statItem('$totalMinutes', '分钟'),
          _statItem('$totalCalories', '千卡'),
        ],
      ),
    );
  }

  /// 统计条里的单项
  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.pink.shade700,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  /// 取消收藏，并提供「撤销」
  void _unfavorite(BuildContext context, Course course) {
    final store = context.read<UserStore>();
    store.toggleFavorite(course.id);

    // 取消收藏是容易误触的操作，给一个撤销入口
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已取消收藏「${course.title}」'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '撤销',
          // 再 toggle 一次就恢复了
          onPressed: () => store.toggleFavorite(course.id),
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            '还没有收藏的课程',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          // 空状态里直接给个入口，省得用户去找右上角
          OutlinedButton.icon(
            onPressed: () => _showCoursePicker(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('去课程库挑几门'),
          ),
        ],
      ),
    );
  }

  /// 弹出底部课程选择面板
  void _showCoursePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // 允许面板占据更高的高度（默认最多半屏）
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _CoursePickerSheet(),
    );
  }
}

/// 底部课程选择面板
///
/// 列出全部课程，每门课右边一个心形按钮，可以直接收藏/取消。
class _CoursePickerSheet extends StatelessWidget {
  const _CoursePickerSheet();

  @override
  Widget build(BuildContext context) {
    // 这里也要 watch：点了收藏后心形图标要立刻变化
    final store = context.watch<UserStore>();

    return Container(
      // 最高占屏幕的75%，课程多了内部滚动
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部小横条，暗示可以下拉关闭
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '课程库',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '点心形图标收藏或取消',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          // 课程列表
          Flexible(
            child: ListView(
              shrinkWrap: true, // 高度跟随内容，配合 Flexible 用
              children: store.allCourses.map((course) {
                final fav = store.isFavorite(course.id);
                return _CourseCard(
                  course: course,
                  isFavorite: fav,
                  onToggle: () => store.toggleFavorite(course.id),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // 关闭按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 课程卡片
///
/// 收藏列表和课程库面板共用一个组件，区别只在 isFavorite 决定心形是实心还是空心。
class _CourseCard extends StatelessWidget {
  final Course course;

  /// 是否已收藏，决定心形图标的样式
  final bool isFavorite;

  /// 点击心形的回调
  final VoidCallback onToggle;

  const _CourseCard({
    required this.course,
    required this.isFavorite,
    required this.onToggle,
  });

  /// 难度对应的颜色：初级绿、中级橙、高级红
  Color get _levelColor {
    switch (course.level) {
      case CourseLevel.beginner:
        return Colors.green;
      case CourseLevel.intermediate:
        return Colors.orange;
      case CourseLevel.advanced:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 左侧封面占位
            // 真实封面图要等后端接好，到时候换成 CachedNetworkImage
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.blue.shade300,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            // 中间课程信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${course.coach} · ${course.category}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  // 底部三个小标签：难度、时长、卡路里
                  Row(
                    children: [
                      // 难度标签带颜色
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _levelColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          course.level.label,
                          style: TextStyle(fontSize: 10, color: _levelColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Text(
                        '${course.durationMinutes}分钟',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.local_fire_department_outlined,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Text(
                        '${course.calories}千卡',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧心形收藏按钮
            IconButton(
              icon: Icon(
                // 已收藏实心红心，未收藏空心灰心
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.pink : Colors.grey.shade400,
              ),
              tooltip: isFavorite ? '取消收藏' : '收藏',
              onPressed: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
