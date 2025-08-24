import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../screens/detail_screen.dart';
import '../constants/app_constants.dart';
import '../screens/cloudflare_bypass_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../screens/genre_comics_screen.dart'; // Added import for GenreComicsScreen

class ComicSearchDelegate extends SearchDelegate<Comic?> {
  final NetTruyenService _service = NetTruyenService();

  @override
  String get searchFieldLabel => 'Search comics…';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null));
  }

  // Only trigger a search when user hits Enter
  @override
  void showResults(BuildContext context) {
    if (query.trim().isEmpty) return;
    super.showResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Show popular genres and search tips when no query
    if (query.isEmpty) {
      return _buildPopularGenres(context);
    }

    // Show search tips when typing
    return _buildSearchTips(context);
  }

  Widget _buildPopularGenres(BuildContext context) {
    final popularGenres = [
      {'name': 'Action', 'path': '/tim-truyen/action-95'},
      {'name': 'Comedy', 'path': '/tim-truyen/comedy-99'},
      {'name': 'Drama', 'path': '/tim-truyen/drama-103'},
      {'name': 'Romance', 'path': '/tim-truyen/romance-121'},
      {'name': 'Fantasy', 'path': '/tim-truyen/fantasy-100'},
      {'name': 'Adventure', 'path': '/tim-truyen/adventure-101'},
      {'name': 'Slice of Life', 'path': '/tim-truyen/slice-of-life'},
      {'name': 'Psychological', 'path': '/tim-truyen/psychological'},
      {'name': 'Mystery', 'path': '/tim-truyen/mystery'},
      {'name': 'Horror', 'path': '/tim-truyen/horror'},
      {'name': 'Sci-Fi', 'path': '/tim-truyen/sci-fi'},
      {'name': 'Supernatural', 'path': '/tim-truyen/supernatural'},
      {'name': 'Historical', 'path': '/tim-truyen/historical'},
      {'name': 'Sports', 'path': '/tim-truyen/sports'},
      {'name': 'Music', 'path': '/tim-truyen/music'},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thể loại phổ biến',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: popularGenres.map((genre) {
              return ActionChip(
                label: Text(genre['name']!),
                onPressed: () {
                  // Navigate to genre page instead of search
                  close(context, null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GenreComicsScreen(
                        genreName: genre['name']!,
                        genreUrl: genre['path']!,
                      ),
                    ),
                  );
                },
                backgroundColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Tìm kiếm nhanh',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '• Gõ tên truyện và nhấn Enter để tìm kiếm\n'
            '• Nhấn vào thể loại để xem truyện cùng loại\n'
            '• Sử dụng từ khóa tiếng Việt hoặc tiếng Anh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tìm kiếm: "$query"',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nhấn Enter để tìm kiếm\n'
            'Hoặc tiếp tục gõ để tinh chỉnh từ khóa',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // This only runs when the user hits Enter/Search
    return FutureBuilder<List<Comic>>(
      future: _service.searchComics(query.trim()),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final err = snap.error;
          if (err.toString().contains('CloudflareException')) {
            // blocked → let user manually verify
            return Center(
              child: ElevatedButton(
                child: const Text('Verify you are human'),
                onPressed: () async {
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CloudflareBypassScreen(url: err.toString()),
                    ),
                  );
                  if (ok == true && context.mounted) {
                    // retry
                    showResults(context);
                  }
                },
              ),
            );
          }
          return Center(child: Text('Error: $err'));
        }

        final results = snap.data!;
        if (results.isEmpty) {
          return const Center(child: Text('No results found.'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: results.length,
          itemBuilder: (_, i) {
            final comic = results[i];
            return GestureDetector(
              onTap: () {
                close(context, comic);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailScreen(comic: comic)));
              },
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                        child: FutureBuilder<String>(
                          future: _service.getCurrentDomain(),
                          builder: (context, domainSnapshot) {
                            if (!domainSnapshot.hasData) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              );
                            }

                            return CachedNetworkImage(
                              cacheManager: CacheManager(
                                  Config(AppConstants.THUMB_CACHE_KEY)),
                              imageUrl: comic.imageUrl,
                              httpHeaders: {'Referer': domainSnapshot.data!},
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        comic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
