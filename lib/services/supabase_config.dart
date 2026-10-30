/// Supabase 连接配置
///
/// 这里的 anon key 是「匿名公开密钥」，本来就是要随 App 一起分发、
/// 给未登录用户用的，不属于机密。真正的服务端密钥 service_role 绝对不能放进来。
///
/// 数据库表结构（SQL）见项目根目录 supabase_schema.sql：
///   profiles / workout_logs / meal_entries / weight_logs /
///   community_posts / post_likes + Storage bucket `avatars`
class SupabaseConfig {
  /// 项目地址（Project Settings → API → Project URL）
  static const String url = 'https://zifruhulyrflbqecvxnt.supabase.co';

  /// 匿名公开密钥（Project Settings → API → anon public）
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InppZnJ1aHVseXJmbGJxZWN2eG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMzMzQ4NTAsImV4cCI6MjEwODkxMDg1MH0.'
      'fwVJZ2DTMf9h2kx3AGVTtPT3-pC4H7lAbyZDa8SppDs';
}
