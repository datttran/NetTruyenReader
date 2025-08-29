# Home Page Quick Reference

## 🚀 Essential Functions (Must-Know)

### **Data Loading**
- `_loadComics()` → Loads main comic grid
- `_loadTopComics()` → Loads featured comics
- `_refreshData()` → Refreshes all data

### **Navigation**
- `_navigateToDetail(Comic)` → Goes to DetailScreen
- `_navigateToGenre(String)` → Goes to GenreComicsScreen
- `_navigateToSearch()` → Opens ComicSearchDelegate

### **UI Building**
- `_buildTopComicsSection()` → Featured comics horizontal scroll
- `_buildComicsGrid()` → Main comics grid
- `_buildGenreChips()` → Genre selection chips
- `_buildRefreshButton()` → Floating refresh button

## 🔄 Data Flow Quick View

```
LoadingScreen → HomeScreen → Other Screens
     ↓            ↓            ↓
  Preload    Display &     Navigation
   Data      Handle        & Actions
```

## 📱 Screen Interactions

| Function | Goes To | Passes Data | Returns To |
|----------|---------|-------------|------------|
| `_navigateToDetail` | DetailScreen | Comic object | HomeScreen |
| `_navigateToGenre` | GenreComicsScreen | Genre string | HomeScreen |
| `_navigateToSearch` | ComicSearchDelegate | None | HomeScreen |

## 🎯 Key State Variables

- `_comics` → Main comic list
- `_topComics` → Featured comics
- `_isLoading` → Loading state
- `_lastUsedDomain` → Domain tracking
- `_thumbCache` → Thumbnail cache manager

## ⚡ Performance Tips

1. **Always use** `CustomComicCard` for consistency
2. **Filter thumbnails** before displaying
3. **Cache domains** to avoid unnecessary reloads
4. **Use shimmer** during loading states

## 🐛 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Thumbnails not loading | Domain mismatch | Check `_getCurrentDomainForHeaders()` |
| Comics not showing | Filter too strict | Review `_filterComicsWithThumbnails()` |
| Refresh not working | State not updated | Ensure `setState()` is called |

## 🔧 Quick Function Templates

### **Add New UI Section**
```dart
Widget _buildNewSection() {
  return Container(
    child: // Your UI here
  );
}
```

### **Add New Navigation**
```dart
void _navigateToNewScreen() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => NewScreen(),
    ),
  );
}
```

### **Add New State Variable**
```dart
// At top of class
bool _newState = false;

// In setState
setState(() {
  _newState = true;
});
```

## 📚 Related Files

- **Home Screen**: `lib/screens/home_screen.dart`
- **Custom Comic Card**: `lib/widgets/custom_comic_card.dart`
- **NetTruyen Service**: `lib/services/nettruyen_service.dart`
- **App Constants**: `lib/constants/app_constants.dart`

## 🎨 UI Components

- **Cards**: Use `CustomComicCard` for consistency
- **Loading**: Use `CardLoading` with shimmer
- **Animations**: Use `reload.json`, `tap.json`
- **Colors**: Use `ThemeConstants` for consistency

---

*Use this quick reference during development for fast access to common patterns and solutions.*
