// lib/screens/genre_comics_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../constants/app_constants.dart';
import 'detail_screen.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class GenreComicsScreen extends StatefulWidget {
  final String genreName;
  final String genreUrl;

  const GenreComicsScreen({
    Key? key,
    required this.genreName,
    required this.genreUrl,
  }) : super(key: key);

  @override
  _GenreComicsScreenState createState() => _GenreComicsScreenState();
}

class _GenreComicsScreenState extends State<GenreComicsScreen> {
  late Future<List<Comic>> _comicsFuture;
  final _thumbCache = CacheManager(
    Config('genre_thumb_cache_${DateTime.now().millisecondsSinceEpoch}', maxNrOfCacheObjects: AppConstants.CACHE_MAX_OBJECTS),
  );

  @override
  void initState() {
    super.initState();
    _comicsFuture = NetTruyenService().fetchComicsByGenre(widget.genreUrl);
  }

  Future<bool> _isImageCached(String imageUrl) async {
    try {
      final fileInfo = await _thumbCache.getFileFromCache(imageUrl);
      return fileInfo != null;
    } catch (e) {
      print('🔍 Cache check error for $imageUrl: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.genreName} Comics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Comic>>(
        future: _comicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading ${widget.genreName} comics',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _comicsFuture = NetTruyenService().fetchComicsByGenre(widget.genreUrl);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final comics = snapshot.data ?? [];
          if (comics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.genreName} comics found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different genre or check back later',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _thumbCache.emptyCache();
              print('🔍 Cleared genre thumbnail cache for fresh loading');
              setState(() {
                _comicsFuture = NetTruyenService().fetchComicsByGenre(widget.genreUrl);
              });
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.65,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: comics.length,
              itemBuilder: (context, index) {
                final comic = comics[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScreen(comic: comic),
                    ),
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Hero(
                            tag: comic.imageUrl,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: FutureBuilder<bool>(
                                future: _isImageCached(comic.imageUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  
                                  final isCached = snapshot.data ?? false;
                                  
                                  if (isCached) {
                                    // Use cached image
                                    return CachedNetworkImage(
                                      cacheManager: _thumbCache,
                                      imageUrl: comic.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                    );
                                  } else {
                                    // Load from web and cache it
                                    return CachedNetworkImage(
                                      cacheManager: _thumbCache,
                                      imageUrl: comic.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Colors.grey[300],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                                      httpHeaders: {
                                        'Referer': 'https://nettruyenvia.com',
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            comic.title,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
} 