class Genre {
  final String name;
  final String url;

  Genre({required this.name, required this.url});

  @override
  String toString() {
    return 'Genre{name: $name, url: $url}';
  }
}

class Comic {
  final String title;
  final String imageUrl;
  final String detailUrl;
  final String? status;
  final String? author;
  final String? views;
  final List<Genre> genres;
  final String? updateTime;
  final String? chapterInfo;
  final int? chapterCount;

  Comic({
    required this.title, 
    required this.imageUrl, 
    required this.detailUrl,
    this.status,
    this.author,
    this.views,
    List<Genre>? genres,
    this.updateTime,
    this.chapterInfo,
    this.chapterCount,
  }) : genres = genres ?? [];

  @override
  String toString() {
    return 'Comic{title: $title, status: $status, author: $author, views: $views, genres: ${genres.map((g) => g.name).join(', ')}, updateTime: $updateTime, chapterInfo: $chapterInfo, chapterCount: $chapterCount}';
  }
}
