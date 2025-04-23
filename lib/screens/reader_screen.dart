import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/nettruyen_service.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> chapters;
  final int initialIndex;

  ReaderScreen({
    required this.chapters,
    this.initialIndex = 0,
  });

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int chapIndex;
  late Future<List<String>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    chapIndex = widget.initialIndex;
    _loadChapter();
  }

  void _loadChapter() {
    _pagesFuture =
        NetTruyenService().fetchChapterPages(widget.chapters[chapIndex]);
    setState(() {});
  }

  void _goChapter(int offset) {
    final newIndex = (chapIndex + offset)
        .clamp(0, widget.chapters.length - 1)
        .toInt();
    if (newIndex != chapIndex) {
      chapIndex = newIndex;
      _loadChapter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: FutureBuilder<List<String>>(
        future: _pagesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final pages = snap.data!;
          return ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: pages.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CachedNetworkImage(
                  imageUrl: pages[i],
                  httpHeaders: const {
                    'Referer': 'https://nettruyenvio.com'
                  },
                  placeholder: (context, _) =>
                      Center(child: CircularProgressIndicator()),
                  errorWidget: (context, _, __) =>
                      Center(child: Icon(Icons.broken_image)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
