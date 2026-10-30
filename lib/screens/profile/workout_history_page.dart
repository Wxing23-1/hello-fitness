import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/workout_record.dart';
import '../../services/user_store.dart';
import '../../utils/health_utils.dart';

/// 训练历史记录页
///
/// 功能：按类型筛选、左滑删除、右下角按钮新增记录。
/// 有状态组件，因为「当前筛选的是哪个类型」是页面自己的状态，
/// 不需要存到全局 store 里。
class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  /// 当前筛选的训练类型，null 表示「全部」
  WorkoutType? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();

    // 按筛选条件过滤记录
    // _filter 为 null 时不过滤，直接用全部记录
    final records = _filter == null
        ? store.records
        : store.records.where((r) => r.type == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('训练历史记录'),
      ),
      body: Column(
        children: [
          // ── 顶部汇总条 ──
          _buildSummary(store),

          // ── 类型筛选条（横向滚动的小标签）──
          _buildFilterBar(),

          const Divider(height: 1),

          // ── 记录列表 ──
          // Expanded 让列表吃掉剩余的垂直空间，否则 ListView 在 Column 里会报错
          Expanded(
            child: records.isEmpty
                ? _buildEmptyState() // 没有记录时显示空状态提示
                : ListView.builder(
                    // ListView.builder 只构建屏幕上可见的项，记录多了也不卡
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      return _buildRecordItem(context, records[index]);
                    },
                  ),
          ),
        ],
      ),
      // 右下角悬浮按钮，点击新增记录
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        tooltip: '添加训练记录',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// 顶部汇总：本周训练次数 vs 目标，以及累计数据
  Widget _buildSummary(UserStore store) {
    final weekDone = store.thisWeekWorkouts;
    final weekTarget = store.goal.weeklyWorkouts;

    // 完成进度，用于进度条。clamp 限制在0-1之间，超额完成也不会溢出
    final progress = weekTarget == 0
        ? 0.0
        : (weekDone / weekTarget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const Text('本周训练', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '$weekDone / $weekTarget 次',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  // 达标变绿色，没达标保持蓝色
                  color: weekDone >= weekTarget ? Colors.green : Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4), // 圆角进度条
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation(
                weekDone >= weekTarget ? Colors.green : Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 累计数据
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('累计', '${store.totalWorkouts}次'),
              _summaryItem('时长', formatDuration(store.totalMinutes)),
              _summaryItem('消耗', '${store.totalCalories}千卡'),
            ],
          ),
        ],
      ),
    );
  }

  /// 汇总条里的单个数据项
  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  /// 类型筛选条
  Widget _buildFilterBar() {
    return SizedBox(
      height: 52,
      // 标签多了放不下，所以横向滚动
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // 「全部」标签
          _filterChip(label: '全部', type: null),
          // 其余按训练类型生成
          ...WorkoutType.values.map(
            (t) => _filterChip(label: t.label, type: t),
          ),
        ],
      ),
    );
  }

  /// 单个筛选标签
  Widget _filterChip({required String label, required WorkoutType? type}) {
    final selected = _filter == type;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        // 点击时切换筛选条件
        onSelected: (_) => setState(() => _filter = type),
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue.shade800,
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? Colors.blue.shade800 : Colors.black87,
        ),
      ),
    );
  }

  /// 单条训练记录
  Widget _buildRecordItem(BuildContext context, WorkoutRecord record) {
    // Dismissible 实现左滑删除
    return Dismissible(
      // key 必须唯一且稳定，否则删除时 Flutter 会认错是哪一项
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart, // 只允许从右往左滑
      // 滑动时露出的红色背景
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      // 滑完后先弹确认框，用户点「删除」才真的删
      confirmDismiss: (_) => _confirmDelete(context, record),
      // 确认删除后执行
      onDismissed: (_) {
        context.read<UserStore>().deleteRecord(record.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('记录已删除'), duration: Duration(seconds: 2)),
        );
      },
      child: Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        child: ListTile(
          // 左侧类型图标
          leading: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(record.type.icon, color: Colors.blue, size: 22),
          ),
          title: Row(
            children: [
              Text(
                record.type.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              // 相对日期标签：今天/昨天/3天前
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatRelativeDate(record.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                '${formatDuration(record.durationMinutes)} · ${record.calories}千卡',
                style: const TextStyle(fontSize: 12),
              ),
              // 有备注才显示
              if (record.note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  record.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          // 提示用户可以左滑
          trailing: Icon(
            Icons.swipe_left,
            size: 16,
            color: Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  /// 删除确认对话框
  ///
  /// 返回 Future<bool>：true 表示确认删除，false 表示取消
  Future<bool> _confirmDelete(
    BuildContext context,
    WorkoutRecord record,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
          '确定删除这条「${record.type.label}」记录吗？删除后无法恢复。',
        ),
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

    // 用户点对话框外面关掉时 result 是 null，当作取消处理
    return result ?? false;
  }

  /// 空状态：没有记录时的提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            // 区分「真的没记录」和「筛选后没结果」，提示文字不一样
            _filter == null ? '还没有训练记录' : '没有「${_filter!.label}」类型的记录',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            '点右下角 + 添加一条',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  /// 弹出「添加训练记录」对话框
  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      // 单独抽成一个有状态组件，因为对话框内部也要管理自己的输入状态
      builder: (_) => const _AddRecordDialog(),
    );
  }
}

/// 添加训练记录对话框
///
/// 独立的有状态组件：对话框里的类型选择和输入框需要自己的 setState，
/// 混在父页面里会导致每次输入都重建整个列表。
class _AddRecordDialog extends StatefulWidget {
  const _AddRecordDialog();

  @override
  State<_AddRecordDialog> createState() => _AddRecordDialogState();
}

class _AddRecordDialogState extends State<_AddRecordDialog> {
  /// 选中的训练类型，默认跑步
  WorkoutType _type = WorkoutType.running;

  final _durationController = TextEditingController(text: '30');
  final _caloriesController = TextEditingController(text: '200');
  final _noteController = TextEditingController();

  /// 错误提示文字，null 表示没有错误
  String? _error;

  @override
  void dispose() {
    _durationController.dispose();
    _caloriesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// 提交新记录
  void _submit() {
    final duration = int.tryParse(_durationController.text);
    final calories = int.tryParse(_caloriesController.text);

    // 校验：时长和卡路里必须是正数
    if (duration == null || duration <= 0) {
      setState(() => _error = '请输入有效的训练时长');
      return;
    }
    if (calories == null || calories < 0) {
      setState(() => _error = '请输入有效的消耗卡路里');
      return;
    }

    // 用当前时间戳当id，保证不重复
    final record = WorkoutRecord(
      id: 'w${DateTime.now().millisecondsSinceEpoch}',
      type: _type,
      date: DateTime.now(),
      durationMinutes: duration,
      calories: calories,
      note: _noteController.text.trim(),
    );

    context.read<UserStore>().addRecord(record);
    Navigator.pop(context); // 关闭对话框

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('记录已添加'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加训练记录'),
      // 对话框内容可能超出屏幕（尤其键盘弹出时），所以套一层滚动
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 高度只占内容需要的大小
          children: [
            const Text('训练类型', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            // 类型选择：用 Wrap 自动换行排列小标签
            Wrap(
              spacing: 6, // 水平间距
              runSpacing: 6, // 换行后的垂直间距
              children: WorkoutType.values.map((t) {
                final selected = t == _type;
                return ChoiceChip(
                  label: Text(t.label, style: const TextStyle(fontSize: 12)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: Colors.blue.shade100,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '训练时长',
                suffixText: '分钟',
                border: OutlineInputBorder(),
                isDense: true, // 紧凑模式，对话框里省地方
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '消耗卡路里',
                suffixText: '千卡',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            // 有错误才显示红色提示
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
