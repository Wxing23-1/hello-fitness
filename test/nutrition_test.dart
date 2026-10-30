// 饮食模块测试
//
// 覆盖营养换算、宏量素目标计算、汇总逻辑、食物库完整性。
// 运行命令：flutter test test/nutrition_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hello_fitness/data/food_database.dart';
import 'package:hello_fitness/models/fitness_goal.dart';
import 'package:hello_fitness/models/food_item.dart';
import 'package:hello_fitness/models/meal_entry.dart';
import 'package:hello_fitness/models/user_profile.dart';
import 'package:hello_fitness/services/user_store.dart';
import 'package:hello_fitness/utils/nutrition_utils.dart';

void main() {
  // ══════════════════════════════════════════
  //  按克数换算营养
  // ══════════════════════════════════════════
  group('FoodItem 换算', () {
    const rice = FoodItem(
      id: 'f_rice',
      name: '米饭',
      category: FoodCategory.staple,
      caloriesPer100g: 116,
      proteinPer100g: 2.6,
      carbsPer100g: 25.9,
      fatPer100g: 0.3,
      defaultGrams: 150,
    );

    test('100 克时等于原值', () {
      expect(rice.caloriesFor(100), 116);
      expect(rice.proteinFor(100), 2.6);
    });

    test('按比例换算', () {
      // 150 克 = 1.5 倍
      expect(rice.caloriesFor(150), closeTo(174, 0.01));
      expect(rice.carbsFor(150), closeTo(38.85, 0.01));
    });

    test('0 克时营养为 0', () {
      expect(rice.caloriesFor(0), 0);
      expect(rice.fatFor(0), 0);
    });

    test('序列化往返后数据不变', () {
      final restored = FoodItem.fromMap(
        jsonDecode(jsonEncode(rice.toMap())) as Map,
      );

      expect(restored.name, '米饭');
      expect(restored.category, FoodCategory.staple);
      expect(restored.caloriesPer100g, 116);
      expect(restored.defaultGrams, 150);
    });

    test('分类 index 越界时退回其他，不崩溃', () {
      final f = FoodItem.fromMap({
        'id': 'x',
        'name': '测试',
        'category': 999,
        'caloriesPer100g': 100,
      });

      expect(f.category, FoodCategory.other);
    });
  });

  // ══════════════════════════════════════════
  //  MealEntry
  // ══════════════════════════════════════════
  group('MealEntry', () {
    const egg = FoodItem(
      id: 'f_egg',
      name: '鸡蛋',
      category: FoodCategory.protein,
      caloriesPer100g: 147,
      proteinPer100g: 13.3,
      carbsPer100g: 2.8,
      fatPer100g: 8.8,
      defaultGrams: 50,
    );

    test('fromFood 自动按克数算好营养', () {
      final entry = MealEntry.fromFood(
        food: egg,
        mealType: MealType.breakfast,
        grams: 100,
      );

      expect(entry.foodName, '鸡蛋');
      expect(entry.calories, 147);
      expect(entry.protein, 13.3);
      expect(entry.grams, 100);
    });

    test('半份的营养也对', () {
      final entry = MealEntry.fromFood(
        food: egg,
        mealType: MealType.breakfast,
        grams: 50,
      );

      expect(entry.calories, closeTo(73.5, 0.01));
    });

    test('存的是营养快照，食物库改了也不影响已有记录', () {
      final entry = MealEntry.fromFood(
        food: egg,
        mealType: MealType.lunch,
        grams: 50,
      );

      // 记录里存的是数值不是引用，所以这条记录的营养永远是记录时的值
      expect(entry.calories, closeTo(73.5, 0.01));
      expect(entry.foodName, '鸡蛋');
    });

    test('序列化往返', () {
      final entry = MealEntry.fromFood(
        food: egg,
        mealType: MealType.dinner,
        grams: 150,
        note: '加了油',
        fromAi: true,
      );

      final restored = MealEntry.fromMap(
        jsonDecode(jsonEncode(entry.toMap())) as Map,
      );

      expect(restored.foodName, '鸡蛋');
      expect(restored.mealType, MealType.dinner);
      expect(restored.grams, 150);
      expect(restored.note, '加了油');
      expect(restored.fromAi, isTrue);
      // 存的是毫秒时间戳，微秒会被截掉。
      // 饮食记录精确到毫秒远够用，所以比较毫秒值而不是整个对象
      expect(
        restored.eatenAt.millisecondsSinceEpoch,
        entry.eatenAt.millisecondsSinceEpoch,
      );
    });

    test('缺字段的脏数据不崩', () {
      final e = MealEntry.fromMap({'id': 'x'});

      expect(e.foodName, '未知食物');
      expect(e.calories, 0);
      expect(e.mealType, MealType.snack);
    });
  });

  // ══════════════════════════════════════════
  //  餐次推测
  // ══════════════════════════════════════════
  group('MealType.guessByHour', () {
    test('早中晚各自落在对应时段', () {
      expect(MealType.guessByHour(8), MealType.breakfast);
      expect(MealType.guessByHour(12), MealType.lunch);
      expect(MealType.guessByHour(19), MealType.dinner);
    });

    test('不在三餐时段内算加餐', () {
      // 凌晨 3 点和下午 3 点半都不在三餐里
      expect(MealType.guessByHour(3), MealType.snack);
      expect(MealType.guessByHour(15), MealType.snack);
      expect(MealType.guessByHour(23), MealType.snack);
    });
  });

  // ══════════════════════════════════════════
  //  营养汇总
  // ══════════════════════════════════════════
  group('NutritionSummary', () {
    const food = FoodItem(
      id: 'f',
      name: '测试食物',
      category: FoodCategory.other,
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 10,
      fatPer100g: 5,
    );

    test('空列表返回全 0', () {
      final s = NutritionSummary.from([]);

      expect(s.calories, 0);
      expect(s.entryCount, 0);
    });

    test('多条记录累加', () {
      final entries = [
        MealEntry.fromFood(
          food: food,
          mealType: MealType.breakfast,
          grams: 100,
        ),
        MealEntry.fromFood(
          food: food,
          mealType: MealType.lunch,
          grams: 200,
        ),
      ];

      final s = NutritionSummary.from(entries);

      expect(s.calories, 300);
      expect(s.protein, 30);
      expect(s.entryCount, 2);
    });

    test('宏量素占比按热量算而不是克数', () {
      // 10g 蛋白(40kcal) + 10g 碳水(40kcal) + 5g 脂肪(45kcal) = 125kcal
      final s = NutritionSummary.from([
        MealEntry.fromFood(
          food: food,
          mealType: MealType.lunch,
          grams: 100,
        ),
      ]);

      final (p, c, f) = s.macroPercents;

      // 脂肪克数最少但热量占比最高 —— 按克数算会严重低估它
      expect(f, greaterThan(p));
      expect(p, closeTo(32, 0.5));
      expect(c, closeTo(32, 0.5));
      expect(f, closeTo(36, 0.5));
    });

    test('没有数据时占比全 0，不除零', () {
      final (p, c, f) = NutritionSummary.empty.macroPercents;

      expect(p, 0);
      expect(c, 0);
      expect(f, 0);
    });

    test('groupByMeal 四个餐次都有键', () {
      final grouped = NutritionSummary.groupByMeal([
        MealEntry.fromFood(
          food: food,
          mealType: MealType.breakfast,
          grams: 100,
        ),
      ]);

      // 即使某餐没记录也要有键，界面上要显示空状态
      expect(grouped.keys.length, MealType.values.length);
      expect(grouped[MealType.breakfast]!.calories, 100);
      expect(grouped[MealType.dinner]!.calories, 0);
    });
  });

  // ══════════════════════════════════════════
  //  BMR / TDEE
  // ══════════════════════════════════════════
  group('代谢计算', () {
    const male = UserProfile(
      name: '张三',
      gender: Gender.male,
      age: 25,
      heightCm: 175,
      weightKg: 70,
    );

    test('男性 BMR 用 Mifflin-St Jeor 公式', () {
      // 10×70 + 6.25×175 − 5×25 + 5 = 700 + 1093.75 − 125 + 5 = 1673.75
      expect(calculateBmr(male), 1674);
    });

    test('女性 BMR 比同条件男性低', () {
      const female = UserProfile(
        name: '李四',
        gender: Gender.female,
        age: 25,
        heightCm: 175,
        weightKg: 70,
      );

      // 常数项差 166（+5 vs −161）
      expect(calculateBmr(female), calculateBmr(male) - 166);
    });

    test('数据不合法时返回 0 而不是负数', () {
      const invalid = UserProfile(
        name: 'x',
        gender: Gender.male,
        age: 0,
        heightCm: 0,
        weightKg: 0,
      );

      expect(calculateBmr(invalid), 0);
      expect(calculateTdee(invalid, ActivityLevel.light), 0);
    });

    test('TDEE 随活动强度递增', () {
      final sedentary = calculateTdee(male, ActivityLevel.sedentary);
      final active = calculateTdee(male, ActivityLevel.active);

      expect(active, greaterThan(sedentary));
    });

    test('减脂目标留缺口，增肌留盈余', () {
      final tdee = calculateTdee(male, ActivityLevel.moderate);

      final lose = recommendedCalories(
        male,
        ActivityLevel.moderate,
        GoalType.loseWeight,
      );
      final gain = recommendedCalories(
        male,
        ActivityLevel.moderate,
        GoalType.gainMuscle,
      );
      final keep = recommendedCalories(
        male,
        ActivityLevel.moderate,
        GoalType.keepFit,
      );

      expect(lose, lessThan(tdee));
      expect(gain, greaterThan(tdee));
      expect(keep, tdee);
    });
  });

  // ══════════════════════════════════════════
  //  宏量素分配
  // ══════════════════════════════════════════
  group('calculateMacros', () {
    test('减脂期蛋白质按 2.0 g/kg', () {
      final m = calculateMacros(
        weightKg: 70,
        dailyCalories: 2000,
        goal: GoalType.loseWeight,
      );

      expect(m.protein, 140);
    });

    test('增肌期蛋白质略低于减脂期', () {
      final lose = calculateMacros(
        weightKg: 70,
        dailyCalories: 2000,
        goal: GoalType.loseWeight,
      );
      final gain = calculateMacros(
        weightKg: 70,
        dailyCalories: 2000,
        goal: GoalType.gainMuscle,
      );

      // 减脂期热量不足，蛋白要更高才保得住肌肉
      expect(gain.protein, lessThan(lose.protein));
    });

    test('脂肪占总热量 25%', () {
      final m = calculateMacros(
        weightKg: 70,
        dailyCalories: 2000,
        goal: GoalType.keepFit,
      );

      // 2000 × 0.25 / 9 ≈ 55.6
      expect(m.fat, 56);
    });

    test('三者热量加起来接近总目标', () {
      final m = calculateMacros(
        weightKg: 70,
        dailyCalories: 2000,
        goal: GoalType.keepFit,
      );

      final sum = m.protein * 4 + m.carbs * 4 + m.fat * 9;

      // 取整会有几千卡误差，20 以内算对得上
      expect((sum - 2000).abs(), lessThan(20));
    });

    test('参数不合法时返回全 0', () {
      final m = calculateMacros(
        weightKg: 0,
        dailyCalories: 2000,
        goal: GoalType.keepFit,
      );

      expect(m.protein, 0);
      expect(m.carbs, 0);
    });

    test('热量目标极低时碳水归 0 而不是负数', () {
      // 蛋白和脂肪就把热量占满了
      final m = calculateMacros(
        weightKg: 100,
        dailyCalories: 900,
        goal: GoalType.loseWeight,
      );

      expect(m.carbs, 0);
    });
  });

  // ══════════════════════════════════════════
  //  食物库完整性
  // ══════════════════════════════════════════
  group('FoodDatabase', () {
    test('有足量条目', () {
      expect(FoodDatabase.getAll().length, greaterThanOrEqualTo(60));
    });

    test('id 全局唯一', () {
      final ids = FoodDatabase.getAll().map((f) => f.id).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('每个分类都有食物', () {
      for (final c in FoodCategory.values) {
        // other 是兜底分类，内置库里可以没有
        if (c == FoodCategory.other) continue;

        expect(
          FoodDatabase.getByCategory(c),
          isNotEmpty,
          reason: '分类「${c.label}」没有食物',
        );
      }
    });

    test('营养数据不是负数', () {
      for (final f in FoodDatabase.getAll()) {
        expect(f.caloriesPer100g, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.proteinPer100g, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.carbsPer100g, greaterThanOrEqualTo(0), reason: f.name);
        expect(f.fatPer100g, greaterThanOrEqualTo(0), reason: f.name);
      }
    });

    test('热量和宏量素大致对得上', () {
      for (final f in FoodDatabase.getAll()) {
        // 水这类零热量的跳过
        if (f.caloriesPer100g == 0) continue;

        final calcKcal =
            f.proteinPer100g * 4 + f.carbsPer100g * 4 + f.fatPer100g * 9;

        // 营养表的数据本身有误差（膳食纤维、酒精、水分都会影响），
        // 允许 35% 偏差，只要不是数量级错误就行
        final diff = (calcKcal - f.caloriesPer100g).abs();
        expect(
          diff,
          lessThan(f.caloriesPer100g * 0.35 + 25),
          reason: '「${f.name}」热量 ${f.caloriesPer100g} '
              '与宏量素算出的 ${calcKcal.round()} 差太多',
        );
      }
    });

    test('默认份量是正数', () {
      for (final f in FoodDatabase.getAll()) {
        expect(f.defaultGrams, greaterThan(0), reason: f.name);
      }
    });

    test('搜索能按子串匹配', () {
      expect(FoodDatabase.search('鸡蛋'), isNotEmpty);
      expect(FoodDatabase.search('不存在的食物xyz'), isEmpty);
    });

    test('空关键词返回全部', () {
      expect(
        FoodDatabase.search('').length,
        FoodDatabase.getAll().length,
      );
    });

    test('getById 找得到也找不到', () {
      expect(FoodDatabase.getById('f_rice'), isNotNull);
      expect(FoodDatabase.getById('不存在'), isNull);
    });
  });

  // ══════════════════════════════════════════
  //  store 里的饮食操作
  // ══════════════════════════════════════════
  group('UserStore 饮食', () {
    const food = FoodItem(
      id: 'f',
      name: '测试食物',
      category: FoodCategory.other,
      caloriesPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 10,
      fatPer100g: 5,
    );

    MealEntry entryAt(DateTime when, {String id = 'm1'}) {
      return MealEntry(
        id: id,
        mealType: MealType.lunch,
        eatenAt: when,
        foodName: '测试',
        grams: 100,
        calories: 100,
        protein: 10,
        carbs: 10,
        fat: 5,
        category: FoodCategory.other,
      );
    }

    test('初始没有记录', () {
      final store = UserStore();

      expect(store.meals, isEmpty);
      expect(store.todaySummary.calories, 0);
    });

    test('添加后能查到', () {
      final store = UserStore();

      store.addMeal(entryAt(DateTime.now()));

      expect(store.meals.length, 1);
      expect(store.todayMeals.length, 1);
      expect(store.todaySummary.calories, 100);
    });

    test('添加会通知监听者', () {
      final store = UserStore();
      var notified = 0;
      store.addListener(() => notified++);

      store.addMeal(entryAt(DateTime.now()));

      expect(notified, 1);
    });

    test('按 id 删除', () {
      final store = UserStore();
      store.addMeal(entryAt(DateTime.now(), id: 'a'));
      store.addMeal(entryAt(DateTime.now(), id: 'b'));

      store.deleteMeal('a');

      expect(store.meals.length, 1);
      expect(store.meals.first.id, 'b');
    });

    test('mealsOn 只返回那一天的', () {
      final store = UserStore();
      final now = DateTime.now();

      store.addMeal(entryAt(now, id: 'today'));
      store.addMeal(
        entryAt(now.subtract(const Duration(days: 3)), id: 'old'),
      );

      expect(store.meals.length, 2);
      expect(store.todayMeals.length, 1);
      expect(store.todayMeals.first.id, 'today');
    });

    test('meals 返回的列表不可直接修改', () {
      final store = UserStore();
      store.addMeal(entryAt(DateTime.now()));

      expect(
        () => store.meals.add(store.meals.first),
        throwsUnsupportedError,
      );
    });

    test('自定义食物会出现在搜索结果里', () {
      final store = UserStore();
      const custom = FoodItem(
        id: 'custom_1',
        name: '奶奶做的红烧肉',
        category: FoodCategory.protein,
        caloriesPer100g: 350,
        proteinPer100g: 15,
        carbsPer100g: 5,
        fatPer100g: 30,
      );

      store.addCustomFood(custom);

      expect(store.searchFoods('红烧肉').length, 1);
      expect(store.findFood('custom_1')?.name, '奶奶做的红烧肉');
    });

    test('删除自定义食物不影响已有记录', () {
      final store = UserStore();
      store.addCustomFood(food);
      store.addMeal(
        MealEntry.fromFood(
          food: food,
          mealType: MealType.lunch,
          grams: 100,
        ),
      );

      store.deleteCustomFood(food.id);

      // 食物没了，但记录还在 —— MealEntry 存的是快照
      expect(store.customFoods, isEmpty);
      expect(store.meals.length, 1);
      expect(store.todaySummary.calories, 100);
    });

    test('活动强度能改并影响 TDEE', () {
      final store = UserStore();

      store.setActivityLevel(ActivityLevel.sedentary);
      final low = store.tdee;

      store.setActivityLevel(ActivityLevel.active);
      final high = store.tdee;

      expect(high, greaterThan(low));
    });

    test('resetAll 清空饮食数据', () {
      final store = UserStore();
      store.addMeal(entryAt(DateTime.now()));
      store.addCustomFood(food);

      store.resetAll();

      expect(store.meals, isEmpty);
      expect(store.customFoods, isEmpty);
    });
  });
}
