import 'package:dio/dio.dart';
import 'package:videohub/core/utils/logger.dart';

/// 日志拦截器
///
/// 统一打印请求/响应/错误日志，便于调试。
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    appLogger.i(
      '→ ${options.method} ${options.uri}\n'
      '  headers: ${options.headers}\n'
      '  query: ${options.queryParameters}\n'
      '  body: ${options.data?.toString().substring(0, options.data.toString().length.clamp(0, 500))}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final length = response.data?.toString().length ?? 0;
    appLogger.i(
      '← ${response.statusCode} ${response.requestOptions.uri} '
      '($length bytes)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    appLogger.e(
      '✕ ${err.type.name} ${err.requestOptions.uri}\n'
      '  status: ${err.response?.statusCode}\n'
      '  message: ${err.message}',
      error: err.error,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}
