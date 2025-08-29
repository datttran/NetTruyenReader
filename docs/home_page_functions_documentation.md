# Home Page Functions Documentation

## Overview
The Home Page (`lib/screens/home_screen.dart`) serves as the central hub of the NetTruyenReader app, displaying comics, handling user interactions, and coordinating with other screens. This document outlines all functions, their responsibilities, and interactions.

## Core Functions

### 1. **State Management Functions**

#### `initState()`
- **Role**: Initialize the screen state and load initial data
- **Responsibilities**:
  - Set up thumbnail cache manager
  - Initialize domain tracking
  - Load comics from loading screen data
  - Set up refresh controller
- **Interactions**:
  - Calls `LoadingScreen` data via `NetTruyenService`
  - Initializes `CacheManager` for thumbnails
  - Sets up `RefreshIndicator` controller

#### `dispose()`
- **Role**: Clean up resources when screen is destroyed
- **Responsibilities**:
  - Dispose refresh controller
  - Clear any active timers or animations
- **Interactions**: None (cleanup only)

#### `didChangeDependencies()`
- **Role**: Handle dependency changes (e.g., theme changes)
- **Responsibilities**:
  - Update font provider references
  - Handle theme changes
- **Interactions**: 
  - `FontProvider` for dynamic font changes
  - Theme system for dark/light mode

### 2. **Data Loading Functions**

#### `_loadComics()`
- **Role**: Load comics from the service
- **Responsibilities**:
  - Fetch comics from `NetTruyenService`
  - Apply thumbnail filtering
  - Update state with loaded comics
- **Interactions**:
  - `NetTruyenService.fetchComics()`
  - `_filterComicsWithThumbnails()`
  - Sets `_comics` state

#### `_loadTopComics()`
- **Role**: Load featured/top comics
- **Responsibilities**:
  - Fetch top comics from service
  - Apply thumbnail filtering
  - Update top comics state
- **Interactions**:
  - `NetTruyenService.fetchTopComics()`
  - `_filterComicsWithThumbnails()`
  - Sets `_topComics` state

#### `_refreshData()`
- **Role**: Refresh all comic data
- **Responsibilities**:
  - Clear existing data
  - Reload comics and top comics
  - Show refresh animation
- **Interactions**:
  - Calls `_loadComics()` and `_loadTopComics()`
  - Triggers `reload.json` animation
  - Updates loading states

### 3. **Domain Management Functions**

#### `_getCurrentDomainForHeaders()`
- **Role**: Get current domain for HTTP headers
- **Responsibilities**:
  - Return cached domain if available
  - Fallback to primary domain constant
  - Update last used domain
- **Interactions**:
  - `AppConstants.PRIMARY_DOMAIN`
  - `NetTruyenService.getCurrentDomain()`
  - Used by `CachedNetworkImage` for referer headers

#### `_checkAndUpdateDomain()`
- **Role**: Check if domain has changed and update if needed
- **Responsibilities**:
  - Compare current domain with last used
  - Trigger reload if domain changed
  - Update domain tracking
- **Interactions**:
  - `NetTruyenService.getCurrentDomain()`
  - Calls `_refreshData()` if domain changes

### 4. **Thumbnail Filtering Functions**

#### `_filterComicsWithThumbnails(List<Comic> comics)`
- **Role**: Filter out comics with broken or invalid thumbnails
- **Responsibilities**:
  - Check for empty/null URLs
  - Validate URL patterns
  - Filter out broken image patterns
  - Ensure proper image extensions
- **Interactions**:
  - Called by `_loadComics()` and `_loadTopComics()`
  - Returns filtered list for display
  - Logs filtering decisions for debugging

### 5. **UI Building Functions**

#### `_buildTopComicsSection()`
- **Role**: Build the featured comics section
- **Responsibilities**:
  - Display top comics in horizontal scroll
  - Handle loading states
  - Apply shimmer effects
  - Use `CustomComicCard` for consistency
- **Interactions**:
  - `CustomComicCard` widget
  - `CardLoading` for shimmer effects
  - `_topComics` state data

#### `_buildComicsGrid()`
- **Role**: Build the main comics grid
- **Responsibilities**:
  - Display filtered comics in responsive grid
  - Handle different screen sizes
  - Apply loading states and shimmer
  - Use `CustomComicCard` for consistency
- **Interactions**:
  - `CustomComicCard` widget
  - `CardLoading` for shimmer effects
  - `_comics` state data
  - Responsive grid calculations

#### `_buildGenreChips()`
- **Role**: Build genre selection chips
- **Responsibilities**:
  - Display available genres
  - Handle chip selection
  - Apply animations and styling
  - Navigate to genre comics screen
- **Interactions**:
  - `GenreComicsScreen` navigation
  - Genre data from service
  - `tap.json` animation on selection

#### `_buildRefreshButton()`
- **Role**: Build the floating refresh button
- **Responsibilities**:
  - Display refresh button with animation
  - Handle refresh actions
  - Show completion animation
  - Auto-hide after completion
- **Interactions**:
  - `reload.json` animation
  - Calls `_refreshData()`
  - Auto-hide timer

### 6. **Navigation Functions**

#### `_navigateToDetail(Comic comic)`
- **Role**: Navigate to comic detail screen
- **Responsibilities**:
  - Pass comic data to detail screen
  - Handle navigation transition
- **Interactions**:
  - `DetailScreen` with comic data
  - Navigation system

#### `_navigateToGenre(String genre)`
- **Role**: Navigate to genre comics screen
- **Responsibilities**:
  - Pass genre data
  - Handle navigation transition
- **Interactions**:
  - `GenreComicsScreen` with genre parameter
  - Navigation system

#### `_navigateToSearch()`
- **Role**: Open search functionality
- **Responsibilities**:
  - Show search delegate
  - Handle search queries
- **Interactions**:
  - `ComicSearchDelegate`
  - Search functionality

### 7. **Animation Functions**

#### `_showRefreshAnimation()`
- **Role**: Display refresh completion animation
- **Responsibilities**:
  - Show completion indicator
  - Auto-hide after delay
  - Update animation state
- **Interactions**:
  - Animation state management
  - Timer for auto-hide

## Data Flow Architecture

### 1. **Initial Load Flow**
```
LoadingScreen → NetTruyenService → HomeScreen
     ↓              ↓              ↓
  Preload Data → Cache Data → Display UI
```

### 2. **Refresh Flow**
```
User Pull → _refreshData() → Clear Data → Reload → Update UI
   ↓           ↓              ↓         ↓        ↓
Refresh    Clear State    Load New   Filter   Rebuild
Animation   Variables     Data      Thumbs    Widgets
```

### 3. **Domain Change Flow**
```
Domain Check → Compare → If Changed → Refresh Data
     ↓           ↓           ↓           ↓
Service Call  Last Used   Different   Reload All
              Domain      Domain      Comics
```

## Interaction Patterns

### 1. **With LoadingScreen**
- **Data Transfer**: Receives preloaded comics and top comics
- **State Synchronization**: Maintains loading states
- **Cache Sharing**: Uses same thumbnail cache manager

### 2. **With DetailScreen**
- **Data Passing**: Sends comic object with all details
- **Navigation**: Pushes detail screen onto stack
- **Return Handling**: Returns to home screen

### 3. **With GenreComicsScreen**
- **Parameter Passing**: Sends genre string
- **Navigation**: Pushes genre screen onto stack
- **Return Handling**: Returns to home screen

### 4. **With ComicSearchDelegate**
- **Search Integration**: Shows search overlay
- **Query Handling**: Processes search results
- **Navigation**: Returns to home after search

### 5. **With NetTruyenService**
- **Data Fetching**: Calls service methods for comics
- **Domain Management**: Gets current domain for headers
- **Error Handling**: Manages service errors gracefully

## Best Practices

### 1. **State Management**
- Always use `setState()` for UI updates
- Maintain consistent loading states
- Handle errors gracefully with user feedback

### 2. **Performance**
- Use `CustomComicCard` for consistent rendering
- Implement proper caching strategies
- Minimize unnecessary rebuilds

### 3. **User Experience**
- Show loading indicators during data fetch
- Provide smooth animations for interactions
- Handle edge cases (no data, errors, etc.)

### 4. **Code Organization**
- Keep functions focused and single-purpose
- Use descriptive function names
- Maintain consistent error handling patterns

## Future Enhancements

### 1. **Caching Improvements**
- Implement more sophisticated cache invalidation
- Add offline support for cached comics
- Optimize thumbnail loading strategies

### 2. **Performance Optimizations**
- Implement lazy loading for large comic lists
- Add pagination for better memory management
- Optimize image loading and caching

### 3. **User Experience**
- Add pull-to-refresh animations
- Implement smooth scrolling optimizations
- Add haptic feedback for interactions

## Testing Considerations

### 1. **Unit Tests**
- Test individual functions in isolation
- Mock external dependencies
- Verify state management logic

### 2. **Integration Tests**
- Test interactions between functions
- Verify data flow patterns
- Test error handling scenarios

### 3. **UI Tests**
- Test user interactions
- Verify animation behaviors
- Test responsive design behavior

---

*This documentation should be updated whenever new functions are added or existing functions are modified to maintain accuracy and consistency across the development team.*
