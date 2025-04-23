import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import 'reader_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailScreen extends StatefulWidget {
  final Comic comic;
  DetailScreen({required this.comic});

  @override
  _DetailScreenState createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<List<String>> _chaptersFuture;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = NetTruyenService().fetchChapters(widget.comic.detailUrl);
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastIndex = prefs.getInt(widget.comic.detailUrl) ?? 0;
    });
  }

  Future<void> _saveLastRead(int idx) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt(widget.comic.detailUrl, idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.comic.title)),
      body: FutureBuilder<List<String>>(
        future: _chaptersFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final chapters = snapshot.data!;
          return ListView.builder(
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('Chapter ${index + 1}'),
                trailing: index == _lastIndex ? Icon(Icons.bookmark) : null,
                onTap: () {
                  _saveLastRead(index);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      chapters: chapters,
                      initialIndex: index,
                      saveLastRead: _saveLastRead,
                    ),
                  ));
                },
              );
            },
          );
        },
      ),
    );
  }
}
