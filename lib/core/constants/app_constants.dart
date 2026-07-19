/// App-wide constants
class AppConstants {
  AppConstants._();

  // App
  static const String appName = 'VideoHub';
  static const String appVersion = '1.0.0';

  // API base URL（用户提供的源站点根路径）
  static const String baseUrl = 'https://shturl.cc/idpALdXm';

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
}
