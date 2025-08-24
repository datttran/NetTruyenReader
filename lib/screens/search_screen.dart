import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comic.dart';
import '../providers/font_provider.dart';

/// A placeholder screen for searching comics.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
    await Future.delayed(const Duration(seconds: 1));

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
        title: Consumer<FontProvider>(
          builder: (context, fontProvider, child) {
            return TextField(
              controller: _searchController,
              style: fontProvider.getScaledTextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search comics...',
                hintStyle: fontProvider.getScaledTextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                  final comic = _searchResults[index];
                  return Consumer<FontProvider>(
                    builder: (context, fontProvider, child) {
                      return ListTile(
                        leading: Image.network(comic.imageUrl,
                            width: 40, height: 60, fit: BoxFit.cover),
                        title: Text(
                          comic.title,
                          style: fontProvider.getScaledTextStyle(fontSize: 16),
                        ),
                        onTap: () {
                          // TODO: Navigate to detail page
                        },
                      );
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
