// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/nettruyen_service.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> chapters;
  final int initialIndex;

  const ReaderScreen({
    Key? key,
    required this.chapters,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int chapIndex;
  List<String>? _pages;
  bool _isLoadingNext = false;
  bool _isInitialLoading = true;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    chapIndex = widget.initialIndex;
    _loadChapter(chapIndex);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapter(int index, {bool append = false}) async {
    if (!append) {
      setState(() {
        _isInitialLoading = true;
      });
    }
    try {
      final pages = await NetTruyenService()
          .fetchChapterPages(widget.chapters[index]);
      setState(() {
        if (append && _pages != null) {
          _pages!.addAll(pages);
        } else {
          _pages = pages;
        }
      });
    } catch (e) {
      // handle error / show toast if you want
    } finally {
      setState(() {
        _isInitialLoading = false;
        _isLoadingNext = false;
      });
    }
  }

  void _onScroll() {
    if (_pages == null || _isLoadingNext) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final cur = _scrollCtrl.position.pixels;
    if (cur >= max - 100 && chapIndex < widget.chapters.length - 1) {
      _isLoadingNext = true;
      chapIndex++;
      _loadChapter(chapIndex, append: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // initial loading
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = _pages!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${chapIndex + 1}'),
      ),
      body: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pages.length + (_isLoadingNext ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == pages.length) {
            // loading spinner at bottom
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CachedNetworkImage(
              imageUrl: pages[i],
              httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
              placeholder: (ctx, _) => const Center(child: CircularProgressIndicator()),
              errorWidget: (ctx, _, __) =>
              const Center(child: Icon(Icons.broken_image)),
            ),
          );
        },
      ),
    );
  }
}
