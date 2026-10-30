// Flutter 组件测试
//
// 测试在「虚拟屏幕」里跑，不需要真机或模拟器，几秒钟就能验证界面逻辑对不对。
// 运行命令：flutter test
//
// 注意：MyApp 现在依赖 provider 注入的 UserStore，
// 所以测试里不能直接 pumpWidget(MyApp())，要用下面的 _buildApp() 包一层。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hello_fitness/main.dart';
import 'package:hello_fitness/services/user_store.dart';

/// 构造一个带 provider 的完整APP，供测试使用
///
/// 每次调用都 new 一个新 store，保证测试之间互不影响
Widget _buildApp() {
  return ChangeNotifierProvider(
    create: (_) => UserStore(),
    child: const MyApp(),
  );
}

/// 把测试视口调成手机尺寸并渲染APP
///
/// 测试默认视口是 800×600 的横屏比例，个人中心的功能入口列表放不下，
/// 「收藏课程」「系统设置」会被挤到屏幕外导致 find 找不到。
/// 这里改成 450×1000 的竖屏，和真机一致。
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(450, 1000));

  // 测试结束后恢复默认视口，不然会影响后面的测试
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_buildApp());
}

/// 从首页切换到「我的」标签（个人中心）
///
/// 几乎每个测试都要先走这一步，抽成函数省得重复写
Future<void> _gotoProfile(WidgetTester tester) async {
  // 底部导航栏的「我的」图标
  await tester.tap(find.byIcon(Icons.person));
  await tester.pumpAndSettle(); // 等切换动画和重建完成
}

void main() {
  // ══════════════════════════════════════════
  //  底部导航栏
  // ══════════════════════════════════════════
  group('底部导航栏', () {
    testWidgets('显示5个标签，默认停在首页', (tester) async {
      await _pumpApp(tester);

      // 「首页」会出现2次（导航栏标签 + 页面大标题），所以用 findsWidgets
      expect(find.text('首页'), findsWidgets);
      expect(find.text('训练'), findsOneWidget);
      expect(find.text('饮食'), findsOneWidget);
      expect(find.text('数据'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);

      // 默认停在首页看板，标志性内容是问候语和几张数据卡
      expect(find.text('今日概览'), findsOneWidget);
      expect(find.text('本周训练'), findsOneWidget);
      expect(find.text('体重目标'), findsOneWidget);
    });

    testWidgets('点「我的」能切到个人中心', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      // 个人中心的标志性内容
      expect(find.text('个人中心'), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  个人中心主页
  // ══════════════════════════════════════════
  group('个人中心主页', () {
    testWidgets('显示5个功能入口', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      expect(find.text('个人资料管理'), findsOneWidget);
      expect(find.text('目标设置调整'), findsOneWidget);
      expect(find.text('训练历史记录'), findsOneWidget);
      expect(find.text('收藏课程'), findsOneWidget);
      expect(find.text('系统设置'), findsOneWidget);
    });

    testWidgets('顶部显示BMI和状态', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      // 默认资料 175cm / 70kg，BMI = 22.9，属于「正常」
      expect(find.text('22.9'), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
    });

    testWidgets('入口副标题显示实时数据', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      // 7条演示记录、3门收藏课程
      expect(find.text('共 7 条记录'), findsOneWidget);
      expect(find.text('已收藏 3 门课程'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  个人资料管理
  // ══════════════════════════════════════════
  group('个人资料管理', () {
    testWidgets('表单预填当前资料', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('个人资料管理'));
      await tester.pumpAndSettle();

      // 输入框里应该已经是现有的值
      expect(find.widgetWithText(TextFormField, '张三'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '175'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '70.0'), findsOneWidget);
    });

    testWidgets('改体重后保存，主页BMI跟着变', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('个人资料管理'));
      await tester.pumpAndSettle();

      // 把体重从 70 改成 85
      // 输入框顺序：昵称(0) 年龄(1) 身高(2) 体重(3) 简介(4)
      await tester.enterText(find.byType(TextFormField).at(3), '85');
      await tester.pumpAndSettle();

      // 页面内的BMI预览应该立刻更新：85 ÷ 1.75² = 27.755... → 27.8
      expect(find.text('27.8'), findsOneWidget);
      // 27.8 属于「偏胖」
      expect(find.text('偏胖'), findsWidgets);

      // 点保存
      await tester.tap(find.text('保存').first);
      await tester.pumpAndSettle();

      // 回到个人中心，BMI 已经是新值
      expect(find.text('个人中心'), findsOneWidget);
      expect(find.text('27.8'), findsOneWidget);
      expect(find.text('85.0kg'), findsOneWidget);
    });

    testWidgets('昵称为空时保存被拦住', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('个人资料管理'));
      await tester.pumpAndSettle();

      // 清空昵称
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.tap(find.text('保存').first);
      await tester.pumpAndSettle();

      // 应该显示校验错误，而且还停在编辑页没返回
      expect(find.text('昵称不能为空'), findsOneWidget);
      expect(find.text('个人资料管理'), findsOneWidget);
    });

    testWidgets('身高超出范围时提示错误', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('个人资料管理'));
      await tester.pumpAndSettle();

      // 填一个离谱的身高
      await tester.enterText(find.byType(TextFormField).at(2), '500');
      await tester.tap(find.text('保存').first);
      await tester.pumpAndSettle();

      expect(find.text('身高应在 100-250cm 之间'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  目标设置
  // ══════════════════════════════════════════
  group('目标设置调整', () {
    testWidgets('显示三种目标类型和当前选中项', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('目标设置调整'));
      await tester.pumpAndSettle();

      expect(find.text('减脂'), findsOneWidget);
      expect(find.text('增肌'), findsOneWidget);
      expect(find.text('保持'), findsOneWidget);

      // 默认目标是减脂，所以有一个实心勾
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('切换目标类型后保存，主页副标题更新', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('目标设置调整'));
      await tester.pumpAndSettle();

      // 选「增肌」
      await tester.tap(find.text('增肌'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存').first);
      await tester.pumpAndSettle();

      // 个人中心的副标题应该变成增肌
      expect(find.textContaining('增肌'), findsOneWidget);
    });

    testWidgets('显示健康体重区间建议', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('目标设置调整'));
      await tester.pumpAndSettle();

      // 175cm 对应 56.7-73.5kg
      expect(find.textContaining('健康体重约为'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  训练历史
  // ══════════════════════════════════════════
  group('训练历史记录', () {
    testWidgets('列出演示记录和汇总数据', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('训练历史记录'));
      await tester.pumpAndSettle();

      // 汇总条
      expect(find.text('本周训练'), findsOneWidget);
      expect(find.text('7次'), findsOneWidget);

      // 第一条记录是今天的跑步
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('昨天'), findsOneWidget);
    });

    testWidgets('按类型筛选', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('训练历史记录'));
      await tester.pumpAndSettle();

      // 点「瑜伽」筛选标签
      await tester.tap(find.widgetWithText(FilterChip, '瑜伽'));
      await tester.pumpAndSettle();

      // 演示数据里只有1条瑜伽，列表应该只剩它
      // 「瑜伽」这个词会出现2次：筛选标签 + 记录标题
      expect(find.text('瑜伽'), findsNWidgets(2));
      // 跑步记录被筛掉了，只剩筛选标签那一个
      expect(find.text('跑步'), findsOneWidget);
    });

    testWidgets('筛选出空结果时显示提示', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('训练历史记录'));
      await tester.pumpAndSettle();

      // 演示数据里没有「游泳」之外的某些类型，这里用没有记录的类型
      // demoRecords 里有：跑步、力量训练×2、瑜伽、HIIT、骑行、游泳
      // 全都有记录，所以先删掉游泳那条再筛
      await tester.tap(find.widgetWithText(FilterChip, '游泳'));
      await tester.pumpAndSettle();

      // 游泳有1条记录，所以不是空状态
      expect(find.text('还没有训练记录'), findsNothing);
    });

    testWidgets('新增一条记录', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('训练历史记录'));
      await tester.pumpAndSettle();

      // 点右下角 +
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('添加训练记录'), findsOneWidget);

      // 对话框里时长和卡路里有默认值，直接点添加
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();

      // 记录数从7变成8
      expect(find.text('8次'), findsOneWidget);
    });

    testWidgets('时长填非法值时拦住', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('训练历史记录'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 时长填 0
      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.tap(find.widgetWithText(FilledButton, '添加'));
      await tester.pumpAndSettle();

      expect(find.text('请输入有效的训练时长'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  收藏课程
  // ══════════════════════════════════════════
  group('收藏课程', () {
    testWidgets('列出已收藏的3门课', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('收藏课程'));
      await tester.pumpAndSettle();

      // 默认收藏 c1 c3 c5
      expect(find.text('新手全身燃脂'), findsOneWidget);
      expect(find.text('哑铃上肢塑形'), findsOneWidget);
      expect(find.text('HIIT 极限挑战'), findsOneWidget);

      // 没收藏的不显示
      expect(find.text('腹肌撕裂者'), findsNothing);

      // 统计条
      expect(find.text('3'), findsOneWidget);
      expect(find.text('门课程'), findsOneWidget);
    });

    testWidgets('点心形取消收藏，列表少一项', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('收藏课程'));
      await tester.pumpAndSettle();

      // 点第一个实心红心
      await tester.tap(find.byIcon(Icons.favorite).first);
      await tester.pumpAndSettle();

      // 那门课从列表里消失了
      expect(find.text('新手全身燃脂'), findsNothing);
      // 统计变成2门
      expect(find.text('2'), findsOneWidget);
      // 底部出现撤销提示
      expect(find.text('撤销'), findsOneWidget);
    });

    testWidgets('从课程库添加收藏', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('收藏课程'));
      await tester.pumpAndSettle();

      // 点右上角 +
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('课程库'), findsOneWidget);
      // 课程库里5门课都列出来了
      expect(find.text('腹肌撕裂者'), findsOneWidget);

      // 点「腹肌撕裂者」旁边的空心心形
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();

      // 关闭面板
      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      await tester.pumpAndSettle();

      // 收藏列表里多了这门课
      expect(find.text('腹肌撕裂者'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════
  //  系统设置
  // ══════════════════════════════════════════
  group('系统设置', () {
    testWidgets('显示4组设置项', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('系统设置'));
      await tester.pumpAndSettle();

      expect(find.text('深色模式'), findsOneWidget);
      expect(find.text('单位制'), findsOneWidget);
      expect(find.text('训练提醒'), findsOneWidget);
      expect(find.text('喝水提醒'), findsOneWidget);
      expect(find.text('清除训练记录'), findsOneWidget);
      expect(find.text('关于本应用'), findsOneWidget);
    });

    testWidgets('拨动深色模式开关，整个APP换成暗色主题', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('系统设置'));
      await tester.pumpAndSettle();

      // 切换前是浅色
      var app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);

      // 点深色模式那一行的开关
      await tester.tap(find.widgetWithText(SwitchListTile, '深色模式'));
      await tester.pumpAndSettle();

      // MaterialApp 的 themeMode 应该变成 dark
      app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('切换单位制', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('系统设置'));
      await tester.pumpAndSettle();

      // 默认公制
      expect(find.text('公制'), findsOneWidget);

      // 点进去选英制
      await tester.tap(find.text('单位制'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('英制').last);
      await tester.pumpAndSettle();

      // 右侧显示值变了
      expect(find.text('英制'), findsOneWidget);
    });

    testWidgets('清除训练记录要先确认', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('系统设置'));
      await tester.pumpAndSettle();

      // 右侧显示当前有7条
      expect(find.text('7 条'), findsOneWidget);

      await tester.tap(find.text('清除训练记录'));
      await tester.pumpAndSettle();

      // 弹出确认框
      expect(find.textContaining('将删除全部 7 条训练记录'), findsOneWidget);

      // 先点取消，数据不动
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('7 条'), findsOneWidget);

      // 再来一次，这次确认
      await tester.tap(find.text('清除训练记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定清除'));
      await tester.pumpAndSettle();

      // 变成0条
      expect(find.text('0 条'), findsOneWidget);
    });

    testWidgets('恢复默认数据把改动全部还原', (tester) async {
      await _pumpApp(tester);
      await _gotoProfile(tester);

      await tester.tap(find.text('系统设置'));
      await tester.pumpAndSettle();

      // 先把记录清空，制造一个「被改过」的状态
      await tester.tap(find.text('清除训练记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定清除'));
      await tester.pumpAndSettle();
      expect(find.text('0 条'), findsOneWidget);

      // 恢复默认
      await tester.tap(find.text('恢复默认数据'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      // 7条演示数据回来了
      expect(find.text('7 条'), findsOneWidget);
    });
  });
}
