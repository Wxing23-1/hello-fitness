import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/weight_log.dart';
import '../../services/user_store.dart';

/// 体重记录页
///
/// 记录体重和体脂，这些数据喂给体重趋势图。
/// 新记录会同步更新个人资料里的当前体重，省得改两处。
class WeightLogPage extends StatefulWidget {
  const WeightLogPage({super.key});

  @override
  State<WeightLogPage> createState() => _WeightLogPageState();
}

class _WeightLogPageState extends State<WeightLogPage> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<UserStore>();
    // 倒序显示，最近的在上面
    final logs = store.weightLogs.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('体重记录'),
      ),
      body: logs.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                final log = logs[i];
                // 和前一条（时间上更早的）比，算出变化量
                final prev = i + 1 < logs.length ? logs[i + 1] : null;

                return _LogTile(
                  log: log,
                  diff: prev == null ? null : log.weightKg - prev.weightKg,
                  onDelete: () => _confirmDelete(store, log),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLog,
        icon: const Icon(Icons.add),
        label: const Text('记录体重'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            Text(
              '还没有体重记录',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '建议固定时间称重（比如早起空腹），\n这样数据才有可比性',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addLog() async {
    final store = context.read<UserStore>();

    final log = await showModalBottomSheet<WeightLog>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // 预填当前体重，多数时候只需微调
      builder: (_) => _WeightInputSheet(current: store.profile.weightKg),
    );

    if (log == null || !mounted) return;

    store.addWeightLog(log);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已记录'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(UserStore store, WeightLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: Text(
          '删除 ${log.date.month}月${log.date.day}日的 '
          '${log.weightKg.toStringAsFixed(1)}kg 记录？',
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

    if (confirm == true) store.deleteWeightLog(log.id);
  }
}

/// 一条体重记录
class _LogTile extends StatelessWidget {
  final WeightLog log;

  /// 和上一次相比的变化量，null 表示这是最早的一条
  final double? diff;

  final VoidCallback onDelete;

  const _LogTile({
    required this.log,
    required this.diff,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${log.date.month}月${log.date.day}日',
                style: const TextStyle(fontSize: 13),
              ),
              if (log.note != null && log.note!.isNotEmpty)
                Text(
                  log.note!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          const Spacer(),

          // 体脂率，有才显示
          if (log.bodyFatPercent != null) ...[
            Text(
              '${log.bodyFatPercent!.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
          ],

          // 变化量
          if (diff != null && diff!.abs() >= 0.05) ...[
            Icon(
              diff! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: diff! > 0 ? Colors.deepOrange : Colors.green,
            ),
            Text(
              diff!.abs().toStringAsFixed(1),
              style: TextStyle(
                fontSize: 11,
                color: diff! > 0 ? Colors.deepOrange : Colors.green,
              ),
            ),
            const SizedBox(width: 10),
          ],

          Text(
            log.weightKg.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' kg',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close, size: 16),
            color: Colors.grey.shade400,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// 体重输入弹窗
class _WeightInputSheet extends StatefulWidget {
  /// 当前体重，用来预填
  final double current;

  const _WeightInputSheet({required this.current});

  @override
  State<_WeightInputSheet> createState() => _WeightInputSheetState();
}

class _WeightInputSheetState extends State<_WeightInputSheet> {
  late final TextEditingController _weightController;
  final _fatController = TextEditingController();
  final _noteController = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.current > 0 ? widget.current.toStringAsFixed(1) : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _fatController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final w = double.tryParse(_weightController.text.trim());

    if (w == null || w <= 0) {
      setState(() => _error = '请填写有效的体重');
      return;
    }
    // 人类体重的合理范围，挡住明显的输入错误（比如单位填错）
    if (w < 20 || w > 300) {
      setState(() => _error = '体重应该在 20-300kg 之间');
      return;
    }

    final fatText = _fatController.text.trim();
    double? fat;
    if (fatText.isNotEmpty) {
      fat = double.tryParse(fatText);
      if (fat == null || fat < 1 || fat > 70) {
        setState(() => _error = '体脂率应该在 1-70% 之间');
        return;
      }
    }

    final note = _noteController.text.trim();

    Navigator.pop(
      context,
      WeightLog.create(
        weightKg: w,
        bodyFatPercent: fat,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '记录体重',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '同一天重复记录会覆盖之前的',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '体重',
                suffixText: 'kg',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _fatController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '体脂率（可选）',
                suffixText: '%',
                helperText: '有体脂秤才填，没有留空',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteController,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '比如：早起空腹',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
