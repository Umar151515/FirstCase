typedef Json = Map<String, dynamic>;

List<Json> items(dynamic value) =>
    ((value is Map ? value['items'] : value) as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

class Person {
  Person(this.json);
  final Json json;
  int get id => json['id'] as int;
  String get name => json['display_name'] as String? ?? 'Пользователь';
  String get specialty => json['specialization'] as String? ?? '';
  String get city => json['city'] as String? ?? 'Бишкек';
  String get bio => json['bio'] as String? ?? '';
  String? get avatar => json['avatar_url'] as String?;
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
  String get category =>
      (json['category'] as Map?)?['name'] as String? ?? 'Другое';
  Person get customer =>
      Person(Map<String, dynamic>.from(json['customer'] as Map));
  bool get tips => json['payment_type'] == 'tips';
  int get responses => json['application_count'] as int? ?? 0;
  int get revisions => json['max_revisions'] as int? ?? 0;
  DateTime get deadline => DateTime.parse(json['deadline'] as String).toLocal();
}

class PageData<T> {
  PageData(this.items, this.total);
  final List<T> items;
  final int total;
}

String statusLabel(String status) =>
    const {
      'published': 'Открыт для откликов',
      'assigned': 'Исполнитель выбран',
      'in_progress': 'В работе',
      'submitted': 'На проверке',
      'revision_requested': 'Нужны правки',
      'accepted_pending_review': 'Ожидает отзыв',
      'completed': 'Завершён',
      'cancelled': 'Отменён',
      'disputed': 'Открыт спор',
      'pending': 'Ожидает решения',
      'accepted': 'Принят',
      'rejected': 'Отклонён',
      'withdrawn': 'Отозван',
      'in_review': 'На рассмотрении',
      'resolved': 'Решена',
      'private': 'Только мне',
      'anonymous': 'Анонимно',
      'public': 'Публично',
      'created': 'Заказ создан',
      'start': 'Исполнитель приступил к работе',
      'accept': 'Заказчик принял результат',
      'request_revision': 'Заказчик запросил правки',
      'cancel': 'Заказ отменён',
      'dispute': 'Открыт спор',
      'customer_review': 'Заказчик оставил отзыв',
      'performer_review': 'Исполнитель оставил отзыв',
      'dispute_resolved': 'Спор рассмотрен модератором',
    }[status] ??
    status;
