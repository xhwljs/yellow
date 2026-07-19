/// App-wide constants
class AppConstants {
  AppConstants._();

  // App
  static const String appName = 'VideoHub';
  static const String appVersion = '1.0.0';

  // API base URL（默认源站点根路径）
  //
  // 实测（2026-07-19）：
  // - http://555976.xyz/ ✅ 当前真实源站（返回含 .stui-vodlist__box 的视频列表 HTML）
  // - http://555975.xyz/ ❌ 已变为跳转壳（JS 跳转到 cktongji.com:8899，Dio 无法处理）
  // - http://555974.xyz/ ❌ 已变跳转壳（JS 跳转到 cktongji.com:8899 → 404）
  // - http://555973.xyz/ ❌ 已是跳转壳
  // - https://shturl.cc/idpALdXm 是短链，需要 JS 跳转，Dio 无法处理
  //
  // 因此默认用 555976.xyz；用户可在设置页运行时切换到其他镜像（keyApiBaseUrl）。
  // 历史镜像在 [ApiServerSwitcher._deadMirrors] 中维护，启动时自动迁移到默认值。
  static const String defaultBaseUrl = 'http://555976.xyz';

  /// 当前生效的 baseUrl（运行时可通过 SharedPreferences 覆盖）
  static String baseUrl = defaultBaseUrl;

  // 网络
  static const int connectTimeoutMs = 30 * 1000;
  static const int receiveTimeoutMs = 30 * 1000;
  static const int sendTimeoutMs = 30 * 1000;
  static const int maxRetryCount = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // 反爬：请求间隔 ≥ 2 秒
  static const Duration requestInterval = Duration(seconds: 2);

  // 播放器
  static const List<double> playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // 缓存
  static const int cacheMaxAgeMinutes = 30;
  static const int historyMaxRecords = 500;
  // 搜索历史最多保存数量（去重后按时间倒序保留前 N 条）
  static const int searchHistoryMax = 20;

  // 数据库
  static const String databaseName = 'videohub.db';
  static const int databaseVersion = 1;

  // SharedPreferences keys
  static const String keyThemePreset = 'theme_preset';
  static const String keyLastCategoryId = 'last_category_id';
  static const String keyApiBaseUrl = 'api_base_url';
  static const String keySearchHistory = 'search_history';
}
