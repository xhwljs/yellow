/// App-wide constants
class AppConstants {
  AppConstants._();

  // App
  static const String appName = 'Yellow Depot';
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
  //
  // version 1: 初始版本
  // version 2: 升级 CategoryParser 解析首页"目录"区块（.stui-pannel__menu）
  //            旧版本缓存的 Category 表只有导航菜单分类（count=0），
  //            migration 2→1 清空 Category + Video 表强制重新拉取
  static const String databaseName = 'videohub.db';
  static const int databaseVersion = 2;

  // SharedPreferences keys
  static const String keyThemePreset = 'theme_preset';
  static const String keyLastCategoryId = 'last_category_id';
  static const String keyApiBaseUrl = 'api_base_url';
  static const String keySearchHistory = 'search_history';

  /// 上次成功下载并安装的 GitHub Release tag（强制更新模式）
  ///
  /// 用于 [GitHubReleaseService.checkForUpdate] 判断是否需要更新：
  /// - 启动时读取 latest release tag，与本字段比较
  /// - 相同 → 已是最新版本，跳过更新
  /// - 不同（或本字段为空）→ 触发强制更新
  /// - 在 [AppUpdateService.downloadAndInstall] 下载成功后写入此字段
  ///
  /// 之所以不直接用 [AppConstants.appVersion]：
  /// AppConstants.appVersion 是硬编码常量（如 '1.0.0'），CI 不注入 tag，
  /// 更新后本地版本号仍是 1.0.0，会重复触发"发现新版本"。
  /// 用 SP 记录实际安装的 tag 可避免此问题。
  static const String keyLastInstalledReleaseTag = 'last_installed_release_tag';

  /// 首页"目录"区块分类 id 集合（来自 `.stui-pannel__menu`）
  ///
  /// 用于 [CategoryRepository] 启动时给从数据库读取的 Category 标记
  /// isCatalog 字段（数据库不持久化此字段，需用 id 集合在内存中重建分组）。
  /// 序列化格式：逗号分隔的 int 字符串，如 "8,9,10,15,21,26,7"
  static const String keyCatalogCategoryIds = 'catalog_category_ids';
}
