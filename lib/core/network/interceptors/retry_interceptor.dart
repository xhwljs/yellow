import 'package:dio/dio.dart';
import 'package:videohub/core/constants/app_constants.dart';
import 'package:videohub/core/utils/logger.dart';

/// 网络失败重试拦截器
///
/// - 连接超时自动重试 3 次
/// - 重试间隔 2 秒（反爬策略）
/// - 仅对幂等 GET 请求重试
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration retryDelay;

  RetryInterceptor({
    this.maxRetries = AppConstants.maxRetryCount,
    this.retryDelay = AppConstants.retryDelay,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = err.requestOptions.extra['retry_attempt'] as int? ?? 0;
    final isIdempotent = err.requestOptions.method.toUpperCase() == 'GET';

    final shouldRetry =
        isIdempotent && attempt < maxRetries && _isRetryableError(err);

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
      final dio = Dio();
      // 复制原始 Dio 的所有拦截器与配置（通过 BuildDio 拿到）
      // 这里通过 extra 标记重试上下文
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
        // 5xx 重试，4xx 不重试
        final code = err.response?.statusCode ?? 0;
        return code >= 500 && code < 600;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
