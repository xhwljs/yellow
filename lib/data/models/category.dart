import 'package:floor/floor.dart';

/// 视频分类
@entity
class Category {
  @primaryKey
  final int id;

  final String name;
  final String url;
  final int count; // 视频数量

  const Category({
    required this.id,
    required this.name,
    required this.url,
    required this.count,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      url: map['url'] as String,
      count: map['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'count': count,
      };

  Category copyWith({
    int? id,
    String? name,
    String? url,
    int? count,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      count: count ?? this.count,
    );
  }
}
