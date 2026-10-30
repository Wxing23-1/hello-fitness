// 导入Flutter Material设计组件库
import 'package:flutter/material.dart';

// 导入首页数据看板（第1个标签「首页」）
import 'home_dashboard_page.dart';
// 导入个人资料页面（第5个标签「我的」）
import '../profile/profile_page.dart';
// 导入训练中心页面（第2个标签「训练」）
import '../training/training_home_page.dart';
// 导入饮食记录页面（第3个标签「饮食」）
import '../nutrition/nutrition_home_page.dart';
// 导入数据统计页面（第4个标签「数据」）
import '../stats/stats_home_page.dart';
// 导入社区页面（第5个标签「社区」）
import '../community/community_home_page.dart';

/// 主框架页面 - APP的骨架，承载底部导航栏和5个标签页
///
/// 有状态组件，因为需要记住「当前选中的是第几个标签」。
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// 主框架页面的状态类
class _MainScreenState extends State<MainScreen> {
  /// 当前选中的标签索引，0=首页，1=训练，2=饮食，3=数据，4=社区，5=我的
  int _currentIndex = 0;

  /// 6个标签页对应的页面组件列表
  ///
  /// 注意这里用 final 而不是 const：列表里的 ProfilePage 是有状态组件，
  /// 整个列表没法在编译期确定为常量。
  ///
  /// 页面在这里一次性全部创建好，切换标签时只是换显示哪一个，
  /// 页面内部的状态（比如输入框里的文字）不会因为切走再切回来就丢失。
  final List<Widget> _screens = const [
    // 索引0：首页 - 今日概览看板
    HomeDashboardPage(),
    // 索引1：训练 - 已完成基础版（Week 5-7）
    TrainingHomePage(),
    // 索引2：饮食 - 食物库记录 + AI 营养估算
    NutritionHomePage(),
    // 索引3：数据 - 体重/热量/营养/训练四张图表
    StatsHomePage(),
    // 索引4：社区 - 分享训练效果和饮食
    CommunityHomePage(),
    // 索引5：我的 - 已完成的BMI计算页面
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 页面主体：显示当前选中的那一个页面
      // 这里不需要再套 AppBar，因为每个子页面自己带了 Scaffold 和 AppBar
      body: _screens[_currentIndex],

      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // 告诉导航栏当前高亮哪一项

        // 点击标签时触发：把索引存进状态，并通知Flutter重建界面
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },

        // fixed 类型：所有标签都显示文字，宽度平均分配
        // 默认的 shifting 类型只显示选中项的文字，5个标签时容易看不清
        type: BottomNavigationBarType.fixed,

        selectedItemColor: Colors.blue, // 选中项为蓝色
        unselectedItemColor: Colors.grey, // 未选中项为灰色
        selectedFontSize: 12, // 缩小字号，5个标签才不会挤在一起
        unselectedFontSize: 12,

        // 6个导航项，顺序必须和上面 _screens 列表严格一一对应
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: '训练',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant), label: '饮食'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '数据'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: '社区'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
