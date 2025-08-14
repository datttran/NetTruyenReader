# NetTruyen Reader - Documentation Index

## Overview
This folder contains comprehensive documentation for the NetTruyen Reader Flutter application. Each major component has its own documentation file for easy navigation and maintenance.

## Documentation Structure

### 📱 Screen Documentation
- **[home_screen.md](home_screen.md)** - Main home screen with hiding app bar
- **[detail_screen.md](detail_screen.md)** - Comic detail view and chapter navigation
- **[genre_comics_screen.md](genre_comics_screen.md)** - Genre-specific comic listings
- **[reader_screen.md](reader_screen.md)** - Chapter reading interface
- **[settings_screen.md](settings_screen.md)** - App configuration and domain management
- **[search_screen.md](search_screen.md)** - Comic search functionality

### 🔧 Service Documentation
- **[nettruyen_service.md](nettruyen_service.md)** - Core API service and data fetching ✅
- **[database_helper.md](database_helper.md)** - Local database operations and caching ✅
- **[comic_search_delegate.md](comic_search_delegate.md)** - Search implementation

### 🏗️ Architecture Documentation
- **[app_architecture.md](app_architecture.md)** - Overall app structure and design patterns
- **[state_management.md](state_management.md)** - State management strategies
- **[navigation_patterns.md](navigation_patterns.md)** - Navigation and routing

### 📚 Model Documentation
- **[comic_model.md](comic_model.md)** - Comic data structure and relationships
- **[genre_model.md](genre_model.md)** - Genre classification system

### 🚀 Development Documentation
- **[setup_guide.md](setup_guide.md)** - Development environment setup
- **[troubleshooting.md](troubleshooting.md)** - Common issues and solutions
- **[performance_optimization.md](performance_optimization.md)** - Performance best practices

## Quick Start

### For Developers
1. Start with [setup_guide.md](setup_guide.md) for environment setup
2. Review [app_architecture.md](app_architecture.md) for overall structure
3. Check specific screen documentation as needed

### For Contributors
1. Read [home_screen.md](home_screen.md) to understand the main implementation
2. Review [troubleshooting.md](troubleshooting.md) for common issues
3. Check [performance_optimization.md](performance_optimization.md) for best practices

## Key Features Documented

### ✅ Completed Features
- **Hiding App Bar** - Modern scroll-based app bar behavior
- **Genre Navigation** - Clickable genre tags with dedicated screens
- **Comic Grid** - Efficient pagination and loading
- **Search Functionality** - Working search with proper deduplication
- **Image Caching** - Optimized thumbnail loading
- **Domain Management** - User-customizable domains with auto-save

### 🚧 In Progress
- **Performance Optimization** - Ongoing improvements
- **Error Handling** - Enhanced user experience

### 📋 Planned Features
- **Offline Reading** - Download chapters for offline access
- **Reading Progress** - Track reading history
- **Personalization** - User preferences and themes

## Technical Stack

### Frontend
- **Flutter** - Cross-platform UI framework
- **Dart** - Programming language
- **Material Design** - UI component library

### Backend Services
- **HTTP Requests** - Network communication
- **HTML Parsing** - Data extraction from web pages
- **Local Database** - SQLite for caching

### Key Packages
- **`cached_network_image`** - Image caching and loading
- **`sqflite`** - Local database operations
- **`shared_preferences`** - User preferences storage
- **`shimmer`** - Loading state effects

## Best Practices

### Code Organization
- **Screen-based structure** - Each screen in its own file
- **Service separation** - Business logic separated from UI
- **Model-driven design** - Clear data structures

### Performance
- **Lazy loading** - Load content on demand
- **Efficient scrolling** - Use sliver widgets for large lists
- **Image optimization** - Proper caching and loading states

### User Experience
- **Smooth animations** - Hero transitions and loading states
- **Responsive design** - Adapt to different screen sizes
- **Accessibility** - Screen reader support and navigation

## Contributing

### Documentation Standards
- **Clear structure** - Use consistent headings and formatting
- **Code examples** - Include practical code snippets
- **Screenshots** - Visual aids when helpful
- **Version tracking** - Update dates and versions

### Adding New Documentation
1. Create a new `.md` file in the appropriate category
2. Follow the existing format and structure
3. Update this index file
4. Include practical examples and code snippets

## Maintenance

### Regular Updates
- **Feature updates** - Document new functionality
- **Bug fixes** - Update troubleshooting guides
- **Performance improvements** - Document optimizations
- **User feedback** - Incorporate user experience insights

### Version Control
- **Git integration** - Track documentation changes
- **Branch strategy** - Feature-based documentation updates
- **Review process** - Ensure accuracy and completeness

---

*Last updated: [Current Date]*
*Documentation Version: 1.0*
*App Version: [Current App Version]* 