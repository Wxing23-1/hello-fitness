// 导入Flutter Material设计组件库
import 'package:flutter/material.dart';
// 导入provider状态管理库
import 'package:provider/provider.dart';

// 导入 Supabase 云端 SDK
// hide LocalStorage：supabase_flutter 里也有同名类，避免和本地存储服务撞名
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;

// 导入全局数据仓库
import 'services/user_store.dart';
// 导入本地存储服务
import 'services/local_storage.dart';
// 导入 Supabase 连接配置
import 'services/supabase_config.dart';
// 导入主框架页面（带底部导航栏的那个骨架）
import 'screens/home/main_screen.dart';

// 程序入口函数 - 应用启动时首先执行这里
//
// 改成 async：初始化本地存储要等它完成才能启动APP，
// 否则 UserStore 构造时读不到数据，界面会先闪一下默认值
void main() async {
  // 用到平台通道（Hive 要读写文件）之前必须先初始化绑定
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Supabase 云端：账号登录、云同步、社区都依赖它。
  // 要在读取本地数据之前完成，UserStore 构造时才能判断登录态决定走不走云。
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // 打开本地数据库，之后 UserStore 构造时就能读到上次保存的数据
  await LocalStorage.init();

  runApp(
    // ChangeNotifierProvider 把 UserStore 挂到组件树的最顶层，
    // 这样下面任何一个页面都能用 context.watch / context.read 拿到它。
    //
    // 放在 MyApp 外面而不是里面：让 MyApp 本身也能读取 store，
    // 深色模式开关才能控制 MaterialApp 的主题。
    ChangeNotifierProvider(
      create: (_) => UserStore(),
      child: const MyApp(),
    ),
  );
}

// 应用的根组件 - 整个应用的起点
//
// 这个文件只负责两件事：配置全局主题、指定首页是谁。
// 具体的页面都放在 lib/screens/ 下面，保持 main.dart 干净。
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 订阅深色模式设置，用户在设置页一拨开关，这里就重建，整个APP换色
    // 只 select 需要的那一个字段，store 里其他数据变化时这里不会白重建
    final darkMode = context.select<UserStore, bool>((s) => s.darkMode);

    return MaterialApp(
      title: '健身助手', // 应用标题（在任务切换器中显示）
      debugShowCheckedModeBanner: false, // 去掉右上角那个红色DEBUG斜标

      // 浅色主题
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // 使用Material 3设计规范
        // 页面背景设成浅灰，这样白色的卡片和列表项才有层次感
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),

      // 深色主题
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark, // 关键：告诉Flutter这是暗色配色
        ),
        useMaterial3: true,
      ),

      // 用哪套主题由设置页的开关决定
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      home: const MainScreen(), // 首页改为主框架，由它管理5个标签页
    );
  }
}
