import 'dart:convert';

import '../models/food_item.dart';
import 'ai_backend.dart';

/// AI 食物营养估算服务
///
/// 用户描述吃了什么（文字），DeepSeek 返回估算的营养成分。
/// 用在内置食物库查不到的时候 —— 自制菜、外卖、地方小吃。
///
/// 为什么只做文字不做拍照：
/// DeepSeek 目前没有视觉模型，识图要换厂商（智谱 GLM-4.6V / 豆包）。
/// 文字描述其实够用而且更准 —— 用户知道自己放了多少油，
/// 照片反而看不出来。拍照识别留作后续接入视觉模型时再加。
class AiFoodService {
  /// 估算食物营养
  ///
  /// [description] 用户的描述，比如「食堂的番茄炒蛋，一盘」
  static Future<AiFoodResult> estimate({
    required String description,
  }) async {
    final desc = description.trim();
    if (desc.isEmpty) {
      return AiFoodResult.failure('请先描述你吃了什么');
    }

    try {
      final content = await AiBackend.chat(
        systemPrompt: '你是一位营养师，擅长估算中餐的营养成分。'
            '你只返回 JSON，不说任何多余的话。',
        userPrompt: _buildPrompt(desc),
        // 营养估算要稳定，温度调低
        temperature: 0.3,
        maxTokens: 500,
        jsonObject: true,
      );

      return AiFoodResult.success(_parse(content));
    } on AiBackendException catch (e) {
      return AiFoodResult.failure(e.message);
    } on FormatException {
      return AiFoodResult.failure('AI 返回的格式不对，请重试一次');
    } catch (e) {
      return AiFoodResult.failure('估算失败：$e');
    }
  }

  static String _buildPrompt(String description) {
    // 分类的可选值要和 FoodCategory 的枚举名对齐，不然解析时匹配不上
    final categories =
        FoodCategory.values.map((c) => '"${c.name}"（${c.label}）').join('、');

    return '''
用户吃的食物：$description

请估算这份食物的营养成分。

要求：
1. **每 100 克的营养成分**，这是食物营养表的通用口径
2. **estimatedGrams 填这一份大概多少克** —— 用户描述里如果提到份量
   （一盘、一碗、一个），按常见分量估算；没提就给一个典型值
3. 中餐要考虑烹饪用油：炒菜比清蒸热量高不少，红烧比白煮高
4. 如果描述太模糊（比如只说「饭」），按最常见的情况估，
   并在 note 里说明你假设的是什么
5. category 从这些里选一个：$categories

严格按下面的 JSON 结构返回，不要加任何额外文字或 markdown 代码块标记：

{
  "name": "食物名称，简洁一点",
  "category": "分类的英文名",
  "caloriesPer100g": 120,
  "proteinPer100g": 8.5,
  "carbsPer100g": 10.2,
  "fatPer100g": 5.0,
  "estimatedGrams": 250,
  "portionHint": "一份约250克",
  "note": "估算说明，20字内，说清你假设了什么"
}

只返回 JSON。
''';
  }

  /// 解析 AI 返回的 JSON
  static AiFoodEstimate _parse(String jsonText) {
    final cleaned = _stripCodeFence(jsonText);
    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    return AiFoodEstimate(
      food: FoodItem(
        // 标明来源，和内置、用户自建的区分开
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        name: map['name'] as String? ?? '未知食物',
        category: _parseCategory(map['category'] as String?),
        // 用 num 兜住：模型可能返回整数或小数
        caloriesPer100g: _toDouble(map['caloriesPer100g']),
        proteinPer100g: _toDouble(map['proteinPer100g']),
        carbsPer100g: _toDouble(map['carbsPer100g']),
        fatPer100g: _toDouble(map['fatPer100g']),
        portionHint: map['portionHint'] as String?,
        // 份量为 0 不合理，退回 100
        defaultGrams: _toDouble(map['estimatedGrams'], 100),
      ),
      note: map['note'] as String?,
    );
  }

  /// 去掉 markdown 代码块包裹
  ///
  /// 要求了只返回 JSON，但模型偶尔还是会套一层 ```json
  static String _stripCodeFence(String text) {
    var s = text.trim();

    if (s.startsWith('```')) {
      final firstNewline = s.indexOf('\n');
      if (firstNewline != -1) s = s.substring(firstNewline + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }

    return s.trim();
  }

  static double _toDouble(dynamic v, [double fallback = 0]) {
    if (v is num) {
      final d = v.toDouble();
      // 负数和离谱的大值都当无效
      return (d >= 0 && d < 10000) ? d : fallback;
    }
    if (v is String) {
      final parsed = double.tryParse(v.trim());
      if (parsed != null && parsed >= 0) return parsed;
    }
    return fallback;
  }

  /// 字符串转分类枚举
  ///
  /// 按枚举的 name 匹配（staple / protein / ...），
  /// 认不出来就归到「其他」
  static FoodCategory _parseCategory(String? value) {
    final v = value?.trim().toLowerCase();
    if (v == null || v.isEmpty) return FoodCategory.other;

    for (final c in FoodCategory.values) {
      if (c.name.toLowerCase() == v) return c;
    }
    return FoodCategory.other;
  }
}

/// AI 估算出的食物
class AiFoodEstimate {
  /// 估算出的食物条目
  final FoodItem food;

  /// AI 的估算说明，比如「假设是家常做法，用了少量油」
  final String? note;

  const AiFoodEstimate({required this.food, this.note});
}

/// 估算结果
///
/// 成功和失败用一个类表示，调用方先判断 success —— 界面上要显示
/// 具体错误文案，抛异常反而不好处理
class AiFoodResult {
  final bool success;
  final AiFoodEstimate? estimate;
  final String? error;

  const AiFoodResult._({required this.success, this.estimate, this.error});

  factory AiFoodResult.success(AiFoodEstimate estimate) =>
      AiFoodResult._(success: true, estimate: estimate);

  factory AiFoodResult.failure(String error) =>
      AiFoodResult._(success: false, error: error);
}
