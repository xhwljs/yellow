import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/utils/number_formatter.dart';

/// NumberFormatter 单测 — 覆盖边界值与单位切换。
void main() {
  group('NumberFormatter.formatCount', () {
    test('0 应原样输出', () {
      expect(NumberFormatter.formatCount(0), '0');
    });

    test('一位数应原样输出', () {
      expect(NumberFormatter.formatCount(5), '5');
    });

    test('9999 应原样输出（未达万）', () {
      expect(NumberFormatter.formatCount(9999), '9999');
    });

    test('10000 应显示为 1.0 万', () {
      expect(NumberFormatter.formatCount(10000), '1.0万');
    });

    test('12345 应显示为 1.2 万（向下截断到 1 位小数）', () {
      expect(NumberFormatter.formatCount(12345), '1.2万');
    });

    test('99999 应显示为 10.0 万', () {
      expect(NumberFormatter.formatCount(99999), '10.0万');
    });

    test('99999999 应显示为 10000.0 万（未达亿）', () {
      expect(NumberFormatter.formatCount(99999999), '10000.0万');
    });

    test('100000000 应显示为 1.0 亿', () {
      expect(NumberFormatter.formatCount(100000000), '1.0亿');
    });

    test('123456789 应显示为 1.2 亿', () {
      expect(NumberFormatter.formatCount(123456789), '1.2亿');
    });
  });

  group('NumberFormatter.formatBytes', () {
    test('0 应返回 0 B', () {
      expect(NumberFormatter.formatBytes(0), '0 B');
    });

    test('负数应返回 0 B', () {
      expect(NumberFormatter.formatBytes(-1), '0 B');
    });

    test('小于 1024 应保持 B 单位', () {
      expect(NumberFormatter.formatBytes(512), '512.0 B');
    });

    test('1024 应转换为 1.0 KB', () {
      expect(NumberFormatter.formatBytes(1024), '1.0 KB');
    });

    test('1536 应显示为 1.5 KB', () {
      expect(NumberFormatter.formatBytes(1536), '1.5 KB');
    });

    test('1048576 应转换为 1.0 MB', () {
      expect(NumberFormatter.formatBytes(1048576), '1.0 MB');
    });

    test('1073741824 应转换为 1.0 GB', () {
      expect(NumberFormatter.formatBytes(1073741824), '1.0 GB');
    });

    test('超过 GB 上限应保持在 GB 单位（不进 TB）', () {
      // units 数组只到 GB，超过 1024 GB 不再升级单位
      expect(NumberFormatter.formatBytes(1073741824 * 2048), '2048.0 GB');
    });
  });
}
