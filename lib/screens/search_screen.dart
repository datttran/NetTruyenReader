import 'package:flutter/material.dart';
import '../models/comic.dart';

/// A placeholder screen for searching comics.
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Comic> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _searchResults.clear();
    });

    // TODO: Integrate real search service here
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      // Populate with dummy data for now
      _searchResults = []; // Replace with actual results
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search comics...',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final comic = _searchResults[index];
          return ListTile(
            leading: Image.network(comic.imageUrl, width: 40, height: 60, fit: BoxFit.cover),
            title: Text(comic.title),
            onTap: () {
              // TODO: Navigate to detail page
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
