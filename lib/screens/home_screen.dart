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
import 'cloudflare_bypass_screen.dart';
import '../services/comic_search_delegate.dart';
import 'genre_comics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Comic> _allComics = []; // Changed from final
  List<Comic> _displayComics = []; // Changed from final
  final ScrollController _scrollController = ScrollController();
  
  static const int _pageSize = 12;
  bool _isLoading = false;
  bool _hasMore = true;
  
  String? _lastUsedDomain;
  final _thumbCacheManager = DefaultCacheManager();

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
  }

  /// CRITICAL: DO NOT CHANGE THIS METHOD! This method initializes the last used domain
  /// to track changes when returning from settings. It's essential for the auto-reload
  /// functionality to work properly.
  Future<void> _initializeLastUsedDomain() async {
    _lastUsedDomain = await NetTruyenService().getCurrentDomain();
    print('🔍 Initialized last used domain: $_lastUsedDomain');
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
    print('🔍 Checking domain change: $_lastUsedDomain -> $currentDomain');
    
    if (_lastUsedDomain != null && _lastUsedDomain != currentDomain) {
      print('🔍 Domain changed from $_lastUsedDomain to $currentDomain, reloading content...');
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

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    
    setState(() => _isLoading = true);

    try {
      if (_allComics.isEmpty) {
        print('🔍 Loading comics from home screen...');
        _allComics = await NetTruyenService().fetchComics();
        print('🔍 Loaded ${_allComics.length} comics');
        _applyDeduplication();
        print('🔍 After deduplication: ${_allComics.length} comics');
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
      print('❌ Error loading comics: $e');
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: RefreshIndicator(
        onRefresh: () async {
          _allComics = await NetTruyenService().fetchComics();
          _applyDeduplication();
          setState(() {
            _displayComics = _allComics.take(_pageSize).toList();
            _hasMore = _allComics.length > _displayComics.length;
          });
        },
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
                      print('🔍 Returning from settings, checking for domain changes...');
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
                    Text(
                      'Thể loại phổ biến',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          {'name': 'Action', 'path': '/tim-truyen/action-95'},
                          {'name': 'Comedy', 'path': '/tim-truyen/comedy-99'},
                          {'name': 'Drama', 'path': '/tim-truyen/drama-103'},
                          {'name': 'Romance', 'path': '/tim-truyen/romance-121'},
                          {'name': 'Fantasy', 'path': '/tim-truyen/fantasy-100'},
                          {'name': 'Adventure', 'path': '/tim-truyen/adventure-101'},
                          {'name': 'Slice of Life', 'path': '/tim-truyen/slice-of-life'},
                          {'name': 'Psychological', 'path': '/tim-truyen/psychological'},
                        ].map((genre) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              label: Text(genre['name']!),
                              onPressed: () {
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
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              labelStyle: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
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
                                          print('🔍 Thumbnail loaded successfully: ${comic.title}');
                                          return Image(
                                            image: provider,
                                            fit: BoxFit.cover,
                                          );
                                        },
                                        placeholder: (ctx, url) {
                                          print('🔍 Loading thumbnail: $url');
                                          print('🔍 Using Referer: ${_getCurrentDomainForHeaders()}');
                                          return Shimmer.fromColors(
                                            baseColor: Colors.grey[800]!,
                                            highlightColor: Colors.grey[600]!,
                                            child: Container(color: Colors.grey[700]),
                                          );
                                        },
                                        errorWidget: (ctx, url, error) {
                                          print('❌ Thumbnail failed to load: $url');
                                          print('❌ Error: $error');
                                          print('❌ Using Referer: ${_getCurrentDomainForHeaders()}');
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