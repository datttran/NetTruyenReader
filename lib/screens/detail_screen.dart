// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import 'reader_screen.dart';

class DetailScreen extends StatefulWidget {
  final Comic comic;
  const DetailScreen({Key? key, required this.comic}) : super(key: key);

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<List<String>> _chaptersFuture;

  // reuse the same thumbnail cache as HomeScreen
  final _thumbCache = CacheManager(
    Config('thumbCache', maxNrOfCacheObjects: 200),
  );

  @override
  void initState() {
    super.initState();
    // fetch the full chapter list (including “Xem thêm” expansion)
    _chaptersFuture = NetTruyenService().fetchChapters(widget.comic.detailUrl);
  }

  void _openReader(List<String> chapters, int index) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        chapters: chapters,
        initialIndex: index,
        // if you want to save last read, pass your prefs‐saving callback here:

      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.comic.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) cover image
          Expanded(
            flex: 2,
            child: Hero(
              tag: widget.comic.imageUrl,
              child: CachedNetworkImage(
                cacheManager: _thumbCache,
                imageUrl: widget.comic.imageUrl,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2) title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.comic.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),

          const SizedBox(height: 12),

          // 3) Read Now + chapter list
          Expanded(
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

                final chapters = snap.data ?? [];
                if (chapters.isEmpty) {
                  return const Center(child: Text('No chapters found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: chapters.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      // “Read Now” always opens chapter 1
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ElevatedButton(
                          onPressed: () => _openReader(chapters, 0),
                          child: const Text('Read Now'),
                        ),
                      );
                    }
                    final chapIndex = i - 1;
                    return ListTile(
                      title: Text('Chapter ${chapIndex + 1}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openReader(chapters, chapIndex),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
