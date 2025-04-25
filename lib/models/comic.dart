class Comic {
  final String title;
  final String imageUrl;
  final String detailUrl;
  final String? status;
  final String? author;
  final String? views;
  final List<String> genres;
  final String? updateTime;

  Comic({
    required this.title, 
    required this.imageUrl, 
    required this.detailUrl,
    this.status,
    this.author,
    this.views,
    List<String>? genres,
    this.updateTime,
  }) : genres = genres ?? [];

  @override
  String toString() {
    return 'Comic{title: $title, status: $status, author: $author, views: $views, genres: $genres, updateTime: $updateTime}';
  }
}
