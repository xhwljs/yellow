import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/services/app_update_service.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

/// 强制更新对话框
///
/// 在启动页检查到新版本后弹出。强制更新模式：用户必须更新才能进入 App，
/// 没有"稍后"按钮，无法通过返回键 / 点击外部关闭对话框。
///
/// 流程：
/// 1. 显示 release 信息（版本号 / 发布时间 / 更新内容）
/// 2. 用户点"立即更新"：
///    - 先请求 REQUEST_INSTALL_PACKAGES 权限
///    - 调用 AppUpdateService.downloadAndInstall 下载 APK
///    - 下载过程中显示进度条 + 下载百分比
///    - 下载完成自动唤起系统 APK 安装器
///    - 对话框切换为"已完成下载，请按提示安装"状态
/// 3. 错误处理：
///    - 权限拒绝 / 下载失败：显示错误信息 + "重试" + "退出 App" 两个按钮
///    - 用户必须重试成功或主动退出 App（不能进入旧版本）
class UpdateDialog extends StatefulWidget {
  final GitHubRelease release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  /// 显示对话框
  ///
  /// 强制更新模式：调用方只需传入 release。对话框关闭意味着用户已退出 App
  /// 或完成安装。调用方不应在对话框关闭后继续进入旧版本 App。
  static Future<void> show(
    BuildContext context, {
    required GitHubRelease release,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(release: release),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  bool _downloaded = false; // APK 已下载并唤起安装器
  double _progress = 0;
  String? _error;

  // 默认主题色（启动阶段 ThemeController 可能未就绪）
  static const Color _primary = Color(0xFFEC4899);
  static const Color _onSurface = Color(0xFF1A1A1A);
  static const Color _onSurfaceMuted = Color(0xFF8E8E93);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _destructive = Color(0xFFEF4444);

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
      _downloaded = false;
    });

    // 1. 请求安装权限
    final granted = await AppUpdateService.requestInstallPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '需要安装权限才能更新。请在系统设置中授予"安装未知应用"权限后重试。';
      });
      return;
    }

    // 2. 下载 + 唤起安装器
    try {
      await AppUpdateService.downloadAndInstall(
        release: widget.release,
        onProgress: (received, total, progress) {
          if (mounted) {
            setState(() => _progress = progress);
          }
        },
      );
      // 安装器已唤起，提示用户完成安装
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloaded = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _error = '下载失败：$e';
      });
    }
  }

  /// 退出 App（强制更新模式下用户拒绝更新只能退出）
  void _exitApp() {
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
              ),
              child: const Icon(
                PhosphorIconsFill.arrowCircleUp,
                color: _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Text(
                _downloaded ? '请完成安装' : '发现新版本',
                style: GoogleFonts.poppins(
                  fontSize: DesignTokens.textH2,
                  fontWeight: FontWeight.w700,
                  color: _onSurface,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 强制更新提示
              if (!_downloaded)
                Container(
                  margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceSm,
                    vertical: DesignTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsFill.warningCircle,
                        size: 14,
                        color: _primary,
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Expanded(
                        child: Text(
                          '此版本必须更新后才能使用',
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            fontWeight: FontWeight.w600,
                            color: _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // 版本号
              _InfoLine(
                label: '版本',
                value: widget.release.tagName,
              ),
              const SizedBox(height: DesignTokens.spaceXs),
              // 发布时间
              _InfoLine(
                label: '发布时间',
                value: _formatDate(widget.release.publishedAt),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              // 更新内容（截断显示）
              if (widget.release.body.isNotEmpty) ...[
                Text(
                  '更新内容',
                  style: TextStyle(
                    fontSize: DesignTokens.textCaption,
                    fontWeight: FontWeight.w600,
                    color: _onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Text(
                    widget.release.body,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: DesignTokens.textCaption,
                      color: _onSurface,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              // 下载完成提示
              if (_downloaded) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        PhosphorIconsFill.checkCircle,
                        size: 18,
                        color: Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Expanded(
                        child: Text(
                          'APK 已下载完成，系统安装器应已弹出。请按提示完成安装后重新启动 App。',
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            color: const Color(0xFF2E7D32),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 错误提示
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: _destructive.withOpacity(0.08),
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        PhosphorIconsFill.warningCircle,
                        size: 16,
                        color: _destructive,
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: DesignTokens.textCaption,
                            color: _destructive,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 下载进度条
              if (_downloading) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(DesignTokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE5E5EA),
                    valueColor: const AlwaysStoppedAnimation(_primary),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXs),
                Center(
                  child: Text(
                    '正在下载... ${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: DesignTokens.textCaption,
                      color: _onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _buildActions(),
      ),
    );
  }

  /// 构建按钮组（根据状态切换）
  ///
  /// - 默认：[立即更新]
  /// - 下载中：无按钮（等待下载完成）
  /// - 下载完成（已唤起安装器）：[退出 App]（用户完成安装后会自动启动新版本）
  /// - 出错：[退出 App] [重试]
  List<Widget> _buildActions() {
    if (_downloading) {
      return const [];
    }
    if (_downloaded) {
      return [
        TextButton(
          onPressed: _exitApp,
          child: const Text(
            '退出 App',
            style: TextStyle(color: _onSurfaceMuted),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        TextButton(
          onPressed: _exitApp,
          child: const Text(
            '退出 App',
            style: TextStyle(color: _onSurfaceMuted),
          ),
        ),
        FilledButton(
          onPressed: _startUpdate,
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('重试'),
        ),
      ];
    }
    return [
      FilledButton(
        onPressed: _startUpdate,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
        child: const Text('立即更新'),
      ),
    ];
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label：',
          style: const TextStyle(
            fontSize: DesignTokens.textCaption,
            color: _onSurfaceMuted,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: DesignTokens.textCaption,
              fontWeight: FontWeight.w500,
              color: _onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
