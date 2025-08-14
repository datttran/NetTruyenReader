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
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _calculateOptimalCardWidth(),
                childAspectRatio: _calculateOptimalAspectRatio(),
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
                        // Image container that takes 80% of card height
                        Flexible(
                          flex: 8,
                          child: Hero(
                            tag: comic.imageUrl,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: FutureBuilder<bool>(
                                future: _isImageCached(comic.imageUrl),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return Container(
                                      width: double.infinity,
                                      height: double.infinity,
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
                                      width: double.infinity,
                                      height: double.infinity,
                                      placeholder: (_, __) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[300],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[300],
                                        child: const Center(child: Icon(Icons.broken_image, size: 40)),
                                      ),
                                    );
                                  } else {
                                    // Load from web and cache it
                                    return CachedNetworkImage(
                                      cacheManager: _thumbCache,
                                      imageUrl: comic.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      placeholder: (_, __) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[700],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        width: double.infinity,
                                        height: double.infinity,
                                        color: Colors.grey[700],
                                        child: const Center(child: Icon(Icons.broken_image, size: 40)),
                                      ),
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
                        // Text section that takes 20% of card height
                        Flexible(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                                                      child: Text(
                            comic.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).brightness == Brightness.dark 
                                  ? Colors.white 
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
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

  /// Calculate optimal card width based on screen size and constraints
  double _calculateOptimalCardWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Use different percentages based on screen size breakpoints
    double cardWidthPercent;
    if (screenWidth < 600.0) {
      cardWidthPercent = 0.42; // Mobile: 2 columns
    } else if (screenWidth < 900.0) {
      cardWidthPercent = 0.28; // Tablet: 3-4 columns
    } else {
      cardWidthPercent = 0.22; // Desktop: 4-5 columns
    }
    
    final calculatedWidth = screenWidth * cardWidthPercent;
    
    // Apply min/max constraints
    return calculatedWidth.clamp(120.0, 200.0);
  }

  /// Calculate optimal aspect ratio based on screen dimensions
  double _calculateOptimalAspectRatio() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate aspect ratio based on screen proportions
    final widthRatio = screenWidth / screenHeight;
    
    // Adjust aspect ratio based on screen orientation and size
    if (widthRatio > 1.0) {
      // Landscape or wide screen - use wider cards
      return 0.7;
    } else if (widthRatio < 0.6) {
      // Very narrow screen (mobile portrait) - use taller cards
      return 0.6;
    } else {
      // Standard mobile portrait - use balanced aspect ratio
      return 0.65;
    }
  }

} 