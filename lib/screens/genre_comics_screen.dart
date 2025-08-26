// lib/screens/genre_comics_screen.dart

import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import 'detail_screen.dart';
import '../widgets/custom_comic_card.dart';
import '../utils/domain_helper.dart';

class GenreComicsScreen extends StatefulWidget {
  final String genreName;
  final String genreUrl;

  const GenreComicsScreen({
    Key? key,
    required this.genreName,
    required this.genreUrl,
  }) : super(key: key);

  @override
  _GenreComicsScreenState createState() => _GenreComicsScreenState();
}

class _GenreComicsScreenState extends State<GenreComicsScreen> {
  late Future<List<Comic>> _comicsFuture;

  @override
  void initState() {
    super.initState();
    _comicsFuture = NetTruyenService().fetchComicsByGenre(widget.genreUrl);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.genreName} Comics'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Comic>>(
        future: _comicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading ${widget.genreName} comics',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _comicsFuture = NetTruyenService()
                            .fetchComicsByGenre(widget.genreUrl);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final comics = snapshot.data ?? [];
          if (comics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.genreName} comics found',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different genre or check back later',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _comicsFuture =
                    NetTruyenService().fetchComicsByGenre(widget.genreUrl);
              });
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: _calculateOptimalCardWidth(),
                childAspectRatio: _calculateOptimalAspectRatio(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: comics.length,
              itemBuilder: (context, index) {
                final comic = comics[index];
                final columnCount = _calculateColumnCount();
                return FutureBuilder<String>(
                  future: DomainHelper.getCurrentDomain(),
                  builder: (context, domainSnapshot) {
                    if (!domainSnapshot.hasData) {
                      return CustomComicCard(
                        comic: comic,
                        columnCount: columnCount,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(comic: comic),
                          ),
                        ),
                      );
                    }
                    
                    return CustomComicCard(
                      comic: comic,
                      domain: domainSnapshot.data!,
                      columnCount: columnCount,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScreen(comic: comic),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Calculate optimal card width based on screen size and constraints
  double _calculateOptimalCardWidth() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Use different percentages based on screen size breakpoints
    double cardWidthPercent;
    if (screenWidth < 600.0) {
      cardWidthPercent = 0.42; // Mobile: 2 columns
    } else if (screenWidth < 900.0) {
      cardWidthPercent = 0.28; // Tablet: 3-4 columns
    } else {
      cardWidthPercent = 0.22; // Desktop: 4-5 columns
    }

    final calculatedWidth = screenWidth * cardWidthPercent;

    // Apply min/max constraints
    return calculatedWidth.clamp(120.0, 200.0);
  }

  /// Calculate optimal aspect ratio based on screen dimensions
  double _calculateOptimalAspectRatio() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate aspect ratio based on screen proportions
    final widthRatio = screenWidth / screenHeight;

    // Adjust aspect ratio based on screen orientation and size
    if (widthRatio > 1.0) {
      // Landscape or wide screen - use wider cards
      return 0.7;
    } else if (widthRatio < 0.6) {
      // Very narrow screen (mobile portrait) - use taller cards
      return 0.6;
    } else {
      // Standard mobile portrait - use balanced aspect ratio
      return 0.65;
    }
  }

  /// Calculate the number of columns based on screen size
  int _calculateColumnCount() {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth < 600.0) {
      return 2; // Mobile: 2 columns
    } else if (screenWidth < 900.0) {
      return 3; // Tablet: 3-4 columns
    } else {
      return 4; // Desktop: 4-5 columns
    }
  }
}
