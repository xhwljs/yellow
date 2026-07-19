/// App-wide constants
class AppConstants {
  AppConstants._();

  // App
  static const String appName = 'VideoHub';
  static const String appVersion = '1.0.0';

  // API base URL（默认源站点根路径）
  //
  // 实测：
  // - http://555973.xyz/ 是跳转壳（返回 JS 跳转到 cktongji.com，无视频内容）
  // - http://555974.xyz/ 是真正的源站（返回含 .stui-vodlist__box 的视频列表 HTML）
  // - https://shturl.cc/idpALdXm 是短链，需要 JS 跳转，Dio 无法处理
  //
  // 因此默认用 555974.xyz；用户可在设置页运行时切换到其他镜像（keyApiBaseUrl）。
  static const String defaultBaseUrl = 'http://555974.xyz';

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
  static const Duration decryptCountdown = Duration(seconds: 6);

  // 缓存
  static const int cacheMaxAgeMinutes = 30;
  static const int historyMaxRecords = 500;

  // 数据库
  static const String databaseName = 'videohub.db';
  static const int databaseVersion = 1;

  // SharedPreferences keys
  static const String keyThemePreset = 'theme_preset';
  static const String keyLastCategoryId = 'last_category_id';
  static const String keyApiBaseUrl = 'api_base_url';
}
