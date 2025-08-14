// lib/screens/home_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import '../constants/app_constants.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';
import '../services/comic_search_delegate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Comic> _allComics = []; // Changed from final
  List<Comic> _displayComics = []; // Changed from final
  List<Comic> _filteredComics = []; // Comics filtered by selected genre
  final ScrollController _scrollController = ScrollController();
  
  static const int _pageSize = 12;
  bool _isLoading = false;
  bool _hasMore = true;
  
  String? _lastUsedDomain;
  final _thumbCacheManager = DefaultCacheManager();
  
  // Genre filtering state
  String _selectedGenre = 'Phổ biến'; // Default to popular
  String? _selectedGenrePath;
  bool _isFilteringByGenre = false;
  
  // Genre caching
  final Map<String, List<Comic>> _genreCache = {};
  final Map<String, DateTime> _genreCacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 10); // Cache for 10 minutes
  
  // Popular comics caching
  static const String _popularCacheKey = 'popular';

  @override
  void initState() {
    super.initState();
    _loadMore();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent * 0.8 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
    
    _initializeLastUsedDomain();
    
    // Clear expired cache entries on app start
    _clearExpiredCache();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method initializes the last used domain
  /// to track changes when returning from settings. It's essential for the auto-reload
  /// functionality to work properly.
  Future<void> _initializeLastUsedDomain() async {
    _lastUsedDomain = await NetTruyenService().getCurrentDomain();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method gets the current domain for use in headers.
  /// It ensures that thumbnails are loaded with the correct Referer header.
  String _getCurrentDomainForHeaders() {
    return _lastUsedDomain ?? AppConstants.PRIMARY_DOMAIN;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndReloadIfNeeded();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method checks if the domain has changed
  /// since the last check and triggers a content reload if needed. It's essential for
  /// the automatic content refresh functionality when returning from settings.
  Future<void> _checkAndReloadIfNeeded() async {
    final currentDomain = await NetTruyenService().getCurrentDomain();
    
    if (_lastUsedDomain != null && _lastUsedDomain != currentDomain) {
      _reloadContent();
    }
    _lastUsedDomain = currentDomain;
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method completely reloads the content
  /// by clearing existing comics and triggering a fresh load. It's essential for
  /// ensuring that content from the new domain is displayed properly.
  Future<void> _reloadContent() async {
    setState(() {
      _allComics.clear();
      _displayComics.clear();
      _hasMore = true;
    });
    await _loadMore();
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method handles thumbnail loading failures
  /// by silently removing the failed comic from both the all comics list and display list.
  /// It's essential for maintaining a clean UI without broken thumbnails.
  void _onThumbnailFailed(String imageUrl) {
    setState(() {
      _allComics.removeWhere((comic) => comic.imageUrl == imageUrl);
      _displayComics.removeWhere((comic) => comic.imageUrl == imageUrl);
      _hasMore = _displayComics.length < _allComics.length;
    });
  }

  String _cleanTitle(String title) {
    return title.replaceFirst(RegExp(r'^[Tt]ruyện tranh\s*'), '').trim();
  }
  
  /// Filter comics by selected genre
  Future<void> _filterByGenre(String genreName, String genrePath) async {
    if (_selectedGenre == genreName && _isFilteringByGenre) {
      // Same genre selected, do nothing
      return;
    }
    
    setState(() {
      _isLoading = true;
      _selectedGenre = genreName;
      _selectedGenrePath = genrePath;
      _isFilteringByGenre = true;
      _displayComics.clear();
      _hasMore = true;
    });
    
    try {
      // Check cache first
      final cachedData = _getCachedGenreData(genrePath);
      if (cachedData != null) {
        _filteredComics = cachedData;
      } else {
        _filteredComics = await NetTruyenService().fetchComicsByGenre(genrePath);
        
        // Cache the fetched data
        _cacheGenreData(genrePath, _filteredComics);
      }
      
      // Apply deduplication to filtered comics
      _applyDeduplicationToFiltered();
      
      // Show first page of filtered comics
      final newItems = _filteredComics.take(_pageSize).toList();
      setState(() {
        _displayComics = newItems;
        _hasMore = _filteredComics.length > _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFilteringByGenre = false;
        _selectedGenre = 'Phổ biến';
        _selectedGenrePath = null;
      });
    }
  }
  
  /// Show all comics (clear genre filter)
  Future<void> _showAllComics() async {
    setState(() {
      _isLoading = true;
      _isFilteringByGenre = false;
      _selectedGenre = 'Phổ biến';
      _selectedGenrePath = null;
      _filteredComics.clear();
      _displayComics.clear();
      _hasMore = true;
    });
    
    // Check cache first for popular comics
    final cachedPopularData = _getCachedGenreData(_popularCacheKey);
    if (cachedPopularData != null) {
      _allComics = cachedPopularData;
    } else {
      _allComics = await NetTruyenService().fetchComics();
      _applyDeduplication();
      
      // Cache the popular comics
      _cacheGenreData(_popularCacheKey, _allComics);
    }
    
    // Show first page of popular comics
    final newItems = _allComics.take(_pageSize).toList();
    setState(() {
      _displayComics = newItems;
      _hasMore = _allComics.length > _pageSize;
      _isLoading = false;
    });
  }

  /// Apply deduplication to filtered comics
  void _applyDeduplicationToFiltered() {
    final map = <String, Comic>{};
    for (var comic in _filteredComics) {
      final key = _cleanTitle(comic.title);
      if (!map.containsKey(key)) {
        map[key] = Comic(
          title: key,
          imageUrl: comic.imageUrl,
          detailUrl: comic.detailUrl,
        );
      }
    }
    _filteredComics = map.values.toList();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);

    try {
      if (_isFilteringByGenre) {
        // Loading more filtered comics
        if (_filteredComics.isEmpty) return;
        
        final currentCount = _displayComics.length;
        final newItems = _filteredComics
            .skip(currentCount)
            .take(_pageSize)
            .toList();
            
        setState(() {
          _displayComics.addAll(newItems);
          _hasMore = _displayComics.length < _filteredComics.length;
        });
      } else {
        // Loading more all comics
        if (_allComics.isEmpty) {
          // Check cache first for popular comics
          final cachedPopularData = _getCachedGenreData(_popularCacheKey);
          if (cachedPopularData != null) {
            _allComics = cachedPopularData;
          } else {
            _allComics = await NetTruyenService().fetchComics();
            _applyDeduplication();
            
            // Cache the popular comics
            _cacheGenreData(_popularCacheKey, _allComics);
          }
        }

        final newItems = _allComics
            .skip(_displayComics.length)
            .take(_pageSize)
            .toList();

        setState(() {
          _displayComics.addAll(newItems);
          _hasMore = _displayComics.length < _allComics.length;
        });
      }

      final newItems = _allComics
          .skip(_displayComics.length)
          .take(_pageSize)
          .toList();

      setState(() {
        _displayComics.addAll(newItems);
        _hasMore = _displayComics.length < _allComics.length;
      });
    } catch (e) {
      // Error loading comics
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyDeduplication() {
    final map = <String, Comic>{};
    for (var comic in _allComics) {
      final key = _cleanTitle(comic.title);
      if (!map.containsKey(key)) {
        map[key] = Comic(
          title: key,
          imageUrl: comic.imageUrl,
          detailUrl: comic.detailUrl,
        );
      }
    }
    _allComics = map.values.toList();
  }
  
  /// Check if cached genre data is still valid
  bool _isGenreCacheValid(String genrePath) {
    if (!_genreCache.containsKey(genrePath)) return false;
    
    final timestamp = _genreCacheTimestamps[genrePath];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Get cached genre data if available and valid
  List<Comic>? _getCachedGenreData(String genrePath) {
    if (_isGenreCacheValid(genrePath)) {
      return _genreCache[genrePath];
    }
    return null;
  }

  /// Cache genre data with timestamp
  void _cacheGenreData(String genrePath, List<Comic> comics) {
    _genreCache[genrePath] = comics;
    _genreCacheTimestamps[genrePath] = DateTime.now();
  }

  /// Clear cache for a specific genre
  void _clearGenreCache(String genrePath) {
    _genreCache.remove(genrePath);
    _genreCacheTimestamps.remove(genrePath);
  }

  /// Clear all expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _genreCacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _genreCache.remove(key);
      _genreCacheTimestamps.remove(key);
    }
  }
  
  /// Refresh content (pull to refresh)
  Future<void> _onRefresh() async {
    if (_isFilteringByGenre) {
      // Refresh filtered comics (clear cache and re-fetch)
      _clearGenreCache(_selectedGenrePath!);
      await _filterByGenre(_selectedGenre!, _selectedGenrePath!);
    } else {
      // Refresh popular comics (clear cache and re-fetch)
      _clearGenreCache(_popularCacheKey);
      _allComics = await NetTruyenService().fetchComics();
      _applyDeduplication();
      
      // Cache the fresh popular comics
      _cacheGenreData(_popularCacheKey, _allComics);
      
      setState(() {
        _displayComics = _allComics.take(_pageSize).toList();
        _hasMore = _allComics.length > _pageSize;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Build a genre chip with proper styling
  Widget _buildGenreChip(String genreName, String genrePath) {
    final isSelected = _selectedGenre == genreName;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(genreName),
        onPressed: () {
          if (genreName == 'Phổ biến') {
            _showAllComics();
          } else {
            _filterByGenre(genreName, genrePath);
          }
        },
        backgroundColor: isSelected 
            ? Theme.of(context).primaryColor
            : Theme.of(context).primaryColor.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Theme.of(context).primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar that hides when scrolling up
            SliverAppBar(
              title: Text(AppConstants.APP_NAME),
              floating: true,
              pinned: false,
              snap: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () async {
                    final comic = await showSearch(
                      context: context,
                      delegate: ComicSearchDelegate(),
                    );
                    if (comic != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(comic: comic),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                                          if (result == true) {
                        await _checkAndReloadIfNeeded();
                      }
                  },
                ),
              ],
            ),
            // Popular Genres Section
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thể loại: $_selectedGenre',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildGenreChip('Phổ biến', ''), // Popular tab - shows all comics
                          _buildGenreChip('Action', '/tim-truyen/action-95'),
                          _buildGenreChip('Comedy', '/tim-truyen/comedy-99'),
                          _buildGenreChip('Drama', '/tim-truyen/drama-103'),
                          _buildGenreChip('Romance', '/tim-truyen/romance-121'),
                          _buildGenreChip('Fantasy', '/tim-truyen/fantasy-100'),
                          _buildGenreChip('Adventure', '/tim-truyen/adventure-101'),
                          _buildGenreChip('Slice of Life', '/tim-truyen/slice-of-life'),
                          _buildGenreChip('Psychological', '/tim-truyen/psychological'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Comics Grid
            _displayComics.isEmpty
                ? SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Shimmer.fromColors(
                            baseColor: Colors.grey[800]!,
                            highlightColor: Colors.grey[600]!,
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700],
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 16,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: 12,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  )
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= _displayComics.length) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final comic = _displayComics[index];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailScreen(comic: comic)),
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
                                      child: CachedNetworkImage(
                                        cacheManager: _thumbCacheManager,
                                        imageUrl: comic.imageUrl,
                                        httpHeaders: {'Referer': _getCurrentDomainForHeaders()},
                                                                                 imageBuilder: (ctx, provider) {
                                           return Image(
                                             image: provider,
                                             fit: BoxFit.cover,
                                           );
                                         },
                                                                                 placeholder: (ctx, url) {
                                           return Shimmer.fromColors(
                                             baseColor: Colors.grey[800]!,
                                             highlightColor: Colors.grey[600]!,
                                             child: Container(color: Colors.grey[700]),
                                           );
                                         },
                                                                                 errorWidget: (ctx, url, error) {
                                           WidgetsBinding.instance.addPostFrameCallback((_) {
                                             _onThumbnailFailed(url);
                                           });
                                           return const Center(child: Icon(Icons.broken_image, size: 40));
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
                      childCount: _displayComics.length + (_hasMore ? 1 : 0),
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final comic = await showSearch(
            context: context,
            delegate: ComicSearchDelegate(),
          );
          if (comic != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScreen(comic: comic),
              ),
            );
          }
        },
        child: const Icon(Icons.search),
        tooltip: 'Tìm kiếm truyện',
      ),
    );
  }


}