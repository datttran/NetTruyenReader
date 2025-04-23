import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../services/nettruyen_service.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> chapters;
  final int initialIndex;
  final Function(int) saveLastRead;

  ReaderScreen({
    required this.chapters,
    this.initialIndex = 0,
    required this.saveLastRead,
  });

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int chapIndex;
  late Future<List<String>> _pagesFuture;
  PageController _pageController = PageController();
  List<String> _pages = [];

  @override
  void initState() {
    super.initState();
    chapIndex = widget.initialIndex;
    _loadChapter();
  }

  void _loadChapter() {
    _pagesFuture = NetTruyenService().fetchChapterPages(widget.chapters[chapIndex]);
    _pagesFuture.then((pages) {
      setState(() {
        _pages = pages;
      });
      widget.saveLastRead(chapIndex);
    });
  }

  void _goChapter(int offset) {
    final newIndex = (chapIndex + offset).clamp(0, widget.chapters.length - 1);
    if (newIndex != chapIndex) {
      setState(() {
        chapIndex = newIndex;
        _pages = [];
      });
      _loadChapter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${chapIndex + 1}'),
        leading: IconButton(icon: Icon(Icons.chevron_left), onPressed: () => _goChapter(-1)),
        actions: [IconButton(icon: Icon(Icons.chevron_right), onPressed: () => _goChapter(1))],
      ),
      body: FutureBuilder<List<String>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return Stack(
            children: [
              ListView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                itemBuilder: (context, idx) {
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: PhotoView.customChild(
                      child: CachedNetworkImage(
                        imageUrl: _pages[idx],
                        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => Icon(Icons.broken_image),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () async {
                    final page = await showModalBottomSheet<int>(
                      context: context,
                      builder: (_) {
                        return ListView.builder(
                          itemCount: _pages.length,
                          itemBuilder: (context, i) {
                            return ListTile(
                              title: Text('Page ${i + 1}'),
                              onTap: () => Navigator.pop(context, i),
                            );
                          },
                        );
                      },
                    );
                    if (page != null) _pageController.jumpToPage(page);
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.black45,
                    child: Text(
                      '\${_pageController.hasClients ? _pageController.page?.round() ?? 1 : 1} / \${_pages.length}',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }



}
