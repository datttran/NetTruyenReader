# Home Screen Documentation

## Overview
The home screen is the main entry point of the NetTruyen Reader app, displaying popular genres and a grid of comics. It features a modern hiding app bar that provides an immersive reading experience.

## Key Features

### 1. Hiding App Bar
- **Implementation**: Uses `SliverAppBar` within `CustomScrollView`
- **Behavior**: 
  - Hides completely when scrolling down
  - Reappears when scrolling up
  - Snaps into view for better UX
- **Properties**:
  ```dart
  SliverAppBar(
    title: Text(AppConstants.APP_NAME),
    floating: true,    // Appears when scrolling up
    pinned: false,     // Completely hides when scrolling down
    snap: true,        // Snaps into view
    actions: [search, settings],
  )
  ```

### 2. Layout Structure
- **Main Container**: `CustomScrollView` with `slivers` list
- **Content Organization**:
  1. `SliverAppBar` - Hiding app bar with actions
  2. `SliverToBoxAdapter` - Popular genres section
  3. `SliverGrid` - Comics grid (or shimmer loading)

### 3. Popular Genres Section
- **Horizontal scrolling** genre chips
- **Hardcoded paths** for consistent navigation
- **Navigation**: Routes to `GenreComicsScreen`
- **Genres**: Action, Comedy, Drama, Romance, Fantasy, Adventure, Slice of Life, Psychological

### 4. Comics Grid
- **Grid Layout**: 3 columns with 0.65 aspect ratio
- **Loading States**: 
  - Shimmer effect when empty
  - Pagination support with load more
- **Navigation**: Taps navigate to `DetailScreen`
- **Hero Animation**: Smooth transitions with `Hero` widget

## Technical Implementation

### Widget Tree Structure
```
Scaffold
└── RefreshIndicator
    └── CustomScrollView
        └── slivers: [
            SliverAppBar,           // Hiding app bar
            SliverToBoxAdapter,      // Genres section
            SliverGrid,             // Comics grid
        ]
```

### Key Widgets Used
- **`CustomScrollView`**: Main scrollable container
- **`SliverAppBar`**: Hiding app bar
- **`SliverToBoxAdapter`**: Wraps regular widgets for sliver compatibility
- **`SliverGrid`**: Grid layout for comics
- **`SliverChildBuilderDelegate`**: Efficient item building

### State Management
- **`_allComics`**: Complete list of comics
- **`_displayComics`**: Currently displayed comics (paginated)
- **`_pageSize`**: Number of comics per page
- **`_hasMore`**: Boolean for pagination

## Important Lessons Learned

### 1. Avoiding Nested Scrollable Widgets
**Problem**: 
- Wrapping `GridView.builder` in `SliverToBoxAdapter` inside `CustomScrollView`
- This caused frame timing errors: `'debugFrameWasSentToEngine': is not true`

**Solution**: 
- Convert all content to proper sliver widgets
- Use `SliverGrid` instead of `GridView.builder`
- Ensure no nested scrollable widgets

### 2. Proper Sliver Structure
**Before (Problematic)**:
```dart
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: _buildShimmerGrid()), // ❌ Returns GridView.builder
  ],
)
```

**After (Fixed)**:
```dart
CustomScrollView(
  slivers: [
    SliverGrid( // ✅ Proper sliver widget
      delegate: SliverChildBuilderDelegate(...),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(...),
    ),
  ],
)
```

### 3. App Bar Hiding Behavior
**Key Properties**:
- `floating: true` - Appears when scrolling up
- `pinned: false` - Completely hides when scrolling down  
- `snap: true` - Snaps into view for better UX

## Performance Considerations

### 1. Efficient Item Building
- **`SliverChildBuilderDelegate`**: Only builds visible items
- **`cacheExtent`**: Caches items slightly beyond viewport
- **Hero animations**: Smooth transitions without performance impact

### 2. Memory Management
- **Pagination**: Loads comics in chunks
- **Image caching**: Uses `CachedNetworkImage` for thumbnails
- **State cleanup**: Proper disposal of controllers and listeners

## Error Handling

### 1. Network Failures
- **Graceful degradation**: Shows error states
- **Retry mechanism**: Pull-to-refresh functionality
- **User feedback**: Clear error messages

### 2. Image Loading
- **Fallback images**: Shows broken image icon on failure
- **Loading states**: Shimmer effects during loading
- **Error logging**: Debug information for troubleshooting

## Future Enhancements

### 1. Search Integration
- **Global search**: Quick access from app bar
- **Search history**: Remember recent searches
- **Voice search**: Accessibility improvement

### 2. Personalization
- **Favorite genres**: User preference storage
- **Reading history**: Track viewed comics
- **Custom themes**: Dark/light mode support

### 3. Performance
- **Lazy loading**: Load images on demand
- **Virtual scrolling**: Handle large comic lists
- **Background prefetching**: Preload next page

## Code Examples

### Basic SliverAppBar Setup
```dart
SliverAppBar(
  title: Text(AppConstants.APP_NAME),
  floating: true,
  pinned: false,
  snap: true,
  actions: [
    IconButton(icon: Icon(Icons.search), onPressed: _onSearch),
    IconButton(icon: Icon(Icons.settings), onPressed: _onSettings),
  ],
)
```

### SliverGrid Implementation
```dart
SliverGrid(
  delegate: SliverChildBuilderDelegate(
    (context, index) => _buildComicCard(index),
    childCount: _displayComics.length + (_hasMore ? 1 : 0),
  ),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    childAspectRatio: 0.65,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
)
```

## Dependencies
- **`flutter/material.dart`**: Core Flutter widgets
- **`cached_network_image`**: Image caching and loading
- **`shimmer`**: Loading state effects
- **Custom services**: `NetTruyenService`, `DatabaseHelper`

## Testing
- **Unit tests**: Widget behavior and state management
- **Integration tests**: Navigation and user flows
- **Performance tests**: Scroll performance and memory usage
- **Accessibility tests**: Screen reader compatibility

---

*Last updated: [Current Date]*
*Version: 1.0* 