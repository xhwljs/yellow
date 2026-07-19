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
    super.message, {
    this.statusCode,
    super.cause,
  }) : super(code: 'NETWORK');
}

class TimeoutException extends AppException {
  const TimeoutException([super.message = '请求超时']) : super(code: 'TIMEOUT');
}

class ParseException extends AppException {
  final String selector;
  const ParseException(
    super.message, {
    this.selector = '',
    super.cause,
  }) : super(code: 'PARSE');
}

class DecryptException extends AppException {
  const DecryptException([super.message = '播放地址解密失败'])
      : super(code: 'DECRYPT');
}

class UrlExpiredException extends AppException {
  const UrlExpiredException([super.message = '播放地址已过期'])
      : super(code: 'URL_EXPIRED');
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = '资源不存在'])
      : super(code: 'NOT_FOUND');
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause}) : super(code: 'DB');
}

class BusinessException extends AppException {
  const BusinessException(super.message, {super.code = 'BUSINESS'});
}
