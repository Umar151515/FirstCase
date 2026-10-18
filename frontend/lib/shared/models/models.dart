typedef Json = Map<String, dynamic>;

List<Json> items(dynamic value) =>
    ((value is Map ? value['items'] : value) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

class Person {
  Person(this.json);
  final Json json;
  int get id => json['id'] as int;
  String get name => json['display_name'] as String? ?? '';
  String get specialty => json['specialization'] as String? ?? '';
  String get city => json['city'] as String? ?? '';
  String get bio => json['bio'] as String? ?? '';
  String? get avatar => json['avatar_url'] as String?;
  int? get avatarAttachmentId => json['avatar_attachment_id'] as int?;
  bool get admin => json['role'] == 'admin';
  bool get onboarded => json['onboarding_completed'] == true;
  double get rating => (json['rating'] as num? ?? 0).toDouble();
  List<String> get skills => List<String>.from(json['skills'] as List? ?? []);
}

class Task {
  Task(this.json);
  final Json json;
  int get id => json['id'] as int;
  int get customerId => json['customer_id'] as int;
  String get title => json['title'] as String;
  String get description => json['description'] as String? ?? '';
  String get result => json['expected_result'] as String? ?? '';
  String get status => json['status'] as String? ?? 'published';
  String get category => (json['category'] as Map?)?['name'] as String? ?? '';
  String get categorySlug =>
      (json['category'] as Map?)?['slug'] as String? ?? '';
  Person get customer =>
      Person(Map<String, dynamic>.from(json['customer'] as Map));
  bool get tips => json['payment_type'] == 'tips';
  int get responses => json['application_count'] as int? ?? 0;
  int get revisions => json['max_revisions'] as int? ?? 0;
  AiPolicy get aiPolicy => AiPolicy.fromCode(json['ai_policy'] as String?);
  int? get coverId => json['cover_attachment_id'] as int?;
  DateTime get deadline => DateTime.parse(json['deadline'] as String).toLocal();
}

enum AiUsage {
  noAi('no_ai'),
  consultation('consultation'),
  assisted('ai_assisted');

  const AiUsage(this.code);
  final String code;
  static AiUsage fromCode(String? code) =>
      values.firstWhere((usage) => usage.code == code, orElse: () => noAi);
}

enum AiPolicy {
  noAi('no_ai'),
  consultation('consultation'),
  allowed('ai_allowed');

  const AiPolicy(this.code);
  final String code;
  static AiPolicy fromCode(String? code) =>
      values.firstWhere((policy) => policy.code == code, orElse: () => allowed);
  List<AiUsage> get permittedUsages => switch (this) {
    noAi => [AiUsage.noAi],
    consultation => [AiUsage.noAi, AiUsage.consultation],
    allowed => AiUsage.values,
  };
}

class PageData<T> {
  PageData(this.items, this.total);
  final List<T> items;
  final int total;
}
