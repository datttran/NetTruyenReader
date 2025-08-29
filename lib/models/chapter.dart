class Chapter {
  final String id;
  final String title;
  final String url;
  final String? number;
  final DateTime? date;

  const Chapter({
    required this.id,
    required this.title,
    required this.url,
    this.number,
    this.date,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      number: json['number'],
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'number': number,
      'date': date?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'Chapter(id: $id, title: $title, url: $url, number: $number, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chapter && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
