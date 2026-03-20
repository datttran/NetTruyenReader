// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../services/database_helper.dart';
import 'reader_screen.dart';
import '../services/comic_search_delegate.dart';
import '../constants/app_constants.dart';
import '../constants/theme_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'genre_comics_screen.dart';

class DetailScreen extends StatefulWidget {
  final Comic comic;
  const DetailScreen({Key? key, required this.comic}) : super(key: key);

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<List<String>> _chaptersFuture;
  late Future<Comic> _comicFuture;

  // reuse the same thumbnail cache as HomeScreen
  final _thumbCache = CacheManager(
    Config(AppConstants.THUMB_CACHE_KEY, maxNrOfCacheObjects: AppConstants.CACHE_MAX_OBJECTS),
  );

  late VideoPlayerController _bgController;
  bool _bgReady = false;

  @override
  void initState() {
    super.initState();
    // fetch the full chapter list (including "Xem thêm" expansion)
    _chaptersFuture = NetTruyenService().fetchChapters(widget.comic.detailUrl);
    // fetch the full-size image URL
    _comicFuture = NetTruyenService().updateComicWithDetails(widget.comic);

    _bgController = VideoPlayerController.asset('assets/animations/BGM.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _bgReady = true);
          _bgController.play();
        }
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Widget _videoBg() {
    if (!_bgReady) return const SizedBox.shrink();
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _bgController.value.size.width,
            height: _bgController.value.size.height,
            child: VideoPlayer(_bgController),
          ),
        ),
        // Darken overlay so text stays readable
        const ColoredBox(color: Color(0xE8000000)),
      ],
    );
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  Future<String> _getCurrentDomainForHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('custom_domain') ?? AppConstants.PRIMARY_DOMAIN;
  }

  void _openReader(List<String> chapters, int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        chapters: chapters,
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.comic.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(child: _videoBg()),
          SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Space for transparent AppBar
            const SizedBox(height: kToolbarHeight + 16),
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
                          const SizedBox(width: 10,),
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
                                      child: const Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  
                                  return CachedNetworkImage(
                                    cacheManager: _thumbCache,
                                    imageUrl: comic.imageUrl,
                                    width: 150,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    httpHeaders: {'Referer': domainSnapshot.data!},
                                    placeholder: (_, __) => Container(
                                      width: 150,
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
                                  );
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Details
                          Expanded(
                            child: snapshot.connectionState != ConnectionState.done
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (comic.status?.isNotEmpty == true) 
                                      _buildInfoRow('Tình trạng:', comic.status!),
                                    if (comic.author?.isNotEmpty == true) 
                                      _buildInfoRow('Tác giả:', comic.author!),
                                    if (comic.views?.isNotEmpty == true) 
                                      _buildInfoRow('Lượt xem:', comic.views!),
                                    if (comic.genres.isNotEmpty)
                                      _buildGenresRow('Thể loại:', comic.genres)
                                    else
                                      _buildInfoRow('Thể loại:', 'Đang cập nhật'),
                                    
                                    // Show message if no details are available
                                    if ((comic.status?.isEmpty ?? true) && 
                                         (comic.author?.isEmpty ?? true) && 
                                         (comic.views?.isEmpty ?? true) && 
                                         comic.genres.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Đang tải thông tin chi tiết...',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    
                                    const SizedBox(height: 16),
                                    
                                    // Last updated time
                                    Text(
                                      'Cập nhật lúc: ${DateTime.now().toString().substring(0, 16)}',
                                      style: Theme.of(context).textTheme.bodySmall,
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
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: chapters.isEmpty ? null : () => _openReader(chapters, 0),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Đọc từ đầu'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: chapters.isEmpty ? null : () => _openReader(chapters, chapters.length - 1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Đọc mới nhất'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: ComicSearchDelegate(),
                              query: '',
                            );
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Tìm truyện tương tự'),
                        ),
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
                    return const Center(
                      child: Image(
                        image: AssetImage('assets/images/banner-sword.gif'),
                        height: 160,
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('Error loading chapters:\n${snap.error}'),
                    );
                  }

                  final chapters = snap.data ?? [];
                  if (chapters.isEmpty) {
                    return const Center(child: Text('No chapters found.'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text('Chapter ${chapters.length - index}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openReader(chapters, index),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
        ],
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
                        decorationColor: ThemeConstants.netflixRed.withOpacity(0.7),
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
}