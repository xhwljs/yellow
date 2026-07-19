import 'dart:math';

/// 移动端 User-Agent 池
///
/// 反爬策略：每次请求从池中随机抽取一个移动端 UA。
class UserAgentUtils {
  UserAgentUtils._();

  static const List<String> _mobileUAs = [
    // iPhone Safari
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    // Android Chrome
    'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    // iPad
    'Mozilla/5.0 (iPad; CPU OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
  ];

  static final _random = Random();

  /// 随机返回一个移动端 UA
  static String random() {
    return _mobileUAs[_random.nextInt(_mobileUAs.length)];
  }

  /// 模拟随机屏幕坐标 x（点击坐标）
  static String randomX() {
    return _random.nextInt(200) + 100.toString(); // 100-300
  }

  /// 模拟随机屏幕坐标 y（点击坐标）
  static String randomY() {
    return _random.nextInt(400) + 100.toString(); // 100-500
  }

  /// 模拟随机屏幕宽度
  static const String screenWidth = '360';

  /// 模拟随机屏幕高度
  static const String screenHeight = '792';

  /// 时区
  static const String timezone = '-480';
}
