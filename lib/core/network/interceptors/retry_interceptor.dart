import 'package:dio/dio.dart';
import 'package:yellow_depot/core/constants/app_constants.dart';
import 'package:yellow_depot/core/utils/human_verification_detector.dart';
import 'package:yellow_depot/core/utils/logger.dart';
import 'package:yellow_depot/core/utils/user_agent_utils.dart';

/// 网络失败重试拦截器
///
/// - 连接超时自动重试 3 次
/// - 418 反爬（Quantum 反爬系统）自动重试 5 次 + 切换 UA + 间隔随机化
/// - 人机验证页（200 + 滑动验证 HTML）自动重试 3 次 + 随机延迟
/// - 5xx 服务器错误重试 3 次
/// - 重试间隔 2 秒（反爬策略）
/// - 仅对幂等 GET 请求重试（418 / 人机验证特殊处理：POST 也重试，
///   因为是反爬误判）
///
/// 重要：通过 [dioProvider] 复用原 Dio 实例进行重试，
/// 否则会丢失 Cookie、UA、baseUrl 等配置，导致重试请求全部失败。
/// 重试走完整拦截器链：UA 拦截器每次注入新随机 UA（自动换 UA），
/// CookieJar 自动保存 WAF 下发的验证 Cookie 并在重试时回带。
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;
  final Dio Function() dioProvider;

  /// 418 反爬错误的最大重试次数（比普通错误更多）
  ///
  /// Quantum 反爬系统会概率性返回 418，多次重试 + UA 切换可绕过。
  static const int maxAntiCrawlerRetries = 5;

  /// 418 反爬错误的基础重试间隔（实际会加随机抖动）
  static const Duration antiCrawlerBaseDelay = Duration(seconds: 1);

  /// 人机验证页（200 + 滑动验证 HTML）的最大重试次数
  ///
  /// 前置 WAF 偶尔返回 200 + 滑动验证页（华东节点），为概率性拦截，
  /// 换 UA + 回带 Cookie + 随机延迟重试可绕过。
  static const int maxHumanVerifyRetries = 3;

  RetryInterceptor({
    required this.dioProvider,
    this.maxRetries = AppConstants.maxRetryCount,
    this.retryDelay = AppConstants.retryDelay,
  });

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    // 源站前置 WAF 偶尔返回 200 + 滑动验证页（非业务 HTML）：
    // 换 UA（重走拦截器链自动随机）+ 随机延迟重试，
    // WAF 下发的 Set-Cookie 由 CookieJar 自动保存回带。
    final data = response.data;
    if (data is String &&
        HumanVerificationDetector.isVerificationPage(data)) {
      final attempt =
          response.requestOptions.extra['humanverify_attempt'] as int? ?? 0;
      if (attempt < maxHumanVerifyRetries) {
        response.requestOptions.extra['humanverify_attempt'] = attempt + 1;

        // 随机延迟 1~2.5s（避免固定重试节奏被 WAF 识别）
        final jitter = DateTime.now().millisecondsSinceEpoch % 1500;
        final delay = Duration(milliseconds: 1000 + jitter);

        appLogger.w(
          '响应为人机验证页，第 ${attempt + 1} 次重试 '
          '(共 $maxHumanVerifyRetries 次): ${response.requestOptions.uri} '
          '(延迟 ${delay.inMilliseconds}ms)',
        );

        await Future.delayed(delay);

        try {
          final dio = dioProvider();
          // 重走完整拦截器链：UA 拦截器注入新随机 UA，
          // 重试响应会再次进入 onResponse 检测（计数累加）
          final resp = await dio.fetch(response.requestOptions);
          return handler.resolve(resp);
        } on DioException catch (e) {
          return handler.reject(e);
        }
      }
      appLogger.w('人机验证重试次数用尽: ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = err.requestOptions.extra['retry_attempt'] as int? ?? 0;
    final isGet = err.requestOptions.method.toUpperCase() == 'GET';

    // 418 反爬错误：GET 和 POST 都重试，且重试次数更多
    final statusCode = err.response?.statusCode ?? 0;
    final isAntiCrawler = statusCode == 418;
    final antiCrawlerAttempt =
        err.requestOptions.extra['anticrawler_attempt'] as int? ?? 0;

    if (isAntiCrawler && antiCrawlerAttempt < maxAntiCrawlerRetries) {
      err.requestOptions.extra['anticrawler_attempt'] = antiCrawlerAttempt + 1;

      // 切换 UA（关键：每次重试都换新 UA 绕过基于 UA 的反爬识别）
      err.requestOptions.headers['User-Agent'] = UserAgentUtils.random();

      // 随机延迟 1-3 秒（避免被识别为机器人的固定节奏）
      final jitter = DateTime.now().millisecondsSinceEpoch % 2000;
      final delay = antiCrawlerBaseDelay +
          Duration(milliseconds: jitter.toInt());

      appLogger.w(
        '反爬 418 错误，第 ${antiCrawlerAttempt + 1} 次重试 '
        '(共 $maxAntiCrawlerRetries 次): ${err.requestOptions.uri} '
        '(延迟 ${delay.inMilliseconds}ms + 切换 UA)',
      );

      await Future.delayed(delay);

      try {
        final dio = dioProvider();
        final response = await dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        // 仍可能是 418，继续交给 onError 处理（会再次进入此分支）
        return handler.next(e);
      }
    }

    // 普通错误：仅对幂等 GET 请求重试
    final shouldRetry =
        isGet && attempt < maxRetries && _isRetryableError(err);

    if (!shouldRetry) {
      return handler.next(err);
    }

    err.requestOptions.extra['retry_attempt'] = attempt + 1;
    appLogger.w(
      '请求失败，第 ${attempt + 1} 次重试 (共 $maxRetries 次): '
      '${err.requestOptions.uri} - ${err.type}',
    );

    await Future.delayed(retryDelay);

    try {
      // 复用原 Dio 实例，保留所有拦截器（UA / Cookie / Log）和 baseUrl
      final dio = dioProvider();
      final response = await dio.fetch(err.requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isRetryableError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        // 5xx 重试，4xx（除 418 外）不重试
        // 418 在上面的反爬分支单独处理
        final code = err.response?.statusCode ?? 0;
        return code >= 500 && code < 600;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
      case DioExceptionType.unknown:
        // unknown 类型常见原因：
        // - DNS 解析失败（域名暂时不可达）
        // - SocketException（连接重置、网络切换）
        // - HandshakeException（TLS 握手失败，源站偶发）
        // - 反爬系统主动断开连接
        // 这些通常是暂时的，重试可恢复
        // 排除用户主动取消（cancel 已在上面处理）
        final msg = err.error?.toString() ?? err.message ?? '';
        // 手动 cancel 信息（部分场景被包装成 unknown）
        if (msg.contains('cancelled') || msg.contains('Canceled')) {
          return false;
        }
        return true;
    }
  }
}
