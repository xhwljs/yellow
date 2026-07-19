import 'package:logger/logger.dart';

/// 全局日志器
final Logger appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 100,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

/// 简化版日志器（用于生产）
final Logger prodLogger = Logger(
  level: Level.warning,
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.none,
  ),
);
