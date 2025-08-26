import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../screens/detail_screen.dart';
import '../constants/theme_constants.dart';
import '../screens/cloudflare_bypass_screen.dart';
import '../screens/genre_comics_screen.dart'; // Added import for GenreComicsScreen
import '../widgets/custom_comic_card.dart';
import '../utils/domain_helper.dart';

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thể loại phổ biến',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThemeConstants.netflixWhite
                      : ThemeConstants.netflixNavy,
                ),
          ),
          const SizedBox(height: 16),
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              physics: const ClampingScrollPhysics(),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: popularGenres.map((genre) {
                  return _buildGenreChip(genre['name']!, genre['path']!, context);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tìm kiếm nhanh',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThemeConstants.netflixWhite
                      : ThemeConstants.netflixNavy,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '• Gõ tên truyện và nhấn Enter để tìm kiếm\n'
            '• Nhấn vào thể loại để xem truyện cùng loại\n'
            '• Sử dụng từ khóa tiếng Việt hoặc tiếng Anh',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThemeConstants.netflixLightGray
                      : ThemeConstants.netflixDarkGray,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTips(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tìm kiếm: "$query"',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThemeConstants.netflixWhite
                      : ThemeConstants.netflixNavy,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nhấn Enter để tìm kiếm\n'
            'Hoặc tiếp tục gõ để tinh chỉnh từ khóa',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? ThemeConstants.netflixLightGray
                      : ThemeConstants.netflixDarkGray,
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
            return _buildComicCard(comic, context);
          },
        );
      },
    );
  }

  Widget _buildGenreChip(String genreName, String genrePath, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          // Navigate to genre page (don't close search, let user navigate back naturally)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GenreComicsScreen(
                genreName: genreName,
                genreUrl: genrePath,
              ),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black,
                offset: const Offset(4, 4),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ThemeConstants.netflixWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.black,
                  width: 2.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getGenreIcon(genreName),
                    size: 16,
                    color: ThemeConstants.netflixRed,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    genreName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ThemeConstants.netflixRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGenreIcon(String genreName) {
    switch (genreName.toLowerCase()) {
      case 'action':
        return Icons.flash_on;
      case 'comedy':
        return Icons.sentiment_satisfied;
      case 'drama':
        return Icons.theater_comedy;
      case 'romance':
        return Icons.favorite;
      case 'fantasy':
        return Icons.auto_fix_high;
      case 'adventure':
        return Icons.explore;
      case 'slice of life':
        return Icons.home;
      case 'psychological':
        return Icons.psychology;
      case 'mystery':
        return Icons.psychology;
      case 'horror':
        return Icons.warning;
      case 'sci-fi':
        return Icons.rocket;
      case 'supernatural':
        return Icons.auto_fix_high;
      case 'historical':
        return Icons.history;
      case 'sports':
        return Icons.sports_soccer;
      case 'music':
        return Icons.music_note;
      default:
        return Icons.category;
    }
  }

  Widget _buildComicCard(Comic comic, BuildContext context) {
    return FutureBuilder<String>(
      future: DomainHelper.getCurrentDomain(),
      builder: (context, domainSnapshot) {
        if (!domainSnapshot.hasData) {
          return CustomComicCard(
            comic: comic,
            onTap: () {
              close(context, comic);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScreen(comic: comic),
                ),
              );
            },
          );
        }

        return CustomComicCard(
          comic: comic,
          domain: domainSnapshot.data!,
          columnCount: 2, // Search results use 2 columns
          onTap: () {
            close(context, comic);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(comic: comic),
              ),
            );
          },
        );
      },
    );
  }


}
