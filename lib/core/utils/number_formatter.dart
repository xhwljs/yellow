/// 数字格式化工具
///
/// 统一全 App 的数字展示规则，避免各页面重复实现导致行为不一致。
class NumberFormatter {
  NumberFormatter._();

  /// 格式化播放次数 / 收藏次数等计数。
  ///
  /// - >= 1亿：显示为 `1.2亿`
  /// - >= 1万：显示为 `1.2万`
  /// - 其他：原样输出
  static String formatCount(int n) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(1)}亿';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(1)}万';
    }
    return n.toString();
  }

  /// 格式化字节数为带单位的可读字符串。
  ///
  /// - 0 或负数：`0 B`
  /// - 自动选择 B / KB / MB / GB 单位，保留 1 位小数
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIdx = 0;
    while (size >= 1024 && unitIdx < units.length - 1) {
      size /= 1024;
      unitIdx++;
    }
    return '${size.toStringAsFixed(1)} ${units[unitIdx]}';
  }
}
