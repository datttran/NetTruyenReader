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
  late Future<Comic> _comicFuture;

  // reuse the same thumbnail cache as HomeScreen
  final _thumbCache = CacheManager(
    Config('thumbCache', maxNrOfCacheObjects: 200),
  );

  @override
  void initState() {
    super.initState();
    // fetch the full chapter list (including "Xem thêm" expansion)
    _chaptersFuture = NetTruyenService().fetchChapters(widget.comic.detailUrl);
    // fetch the full-size image URL
    _comicFuture = NetTruyenService().updateComicWithDetails(widget.comic);
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
      appBar: AppBar(title: Text(widget.comic.title)),
      body: SingleChildScrollView(
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
                          SizedBox(width: 10,),
                          // Cover image
                          Hero(
                            tag: comic.imageUrl,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                cacheManager: _thumbCache,
                                imageUrl: comic.imageUrl,
                                width: 150,
                                height: 200,
                                fit: BoxFit.cover,
                                httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
                                placeholder: (_, __) => Container(
                                  width: 150,
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
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
                                      _buildInfoRow('Thể loại:', comic.genres.join(', ')),
                                    
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
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: chapters.isEmpty ? null : () => _openReader(chapters, 0),
                          child: const Text('Đọc từ đầu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: chapters.isEmpty ? null : () => _openReader(chapters, chapters.length - 1),
                          child: const Text('Đọc mới nhất'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
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
}