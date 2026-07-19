/// 统一异常封装
sealed class AppException implements Exception {
  final String message;
  final String code;
  final Object? cause;

  const AppException(this.message, {this.code = 'UNKNOWN', this.cause});

  @override
  String toString() => '[$code] $message';
}

class NetworkException extends AppException {
  final int? statusCode;
  const NetworkException(
    String message, {
    this.statusCode,
    Object? cause,
  }) : super(message, code: 'NETWORK', cause: cause);
}

class TimeoutException extends AppException {
  const TimeoutException([String message = '请求超时'])
      : super(message, code: 'TIMEOUT');
}

class ParseException extends AppException {
  final String selector;
  const ParseException(
    String message, {
    this.selector = '',
    Object? cause,
  }) : super(message, code: 'PARSE', cause: cause);
}

class DecryptException extends AppException {
  const DecryptException([String message = '播放地址解密失败'])
      : super(message, code: 'DECRYPT');
}

class UrlExpiredException extends AppException {
  const UrlExpiredException([String message = '播放地址已过期'])
      : super(message, code: 'URL_EXPIRED');
}

class NotFoundException extends AppException {
  const NotFoundException([String message = '资源不存在'])
      : super(message, code: 'NOT_FOUND');
}

class DatabaseException extends AppException {
  const DatabaseException(String message, {Object? cause})
      : super(message, code: 'DB', cause: cause);
}

class BusinessException extends AppException {
  const BusinessException(String message, {String code = 'BUSINESS'})
      : super(message, code: code);
}
