/// 人机验证页检测工具
///
/// 源站前置 WAF 偶尔会拦截请求，返回"滑动验证"人机验证页
/// （HTTP 200 + 验证 HTML，而非业务页面），导致：
/// - 根域名解析拿不到 Location / 跳转壳 → 域名获取失败
/// - 列表 / 详情页解析不到任何数据 → 页面空白
///
/// WAF 验证多为概率性触发（请求频率 / UA 特征建模），无 JS 引擎的
/// 客户端通用绕过手段：换 UA + 回带响应 Cookie + 随机延迟重试。
///
/// 实测样本（2026-09-16）特征：
/// - `<title>滑动验证</title>`
/// - class `slideBox` / `slider`
/// - 文本"人机身份验证，请完成以下操作"
/// - 引用 `/huadong_<hash>.js` 脚本（华东节点 WAF）
class HumanVerificationDetector {
  HumanVerificationDetector._();

  /// 验证页特征关键字
  ///
  /// 命中 2 个及以上才判定为验证页，避免正常页面误伤
  /// （如影片简介可能含"验证"字样，但不会同时命中多个特征）。
  static const List<String> _markers = [
    '滑动验证',
    '人机身份验证',
    '人机验证',
    '请完成以下操作',
    'slideBox',
    'huadong_',
    'geetest',
    'captcha-container',
  ];

  /// 检测 HTML 是否为人机验证页
  ///
  /// 空内容 / 超长内容（正常业务页远大于 4KB）直接排除。
  static bool isVerificationPage(String? html) {
    if (html == null || html.isEmpty) return false;
    // 验证页都很小（实测 < 1KB）；正常列表 / 详情页远大于此
    if (html.length > 4000) return false;
    var hits = 0;
    for (final marker in _markers) {
      if (html.contains(marker)) hits++;
      if (hits >= 2) return true;
    }
    return false;
  }
}
