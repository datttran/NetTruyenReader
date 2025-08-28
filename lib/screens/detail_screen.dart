// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../services/comic_search_delegate.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import 'reader_screen.dart';
import 'genre_comics_screen.dart';

class DetailScreen extends StatefulWidget {
  final Comic comic;
  const DetailScreen({Key? key, required this.comic}) : super(key: key);

  @override
  DetailScreenState createState() => DetailScreenState();
}

class DetailScreenState extends State<DetailScreen> {
  late Future<Comic> _comicFuture;
  late Future<List<String>> _chaptersFuture;
  late CacheManager _thumbCache;
  String? _lastUsedDomain;

  @override
  void initState() {
    super.initState();
    _comicFuture = NetTruyenService().updateComicWithDetails(widget.comic);
    _chaptersFuture = NetTruyenService().fetchChapters(widget.comic.detailUrl);
    _thumbCache = CacheManager(Config(AppConstants.THUMB_CACHE_KEY));
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  Future<String> _getCurrentDomainForHeaders() async {
    if (_lastUsedDomain != null) {
      return _lastUsedDomain!;
    }
    return AppConstants.PRIMARY_DOMAIN;
  }

  void _openReader(List<String> chapters, int chapterIndex) {
    if (chapterIndex >= 0 && chapterIndex < chapters.length) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReaderScreen(
            chapters: chapters,
            initialIndex: chapterIndex,
          ),
        ),
      );
    }
  }

  // Extract chapter number from chapter URL or title
  int _extractChapterNumber(String chapterUrl) {
    try {
      // Try to extract chapter number from URL patterns
      // Common patterns: chapter-123, chapter123, chap-123, etc.
      final regex = RegExp(r'chapter[_-]?(\d+)', caseSensitive: false);
      final match = regex.firstMatch(chapterUrl);
      if (match != null && match.groupCount >= 1) {
        return int.parse(match.group(1)!);
      }
      
      // Try to find any number in the URL
      final numberRegex = RegExp(r'(\d+)');
      final numberMatch = numberRegex.firstMatch(chapterUrl);
      if (numberMatch != null) {
        return int.parse(numberMatch.group(1)!);
      }
      
      // If no pattern found, return 0 as fallback
      return 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh both comic details and chapters
          setState(() {
            _comicFuture =
                NetTruyenService().forceRefreshComicDetails(widget.comic);
            _chaptersFuture =
                NetTruyenService().fetchChapters(widget.comic.detailUrl);
          });
        },
        child: CustomScrollView(
          slivers: [
            // Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section with image and details
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: FutureBuilder<Comic>(
                      future: _comicFuture,
                      builder: (context, snapshot) {
                        final comic = snapshot.data ?? widget.comic;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // Image and info side by side
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 10,
                                ),
                                // Cover image
                                Hero(
                                  tag: comic.imageUrl,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: FutureBuilder<String>(
                                      future: _getCurrentDomainForHeaders(),
                                      builder: (context, domainSnapshot) {
                                        if (!domainSnapshot.hasData) {
                                          return Container(
                                            width: 150,
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(
                                                child: CircularProgressIndicator()),
                                          );
                                        }

                                        return CachedNetworkImage(
                                          cacheManager: _thumbCache,
                                          imageUrl: comic.imageUrl,
                                          width: 150,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          httpHeaders: {
                                            'Referer': domainSnapshot.data!
                                          },
                                          placeholder: (_, __) => Container(
                                            width: 150,
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(
                                                child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (_, __, ___) => const Icon(
                                              Icons.broken_image,
                                              size: 80),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Details
                                Expanded(
                                  child: snapshot.connectionState !=
                                          ConnectionState.done
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (comic.status?.isNotEmpty == true)
                                              _buildInfoRow(
                                                  'Tình trạng:', comic.status!),
                                            if (comic.author?.isNotEmpty == true)
                                              _buildInfoRow(
                                                  'Tác giả:', comic.author!),
                                            if (comic.views?.isNotEmpty == true)
                                              _buildInfoRow(
                                                  'Lượt xem:', comic.views!),
                                            if (comic.genres.isNotEmpty)
                                              _buildGenresRow(
                                                  'Thể loại:', comic.genres)
                                            else
                                              _buildInfoRow(
                                                  'Thể loại:', 'Đang cập nhật'),

                                            // Show message if no details are available
                                            if ((comic.status?.isEmpty ?? true) &&
                                                (comic.author?.isEmpty ?? true) &&
                                                (comic.views?.isEmpty ?? true) &&
                                                comic.genres.isEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(top: 8),
                                                child: Text(
                                                  'Đang tải thông tin chi tiết...',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                ),
                                              ),

                                            const SizedBox(height: 16),

                                            // Last updated time
                                            Text(
                                              'Cập nhật lúc: ${DateTime.now().toString().substring(0, 16)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FutureBuilder<List<String>>(
                      future: _chaptersFuture,
                      builder: (context, snapshot) {
                        final chapters = snapshot.data ?? [];
                        final isLoading = snapshot.connectionState != ConnectionState.done;
                        
                        return Column(
                          children: [
                            // Top row: Read from beginning and Read latest
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    onPressed: chapters.isEmpty || isLoading
                                        ? null
                                        : () => _openReader(chapters, 0),
                                    text: 'Đọc từ đầu',
                                    icon: Icons.play_arrow,
                                    backgroundColor: isLoading 
                                        ? ThemeConstants.netflixRed.withValues(alpha: 0.6)
                                        : ThemeConstants.netflixRed,
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildActionButton(
                                    onPressed: chapters.isEmpty || isLoading
                                        ? null
                                        : () => _openReader(
                                            chapters, chapters.length - 1),
                                    text: 'Đọc mới nhất',
                                    icon: Icons.new_releases,
                                    backgroundColor: isLoading 
                                        ? Colors.orange.withValues(alpha: 0.6)
                                        : Colors.orange,
                                    isPrimary: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Bottom row: Find similar comics
                            _buildActionButton(
                              onPressed: isLoading ? null : () {
                                showSearch(
                                  context: context,
                                  delegate: ComicSearchDelegate(),
                                  query: '',
                                );
                              },
                              text: 'Tìm truyện tương tự',
                              icon: Icons.search,
                              backgroundColor: isLoading 
                                  ? ThemeConstants.netflixDarkGray.withValues(alpha: 0.6)
                                  : ThemeConstants.netflixDarkGray,
                              isPrimary: false,
                              isFullWidth: true,
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Chapter list
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FutureBuilder<List<String>>(
                      future: _chaptersFuture,
                      builder: (ctx, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text('Error loading chapters:\n${snap.error}'),
                          );
                        }

                        final allChapters = snap.data ?? [];
                        if (allChapters.isEmpty) {
                          return const Center(child: Text('No chapters found.'));
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chapter order switch
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Danh sách chương (${allChapters.length} chương)',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Chapter list
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: allChapters.length,
                              itemBuilder: (context, index) {
                                final chapterUrl = allChapters[index];
                                final actualChapterNumber = _extractChapterNumber(chapterUrl);
                                
                                // If we can't extract a chapter number, fall back to index-based numbering
                                final displayChapterNumber = actualChapterNumber > 0 
                                    ? actualChapterNumber 
                                    : (allChapters.length - index);

                                return ListTile(
                                  title: Text('Chapter $displayChapterNumber'),
                                  subtitle: Text(
                                    chapterUrl,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _openReader(allChapters, index),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresRow(String label, List<Genre> genres) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: genres.map((genre) {
                return GestureDetector(
                  onTap: () {
                    // Navigate to genre page to show comics of this genre
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GenreComicsScreen(
                          genreName: genre.name,
                          genreUrl: genre.url,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Text(
                      genre.name,
                      style: TextStyle(
                        color: ThemeConstants.netflixRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            ThemeConstants.netflixRed.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    required Color backgroundColor,
    bool isPrimary = true,
    bool isFullWidth = false,
  }) {
    Widget button = Container(
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
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0, // Remove default elevation since we have custom shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    
    // Return the button directly - let the parent Row handle the Expanded logic
    return button;
  }
}
