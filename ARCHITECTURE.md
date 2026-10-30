# Hello Fitness 项目架构

一个 Flutter 健身管理应用：训练计划、饮食记录、数据统计三大模块，带 AI 辅助（生成训练计划、估算食物营养）。

- 代码量：`lib/` 下约 17600 行 Dart
- 测试：216 个测试用例，`flutter test` 全部通过
- 平台：Web（Chrome，当前开发目标）+ Android/iOS
- 状态管理：Provider（单一 `UserStore`）
- 本地存储：Hive（Web 端落到 IndexedDB）

---

## 一、分层结构

```
lib/
├── main.dart              应用入口，初始化 Hive 和 Provider
├── models/                纯数据类，无 UI 依赖
├── data/                  静态数据（预置训练计划、食物营养库）
├── services/              状态管理、持久化、AI 调用
├── utils/                 纯函数计算（BMI、TDEE、宏量素）
└── screens/               UI，按业务模块分目录
```

依赖方向单向：`screens → services → models`，`utils` 和 `data` 被任意层引用。models 不反向依赖任何上层，所以能独立单测。

---

## 二、数据模型（`lib/models/`）

| 文件 | 作用 |
|---|---|
| `user_profile.dart` | 用户资料：身高、体重、性别、年龄 |
| `fitness_goal.dart` | 健身目标：减脂/增肌/保持，目标体重与每日热量 |
| `training_plan.dart` | 训练计划三层结构：`TrainingPlan` → `TrainingDay` → `Exercise` |
| `workout_log.dart` | 训练完成记录：`WorkoutLog` → `ExerciseLog` → `SetLog` |
| `session_draft.dart` | 训练中断草稿，练到一半退出时保存进度 |
| `workout_record.dart` | 简易训练打卡（早期模块，与 WorkoutLog 并存） |
| `food_item.dart` | 食物营养成分，按每 100g 存 |
| `meal_entry.dart` | 一条饮食记录 + `NutritionSummary` 汇总类 |
| `weight_log.dart` | 体重记录，每天一条，用于画曲线 |
| `course.dart` | 课程数据（收藏功能用） |

所有模型都有 `toMap()` / `fromMap()`，持久化走 JSON 字符串而不是 Hive TypeAdapter —— 省掉代码生成步骤，字段增删时旧数据用 `?? 默认值` 兜住即可。

### 训练计划的三层嵌套

```
TrainingPlan（计划：名称、目标、周期）
  └── TrainingDay（训练日：第几天、预计时长）
        └── Exercise（动作：组数、次数、建议重量、步骤、常见错误）
```

`Exercise` 带 `steps` 和 `mistakes` 两个列表，支撑动作详解弹窗。预置计划里 30 个动作已填充这两个字段。

---

## 三、服务层（`lib/services/`）

### `user_store.dart` —— 唯一状态源

继承 `ChangeNotifier`，所有业务状态集中在这里。界面通过 `context.watch<UserStore>()` 订阅，数据变更后 `notifyListeners()` 触发重建。

职责分组：

- **资料与目标**：`profile`、`goal`、`bmr`、`dailyCalorieTarget`
- **训练计划**：`aiPlans`、`activePlanId`、`activePlan`、`savePlan`、`deleteAiPlan`
- **训练记录**：`workoutLogs`、`addWorkoutLog`、`thisWeekPlanWorkouts`
- **中断草稿**：`draft`、`saveDraft`、`clearDraft`
- **饮食**：`meals`、`mealsOn`、`addMeal`、`deleteMeal`、`customFoods`、`macroTargets`
- **体重**：`weightLogs`、`recentWeightLogs`、`addWeightLog`、`deleteWeightLog`

每个 setter 都先写内存、再调 `_persistXxx()` 落盘、最后通知监听者。

### `local_storage.dart` —— Hive 封装

单一 box `fitness_data`，14 个 key：

```
profile          用户资料
goal             健身目标
records          简易打卡记录
favorites        收藏课程
settings         应用设置
ai_api_key       AI 接口密钥
ai_plans         AI 生成的训练计划
workout_logs     训练完成记录
active_plan_id   当前选中的计划（只存 id）
session_draft    训练中断草稿
meal_entries     饮食记录
custom_foods     用户自建食物
weight_logs      体重记录
activity_level   活动水平（算 TDEE 用）
```

`active_plan_id` 只存 id 不存计划内容：预置计划定义在代码里、AI 计划已单独持久化，存两份会在计划变更时产生不一致。

### AI 服务

- `ai_plan_service.dart` —— 根据用户资料生成训练计划
- `ai_food_service.dart` —— 文字描述或拍照估算食物营养

两者都是无状态静态类，返回结构化结果对象（带 `error` 字段），不抛异常给界面。

---

## 四、工具层（`lib/utils/`）

- `health_utils.dart` —— BMI 计算与分级、时长格式化
- `nutrition_utils.dart` —— BMR（Mifflin-St Jeor）、TDEE、宏量素目标分配、营养换算

纯函数，无副作用，测试覆盖最密集的一层。

---

## 五、界面层（`lib/screens/`）

底部导航五个标签，全部已实现（无占位页）：

```
首页 → home/home_dashboard_page.dart
训练 → training/training_home_page.dart
饮食 → nutrition/nutrition_home_page.dart
数据 → stats/stats_home_page.dart
我的 → profile/profile_page.dart
```

### 训练模块（`screens/training/`）

| 文件 | 作用 |
|---|---|
| `training_home_page.dart` | 计划列表，按类别筛选，当前计划高亮 |
| `plan_detail_page.dart` | 计划详情，训练日列表，选用/取消选用 |
| `day_edit_page.dart` | 编辑训练日：改组数次数重量、删动作、调顺序 |
| `workout_session_page.dart` | 训练执行：计组、休息倒计时、记重量 |
| `session_summary_page.dart` | 训练总结 |
| `start_session.dart` | 共用启动入口，有草稿先问是否接着练 |
| `exercise_guide_sheet.dart` | 动作详解弹窗：步骤 + 常见错误 |
| `ai_generate_page.dart` | AI 生成计划 |
| `training_log_page.dart` | 训练历史 |
| `workout_log_detail_page.dart` | 单次训练详情 |

**编辑预置计划的处理**：预置计划是 `const` 常量改不了，编辑时另存为一份新计划（新 id + 重映射每个 `TrainingDay.planId`），原预置保持不动。AI 计划则原地覆盖。

### 饮食模块（`screens/nutrition/`）

| 文件 | 作用 |
|---|---|
| `nutrition_home_page.dart` | 今日热量环 + 三餐列表 |
| `food_picker_page.dart` | 食物库选择，搜索 + 分类筛选 |
| `portion_sheet.dart` | 份量输入，实时显示营养换算 |
| `custom_food_page.dart` | 自建食物 |
| `ai_food_page.dart` | AI 识别：文字描述或拍照 |
| `nutrition_history_page.dart` | 历史记录按天分组 |

热量环中间显示「还能吃多少」而不是「吃了多少」—— 剩余量才是决定下一餐的依据。

### 数据模块（`screens/stats/`）

| 文件 | 作用 |
|---|---|
| `stats_home_page.dart` | 四张图表的容器 |
| `weight_chart.dart` | 体重曲线（折线图） |
| `calorie_chart.dart` | 热量摄入 vs 消耗（双色柱状图） |
| `macro_chart.dart` | 三大宏量素占比（饼图） |
| `workout_chart.dart` | 训练量趋势（柱状图） |
| `weight_log_page.dart` | 体重记录增删 |
| `chart_empty.dart` | 图表空状态，没数据时显示提示而非空坐标系 |

图表用 `fl_chart`。

---

## 六、静态数据（`lib/data/`）

- `preset_plans.dart` —— 4 套预置训练计划（新手减脂、纯有氧、增肌、体能维持），器械动作带建议重量，30 个动作带步骤与常见错误
- `food_database.dart` —— 70 条常见食物营养数据，分主食/蛋白/蔬菜/水果/坚果/饮品等类别，数据参考《中国食物成分表（第 6 版）》

---

## 七、测试（`test/`）

216 个用例，13 个文件：

| 文件 | 覆盖内容 |
|---|---|
| `health_utils_test.dart` | BMI 计算与边界 |
| `nutrition_test.dart` | 营养换算、宏量素目标、汇总、食物库完整性 |
| `training_plan_test.dart` | 计划模型与序列化 |
| `active_plan_test.dart` | 选用计划、悬空 id 处理 |
| `plan_edit_test.dart` | 编辑保存两条路径（原地覆盖 / 另存副本） |
| `session_draft_test.dart` | 草稿序列化与过期判断 |
| `exercise_guide_test.dart` | 动作详解字段与预置数据完整性 |
| `workout_log_test.dart` | 训练记录与完成率 |
| `persistence_test.dart` | 存储往返 |
| `user_store_test.dart` | 状态管理 |
| `home_dashboard_test.dart` | 首页组件 |
| `ai_parse_test.dart` | AI 返回 JSON 解析容错 |
| `widget_test.dart` | 应用启动 |

测试里发现并修掉的两个真 bug：
1. 连续保存预置计划副本时毫秒时间戳撞车，第二份覆盖第一份 —— 加自增计数器
2. 本周训练计数用 `isAfter(monday)` 严格比较，漏掉周一零点整的记录 —— 改 `!isBefore`

---

## 八、开发进度

**已完成**

- 用户资料与健身目标设定
- 4 套预置训练计划 + AI 生成个性化计划
- 训练执行：计组、休息倒计时、记录重量
- 训练中断恢复（草稿持久化）
- 当前计划置顶首页，推荐今天该练哪一天
- 训练日编辑（改参数、删动作、调顺序）
- 动作详解（步骤 + 常见错误）
- 饮食记录：70 条食物库 + 自建食物 + AI 识别
- 四张数据图表

**未做**

- 云端同步（当前纯本地，换设备数据不跟随）
- 训练提醒通知
- 社交分享
- `screens/auth/` 目录为空，没做登录注册

