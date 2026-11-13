import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// AI 调用失败，message 是给用户看的中文提示
class AiBackendException implements Exception {
  final String message;
  const AiBackendException(this.message);

  @override
  String toString() => message;
}

/// 统一的 AI 调用入口
///
/// 客户端不直接调 DeepSeek，而是走 Supabase Edge Function `ai-chat`。
/// DeepSeek 的 API Key 存在服务端 Secret 里，用户不用自己填 key，
/// 只需登录（Edge Function 会校验登录态）。
///
/// 三个 AI 服务（计划 / 食物估算 / 今日分析）都通过这里发请求，
/// 之前各自的 HTTP 逻辑和错误处理统一收敛到这里。
class AiBackend {
  /// 调用 DeepSeek 聊天接口，返回模型输出的文本 content
  ///
  /// 失败时抛 [AiBackendException]，message 可直接展示给用户。
  static Future<String> chat({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
    bool jsonObject = false,
  }) async {
    // 未登录直接拦住，别浪费一次请求
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw const AiBackendException('请先登录后再使用 AI 功能');
    }

    final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/ai-chat');

    final body = {
      'model': 'deepseek-chat',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (jsonObject) 'response_format': {'type': 'json_object'},
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            // 中文必须显式 utf8 编码
            body: utf8.encode(jsonEncode(body)),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw AiBackendException(_httpError(response));
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      // Edge Function 可能返回 { error } 包一层
      if (data['error'] != null) {
        throw AiBackendException(data['error'].toString());
      }

      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw const AiBackendException('AI 没有返回内容，请重试');
      }

      final content =
          (choices.first as Map)['message']?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const AiBackendException('AI 返回了空内容，请重试');
      }

      return content;
    } on AiBackendException {
      rethrow;
    } on http.ClientException catch (e) {
      throw AiBackendException('网络请求失败：${e.message}');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('TimeoutException')) {
        throw const AiBackendException('请求超时，网络可能不稳定，请重试');
      }
      throw AiBackendException('请求失败：$msg');
    }
  }

  /// 把 HTTP 错误转成用户能看懂的中文
  static String _httpError(http.Response response) {
    final code = response.statusCode;
    // 先看 Edge Function 有没有带 error 说明
    try {
      final map = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final msg = map['error'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}

    switch (code) {
      case 401:
        return '登录已失效，请重新登录';
      case 402:
        return 'AI 服务余额不足，请联系管理员';
      case 429:
        return '请求太频繁，等一会儿再试';
      case 500:
      case 502:
      case 503:
        return 'AI 服务暂时不可用，稍后重试';
      default:
        return '请求失败，错误码 $code';
    }
  }
}
