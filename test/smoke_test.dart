import 'package:flutter_test/flutter_test.dart';
import 'package:videohub/core/theme/design_tokens.dart';
import 'package:videohub/core/theme/theme_presets.dart';
import 'package:videohub/data/models/category.dart';
import 'package:videohub/data/models/video.dart';

/// Smoke 测试 — 验证核心数据模型与设计 tokens 基础契约。
///
/// 不涉及平台插件 / 数据库 / 网络，可在 CI 无设备环境跑通。
void main() {
  group('Category 模型', () {
    test('toMap / fromMap 双向序列化应等价', () {
      const c = Category(
        id: 12,
        name: '动作',
        url: '/vodtype/12.html',
        count: 99,
      );
      final map = c.toMap();
      final restored = Category.fromMap(map);

      expect(restored.id, 12);
      expect(restored.name, '动作');
      expect(restored.url, '/vodtype/12.html');
      expect(restored.count, 99);
    });

    test('copyWith 仅覆盖传入字段', () {
      const c = Category(
        id: 1,
        name: '剧情',
        url: '/vodtype/1.html',
        count: 0,
      );
      final updated = c.copyWith(count: 50);

      expect(updated.id, 1);
      expect(updated.name, '剧情');
      expect(updated.count, 50);
    });
  });

  group('Video 模型', () {
    test('字段应正确赋值', () {
      const v = Video(
        id: 'abc123',
        title: '示例视频',
        coverUrl: 'https://example.com/cover.jpg',
        duration: '90:00',
        updateTime: '2024-01-01',
        playCount: 1000,
        likeCount: 200,
        categoryId: 5,
      );

      expect(v.id, 'abc123');
      expect(v.title, '示例视频');
      expect(v.playCount, 1000);
      expect(v.categoryId, 5);
    });
  });

  group('ThemePreset 主题预设', () {
    test('应有 5 套预设', () {
      expect(ThemePreset.values.length, 5);
    });

    test('fromId 应支持往返', () {
      for (final preset in ThemePreset.values) {
        expect(ThemePreset.fromId(preset.id), preset);
      }
    });

    test('未知 id 应回退到 pink', () {
      expect(ThemePreset.fromId('not-exist'), ThemePreset.pink);
    });

    test('每个预设应有不同的 primaryColor', () {
      final colors = ThemePreset.values
          .map((p) => p.primaryColor.value)
          .toSet();
      expect(colors.length, ThemePreset.values.length);
    });
  });

  group('DesignTokens 设计 tokens', () {
    test('间距应单调递增', () {
      expect(DesignTokens.spaceXs, lessThan(DesignTokens.spaceSm));
      expect(DesignTokens.spaceSm, lessThan(DesignTokens.spaceMd));
      expect(DesignTokens.spaceMd, lessThan(DesignTokens.spaceLg));
      expect(DesignTokens.spaceLg, lessThan(DesignTokens.spaceXl));
    });

    test('圆角应单调递增', () {
      expect(DesignTokens.radiusSm, lessThan(DesignTokens.radiusMd));
      expect(DesignTokens.radiusMd, lessThan(DesignTokens.radiusLg));
      expect(DesignTokens.radiusLg, lessThan(DesignTokens.radiusXl));
    });
  });
}
