import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:yellow_depot/core/services/app_update_service.dart';
import 'package:yellow_depot/core/services/github_release_service.dart';
import 'package:yellow_depot/core/theme/design_tokens.dart';

/// 更新对话框主题色（顶层定义，便于 [_InfoLine] 等内部类访问）
///
/// 启动阶段 ThemeController 可能未就绪，硬编码默认主题色避免依赖 GetX。
class _UpdateColors {
  static const Color primary = Color(0xFFEC4899);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceMuted = Color(0xFF8E8E93);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color destructive = Color(0xFFEF4444);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color successFg = Color(0xFF2E7D32);
  static const Color neutralBg = Color(0xFFF5F5F7);
  static const Color trackBg = Color(0xFFE5E5EA);
}

/// 更新对话框
///
/// 支持两种模式：
/// - **强制更新**（`forceUpdate = true`）：只有"立即更新"按钮，
///   无法通过返回键 / 点击外部关闭对话框，用户必须更新或退出 App。
/// - **非强制更新**（`forceUpdate = false`）：有"立即更新"和"稍后"两个按钮，
///   用户可选"稍后"跳过本次更新，下次启动仍会重新提示。
///
/// 流程：
/// 1. 显示 release 信息（版本号 / 发布时间 / 更新内容）
/// 2. 用户点"立即更新"：
///    - 先请求 REQUEST_INSTALL_PACKAGES 权限
///    - 调用 AppUpdateService.downloadAndInstall 下载 APK
///    - 下载过程中显示进度条 + 下载百分比 + 已下载/总字节数
///    - 下载完成自动唤起系统 APK 安装器
///    - 对话框切换为"已完成下载，请按提示安装"状态
/// 3. 错误处理：
///    - 权限拒绝 / 下载失败：显示错误信息 + "重试"按钮
///    - 强制模式额外提供"退出 App"按钮（避免用户无法离开对话框）
/// 4. 非强制模式下用户点"稍后"：关闭对话框，调用 onLater 继续 App 流程
class UpdateDialog extends StatefulWidget {
  final GitHubRelease release;

  /// 是否强制更新
  ///
  /// - true：仅显示"立即更新"按钮，barrierDismissible=false，canPop=false
  /// - false：显示"立即更新" + "稍后"两个按钮，barrierDismissible=true，canPop=true
  final bool forceUpdate;

  /// 用户选"稍后"时的回调（仅在非强制模式下生效）
  ///
  /// 强制模式下此回调不会被调用（无"稍后"按钮）。
  final VoidCallback? onLater;

  const UpdateDialog({
    super.key,
    required this.release,
    required this.forceUpdate,
    this.onLater,
  });

  /// 显示对话框
  ///
  /// 参数：
  /// - [release]：GitHubRelease 实例
  /// - [forceUpdate]：是否强制更新（来自 release.forceUpdate）
  /// - [onLater]：用户选"稍后"的回调（仅非强制模式有效）
  ///
  /// 返回值：对话框关闭后 Future 完成。调用方应根据 forceUpdate 决定后续行为：
  /// - 强制模式：对话框关闭意味着用户已退出 App 或正在安装新版本，不应继续进入旧版本
  /// - 非强制模式：可继续 App 流程（onLater 已被调用，或已下载完成）
  static Future<void> show(
    BuildContext context, {
    required GitHubRelease release,
    required bool forceUpdate,
    VoidCallback? onLater,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => UpdateDialog(
        release: release,
        forceUpdate: forceUpdate,
        onLater: onLater,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  bool _downloaded = false; // APK 已下载并唤起安装器
  double _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _receivedBytes = 0;
      _totalBytes = 0;
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
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _progress = progress;
            });
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

  /// 退出 App（仅强制更新模式下用户拒绝更新时使用）
  void _exitApp() {
    SystemNavigator.pop();
  }

  /// 选"稍后"（非强制模式）— 关闭对话框并通知调用方
  void _onLater() {
    Navigator.of(context).pop();
    widget.onLater?.call();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forceUpdate,
      // 用 Dialog 替代 AlertDialog，避免 AlertDialog 内部自动 SingleChildScrollView
      // 把整个 content 一起滚动（与"标题/版本/发布时间/按钮固定"的诉求冲突）。
      //
      // 布局结构（全部固定，仅 release notes 内容区域可滚动）：
      // ┌─────────────────────────────────┐
      // │ Title（图标 + 「新版本」）       │ ← 固定
      // ├─────────────────────────────────┤
      // │ ModeBadge（强制/普通徽章）       │ ← 固定
      // │ 版本: v2026.xxx                  │ ← 固定
      // │ 发布时间: 2026-xx-xx             │ ← 固定
      // │ 更新内容（标题）                 │ ← 固定
      // │ ┌─────────────────────────────┐ │
      // │ │ Release body (可上下滑动)    │ │ ← 可滚动
      // │ │                             │ │
      // │ └─────────────────────────────┘ │
      // │ DownloadedHint / ErrorHint      │ ← 固定（按状态显示）
      // │ ProgressSection                  │ ← 固定（按状态显示）
      // ├─────────────────────────────────┤
      // │ [立即更新] [稍后]                │ ← 固定（按钮区）
      // └─────────────────────────────────┘
      child: Dialog(
        backgroundColor: _UpdateColors.surface,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceLg,
          vertical: DesignTokens.spaceXl,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏（固定）
              _buildTitle(),
              const SizedBox(height: DesignTokens.spaceMd),
              // 模式徽章（固定）
              _buildModeBadge(),
              // 版本信息（固定）
              _InfoLine(
                label: '版本',
                value: widget.release.tagName,
              ),
              const SizedBox(height: DesignTokens.spaceXs),
              _InfoLine(
                label: '发布时间',
                value: _formatDate(widget.release.publishedAt),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              // 更新内容标题（固定）
              _buildReleaseNotesHeader(),
              const SizedBox(height: DesignTokens.spaceXs),
              // 更新内容本身：限高 + 单独滚动
              // ConstrainedBox 限制最大高度避免极长 changelog 撑爆 Dialog，
              // 内层 SingleChildScrollView 仅此区域可上下滑动
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: _buildReleaseNotesBody(),
              ),
              // 状态提示（固定，按状态显示）
              if (_downloaded) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                _buildDownloadedHint(),
              ],
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                _buildErrorHint(),
              ],
              if (_downloading) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                _buildProgressSection(),
              ],
              const SizedBox(height: DesignTokens.spaceMd),
              // 按钮区（固定）
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标题栏：图标 + 标题文案
  ///
  /// 标题仅保留「新版本」字样（去除"发现"/"（必须更新）"等冗余后缀），
  /// 是否强制更新已通过下方 [_buildModeBadge] 红色/绿色徽章区分。
  Widget _buildTitle() {
    final title = _downloaded ? '请完成安装' : '新版本';
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _UpdateColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          child: const Icon(
            PhosphorIconsFill.arrowCircleUp,
            color: _UpdateColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: DesignTokens.spaceMd),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: DesignTokens.textH2,
              fontWeight: FontWeight.w700,
              color: _UpdateColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部模式徽章：强制更新 / 普通更新
  Widget _buildModeBadge() {
    if (_downloaded) return const SizedBox.shrink();
    if (widget.forceUpdate) {
      return Container(
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceSm,
          vertical: DesignTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: _UpdateColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: Row(
          children: [
            const Icon(
              PhosphorIconsFill.warningCircle,
              size: 14,
              color: _UpdateColors.primary,
            ),
            const SizedBox(width: DesignTokens.spaceXs),
            Expanded(
              child: Text(
                '此版本必须更新后才能使用',
                style: TextStyle(
                  fontSize: DesignTokens.textCaption,
                  fontWeight: FontWeight.w600,
                  color: _UpdateColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceSm,
        vertical: DesignTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: _UpdateColors.successBg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsFill.info,
            size: 14,
            color: _UpdateColors.successFg,
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          Expanded(
            child: Text(
              '发现新版本，可选择立即更新或稍后',
              style: TextStyle(
                fontSize: DesignTokens.textCaption,
                fontWeight: FontWeight.w600,
                color: _UpdateColors.successFg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Release body 更新内容标题（固定，不滚动）
  Widget _buildReleaseNotesHeader() {
    if (widget.release.body.isEmpty) return const SizedBox.shrink();
    return Text(
      '更新内容',
      style: TextStyle(
        fontSize: DesignTokens.textCaption,
        fontWeight: FontWeight.w600,
        color: _UpdateColors.onSurfaceMuted,
      ),
    );
  }

  /// Release body 更新内容主体（可单独上下滑动）
  ///
  /// 由外层 [ConstrainedBox] 限制最大高度，超出部分在此 [SingleChildScrollView]
  /// 内部滚动。其它信息（标题/版本/发布时间/按钮/状态提示）都固定不动。
  Widget _buildReleaseNotesBody() {
    if (widget.release.body.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: _UpdateColors.neutralBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        ),
        child: Text(
          widget.release.body,
          style: const TextStyle(
            fontSize: DesignTokens.textCaption,
            color: _UpdateColors.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  /// 下载完成提示
  Widget _buildDownloadedHint() {
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.spaceMd),
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        color: _UpdateColors.successBg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsFill.checkCircle,
            size: 18,
            color: _UpdateColors.successFg,
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          Expanded(
            child: Text(
              'APK 已下载完成，系统安装器应已弹出。请按提示完成安装后重新启动 App。',
              style: TextStyle(
                fontSize: DesignTokens.textCaption,
                color: _UpdateColors.successFg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误提示
  Widget _buildErrorHint() {
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.spaceMd),
      padding: const EdgeInsets.all(DesignTokens.spaceSm),
      decoration: BoxDecoration(
        color: _UpdateColors.destructive.withOpacity(0.08),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsFill.warningCircle,
            size: 16,
            color: _UpdateColors.destructive,
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                fontSize: DesignTokens.textCaption,
                color: _UpdateColors.destructive,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 下载进度条区域：进度条 + 百分比 + 字节数
  Widget _buildProgressSection() {
    return Container(
      margin: const EdgeInsets.only(top: DesignTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: _UpdateColors.trackBg,
              valueColor:
                  const AlwaysStoppedAnimation(_UpdateColors.primary),
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '正在下载... ${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: DesignTokens.textCaption,
                  color: _UpdateColors.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_totalBytes > 0)
                Text(
                  '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                  style: const TextStyle(
                    fontSize: DesignTokens.textCaption,
                    color: _UpdateColors.onSurfaceMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 按钮组（根据状态切换）
  ///
  /// - 下载中：无按钮
  /// - 下载完成：[退出 App]（强制）/ [关闭]（非强制）
  /// - 出错：[退出 App（强制）/ 稍后（非强制）] [重试]
  /// - 默认：强制 [立即更新] / 非强制 [稍后] [立即更新]
  List<Widget> _buildActions() {
    if (_downloading) {
      return const [];
    }
    if (_downloaded) {
      // 下载完成：仅一个关闭按钮
      return [
        TextButton(
          onPressed: widget.forceUpdate ? _exitApp : _onLater,
          child: Text(
            widget.forceUpdate ? '退出 App' : '关闭',
            style: const TextStyle(color: _UpdateColors.onSurfaceMuted),
          ),
        ),
      ];
    }
    if (_error != null) {
      // 出错：重试 + （强制模式：退出 App / 非强制模式：稍后）
      return [
        TextButton(
          onPressed: widget.forceUpdate ? _exitApp : _onLater,
          child: Text(
            widget.forceUpdate ? '退出 App' : '稍后',
            style: const TextStyle(color: _UpdateColors.onSurfaceMuted),
          ),
        ),
        FilledButton(
          onPressed: _startUpdate,
          style: FilledButton.styleFrom(
            backgroundColor: _UpdateColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('重试'),
        ),
      ];
    }
    // 默认：强制 → 仅[立即更新]；非强制 → [稍后] [立即更新]
    if (widget.forceUpdate) {
      return [
        FilledButton(
          onPressed: _startUpdate,
          style: FilledButton.styleFrom(
            backgroundColor: _UpdateColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('立即更新'),
        ),
      ];
    }
    return [
      TextButton(
        onPressed: _onLater,
        child: const Text(
          '稍后',
          style: TextStyle(color: _UpdateColors.onSurfaceMuted),
        ),
      ),
      FilledButton(
        onPressed: _startUpdate,
        style: FilledButton.styleFrom(
          backgroundColor: _UpdateColors.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text('立即更新'),
      ),
    ];
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static String _formatBytes(int bytes) {
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

/// 信息行（版本号 / 发布时间展示）
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
            color: _UpdateColors.onSurfaceMuted,
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
              color: _UpdateColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
