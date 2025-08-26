// lib/screens/genre_comics_screen.dart

import 'package:flutter/material.dart';
import '../models/comic.dart';
import '../services/nettruyen_service.dart';
import 'detail_screen.dart';
import '../widgets/custom_comic_card.dart';
import '../utils/domain_helper.dart';
import '../constants/theme_constants.dart';

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
  String _selectedSort = 'Số chapter'; // Default sort option

  @override
  void initState() {
    super.initState();
    _comicsFuture = NetTruyenService().fetchComicsByGenre(widget.genreUrl);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: CustomScrollView(
              slivers: [
                // Custom header section
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        Text(
                          '${widget.genreName} Comics',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${comics.length} comics found',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sorting options
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sắp xếp theo:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[300]
                                    : Colors.grey[700],
                              ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSortChip('Ngày cập nhật', Icons.update),
                            _buildSortChip('Truyện mới', Icons.new_releases),
                            _buildSortChip('Top all', Icons.visibility),
                            _buildSortChip('Top tháng', Icons.visibility),
                            _buildSortChip('Top tuần', Icons.visibility),
                            _buildSortChip('Top ngày', Icons.visibility),
                            _buildSortChip('Theo dõi', Icons.favorite_border),
                            _buildSortChip('Bình luận', Icons.chat_bubble_outline),
                            _buildSortChip('Số chapter', Icons.format_list_numbered),
                            _buildSortChip('Top Follow', Icons.format_list_numbered),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                                // Comics grid using SliverGrid for better performance
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                      childCount: comics.length,
                    ),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: _calculateOptimalCardWidth(),
                      childAspectRatio: _calculateOptimalAspectRatio(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  ),
                ),
              ],
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

    // Calculate aspect ratio based on screen proportions
    final widthRatio = screenWidth / MediaQuery.of(context).size.height;

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

  /// Build a sort chip with proper styling and selection state
  Widget _buildSortChip(String label, IconData icon) {
    final isSelected = _selectedSort == label;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSort = label;
        });
        // TODO: Implement actual sorting logic based on selection
        print('Selected sort: $label');
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black,      // shadow color
              offset: const Offset(4, 4),     // shadow position
              blurRadius: 0,            // no blur → hard edge
              spreadRadius: 0,          // no extra spread
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? ThemeConstants.netflixRed
                  : ThemeConstants.netflixWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.black,
                width: 2.0,
              ),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : ThemeConstants.netflixRed,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : ThemeConstants.netflixRed,
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
