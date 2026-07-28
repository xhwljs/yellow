import 'package:flutter_test/flutter_test.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';

/// GitHubRelease.isNewerThan 版本比较单测。
///
/// 覆盖：v 前缀、多段版本号、不足段补 0、相等、空字符串、非数字段。
void main() {
  GitHubRelease releaseWithTag(String tag) {
    return GitHubRelease(
      tagName: tag,
      name: 'Release $tag',
      body: '',
      apkDownloadUrl: '',
      apkFileName: '',
      publishedAt: DateTime(2026),
      prerelease: false,
      forceUpdate: false,
    );
  }

  group('GitHubRelease.isNewerThan', () {
    test('release 版本更高应返回 true', () {
      expect(releaseWithTag('v1.0.1').isNewerThan('1.0.0'), isTrue);
    });

    test('release 版本更低应返回 false', () {
      expect(releaseWithTag('v1.0.0').isNewerThan('1.0.1'), isFalse);
    });

    test('版本相等应返回 false（不高于当前）', () {
      expect(releaseWithTag('v1.0.0').isNewerThan('1.0.0'), isFalse);
    });

    test('release 无 v 前缀也应正常比较', () {
      expect(releaseWithTag('2.0.0').isNewerThan('1.9.9'), isTrue);
    });

    test('大写 V 前缀应被识别并去掉', () {
      // 实现用 startsWith('v') 后转 toLowerCase 判断，实际是先 toLowerCase 再 startsWith
      expect(releaseWithTag('V1.2.3').isNewerThan('1.2.2'), isTrue);
    });

    test('多段版本号：1.0 < 1.0.1（不足段补 0）', () {
      expect(releaseWithTag('v1.0.1').isNewerThan('1.0'), isTrue);
    });

    test('多段版本号：1.0 不高于 1.0.0（补 0 后相等）', () {
      expect(releaseWithTag('v1.0').isNewerThan('1.0.0'), isFalse);
    });

    test('次版本号比较：1.2.0 > 1.1.9', () {
      expect(releaseWithTag('v1.2.0').isNewerThan('1.1.9'), isTrue);
    });

    test('主版本号比较：2.0.0 > 1.99.99', () {
      expect(releaseWithTag('v2.0.0').isNewerThan('1.99.99'), isTrue);
    });

    test('CI 注入的日期版本号格式 YYYY.MMDD.N 应支持比较', () {
      // 项目实际版本格式如 2026.0728.0
      expect(releaseWithTag('v2026.0728.1').isNewerThan('2026.0728.0'), isTrue);
      expect(releaseWithTag('v2026.0729.0').isNewerThan('2026.0728.5'), isTrue);
    });

    test('本地默认版本 1.0.0 应被任何线上版本超过', () {
      expect(releaseWithTag('v2026.0728.0').isNewerThan('1.0.0'), isTrue);
    });

    test('非数字段应回退为 0（容错）', () {
      // "1.x.0" → [1, 0, 0]，与 "1.0.0" 相等
      expect(releaseWithTag('v1.x.0').isNewerThan('1.0.0'), isFalse);
    });

    test('空 tagName 应视为 0.0.0，不高于任何正常版本', () {
      expect(releaseWithTag('').isNewerThan('0.0.0'), isFalse);
    });

    test('当前版本为空字符串应视为 0.0.0，任何 release 都更高', () {
      expect(releaseWithTag('v0.0.1').isNewerThan(''), isTrue);
    });
  });
}
