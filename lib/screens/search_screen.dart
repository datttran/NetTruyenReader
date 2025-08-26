import 'package:flutter/material.dart';
import '../services/comic_search_delegate.dart';
import '../models/comic.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ComicSearchDelegate _searchDelegate = ComicSearchDelegate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _SearchDelegateWrapper(
        searchDelegate: _searchDelegate,
        onComicSelected: (comic) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScreen(comic: comic),
            ),
          );
        },
      ),
    );
  }
}

class _SearchDelegateWrapper extends StatefulWidget {
  final ComicSearchDelegate searchDelegate;
  final Function(Comic) onComicSelected;

  const _SearchDelegateWrapper({
    required this.searchDelegate,
    required this.onComicSelected,
  });

  @override
  State<_SearchDelegateWrapper> createState() => _SearchDelegateWrapperState();
}

class _SearchDelegateWrapperState extends State<_SearchDelegateWrapper> {
  String _query = '';
  bool _showResults = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input field
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm truyện...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _showResults = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
                          onChanged: (value) {
                setState(() {
                  _query = value;
                  _showResults = value.trim().isNotEmpty;
                });
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  setState(() {
                    _query = value;
                    _showResults = true;
                  });
                }
              },
            ),
          ),
        ),
        // Search content
        Expanded(
          child: _showResults
              ? widget.searchDelegate.buildSearchResults(context, customQuery: _query)
              : widget.searchDelegate.buildSuggestionsContent(context),
        ),
      ],
    );
  }
}
