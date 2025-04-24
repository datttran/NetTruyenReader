// lib/screens/reader_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/nettruyen_service.dart';
import 'package:flutter/scheduler.dart';

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
  List<String> _pages = [];
  List<String>? _nextPages;
  bool _isInitialLoading = true;
  bool _isAppending = false;

  // ◀ NEW ▶ store the pixel‐offset where each chapter begins
  final List<double> _chapterOffsets = [0.0];

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    chapIndex = widget.initialIndex;
    _scrollCtrl.addListener(_onScroll);
    _loadChapter(chapIndex);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChapter(int index, {bool append = false}) async {
    if (!append) setState(() => _isInitialLoading = true);

    final pages =
    await NetTruyenService().fetchChapterPages(widget.chapters[index]);

    setState(() {
      if (append)
        _pages.addAll(pages);
      else
        _pages = pages;
    });

    // once this chapter is visible, record its start offset
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _chapterOffsets[index] = _scrollCtrl.position.pixels;
    });

    // preload the next chapter in background
    _preloadNextChapter(index + 1);

    setState(() {
      _isInitialLoading = false;
      _isAppending = false;
    });
  }

  Future<void> _preloadNextChapter(int nextIndex) async {
    if (nextIndex >= widget.chapters.length) return;
    final pages =
    await NetTruyenService().fetchChapterPages(widget.chapters[nextIndex]);
    _nextPages = pages;
    for (var url in pages) {
      precacheImage(
        CachedNetworkImageProvider(url, headers: {'Referer': 'https://nettruyenvio.com'}),
        context,
      ).catchError((_) {});
    }
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    final cur = pos.pixels;

    // 1) append next chapter if you hit bottom
    if (!_isAppending &&
        _nextPages != null &&
        cur >= pos.maxScrollExtent - 100 &&
        chapIndex < widget.chapters.length - 1) {
      setState(() => _isAppending = true);
      chapIndex++;
      _pages.addAll(_nextPages!);
      _nextPages = null;

      // record the offset for this new chapter
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _chapterOffsets.add(_scrollCtrl.position.pixels);
      });

      _preloadNextChapter(chapIndex + 1);
      // hide spinner
      setState(() => _isAppending = false);
    }

    // 2) figure out which chapter you're in now
    for (var i = _chapterOffsets.length - 1; i >= 0; i--) {
      if (cur >= _chapterOffsets[i] - 50) {
        if (chapIndex != i) {
          setState(() => chapIndex = i);
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Chapter ${chapIndex + 1}')),
      body: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pages.length + (_isAppending ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _pages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CachedNetworkImage(
              imageUrl: _pages[i],
              httpHeaders: const {'Referer': 'https://nettruyenvio.com'},
              placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image)),
            ),
          );
        },
      ),
    );
  }
}
