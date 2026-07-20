import 'package:dio/dio.dart';
import 'package:yellow_depot/core/error/exceptions.dart';

/// 错误封装拦截器
///
/// 统一把 DioException 封装为 AppException 体系，业务层只关心业务异常。
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _convert(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
        stackTrace: err.stackTrace,
        message: exception.message,
      ),
    );
  }

  AppException _convert(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const TimeoutException('网络连接超时，请检查网络后重试');
      case DioExceptionType.connectionError:
        return const NetworkException('网络连接失败，请检查网络设置');
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        if (code == 404) {
          return const NotFoundException('请求的资源不存在');
        }
        if (code >= 500) {
          return NetworkException(
            '服务器繁忙 ($code)',
            statusCode: code,
          );
        }
        return NetworkException(
          '请求失败 ($code)',
          statusCode: code,
          cause: err,
        );
      case DioExceptionType.cancel:
        return const BusinessException('请求已取消');
      case DioExceptionType.badCertificate:
        return const NetworkException('证书校验失败');
      case DioExceptionType.unknown:
        // unknown 类型常见原因：DNS 解析失败、SocketException、
        // HandshakeException、源站主动断开连接（反爬）。
        // 给用户更友好的提示而非"未知网络错误"。
        final msg = err.error?.toString() ?? err.message ?? '';
        if (msg.contains('Failed host lookup') ||
            msg.contains('SocketException') ||
            msg.contains('DNS')) {
          return const NetworkException('网络连接失败，请检查网络或切换镜像');
        }
        if (msg.contains('HandshakeException') ||
            msg.contains('TLS') ||
            msg.contains('certificate')) {
          return const NetworkException('安全连接失败，请稍后重试');
        }
        if (msg.contains('Connection reset') ||
            msg.contains('Broken pipe') ||
            msg.contains('Connection closed')) {
          return const NetworkException('连接被重置，请稍后重试');
        }
        return NetworkException(
          msg.isNotEmpty ? msg : '网络异常，请稍后重试',
          cause: err,
        );
    }
  }
}
