# Responsive Grid Implementation

## Overview

The NetTruyen Reader app now uses a responsive grid system that automatically adjusts the number of columns based on screen size while maintaining reasonable comic card dimensions for optimal reading experience.

## Key Features

### 1. Percentage-Based Sizing
- **Mobile (≤600px)**: Cards use 42% of screen width (2 columns)
- **Tablet (601-900px)**: Cards use 28% of screen width (3-4 columns)  
- **Desktop (>900px)**: Cards use 22% of screen width (4-5 columns)

### 2. Adaptive Aspect Ratios
- **Portrait**: 0.6 aspect ratio for taller cards
- **Landscape**: 0.7 aspect ratio for wider cards
- **Standard**: 0.65 aspect ratio for balanced proportions

### 3. Size Constraints
- **Minimum width**: 120px (ensures readability)
- **Maximum width**: 200px (prevents oversized cards)

## Implementation Details

### Grid Delegate
```dart
gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: _calculateOptimalCardWidth(),
  childAspectRatio: _calculateOptimalAspectRatio(),
  crossAxisSpacing: AppConstants.GRID_SPACING,
  mainAxisSpacing: AppConstants.GRID_SPACING,
),
```

### Card Width Calculation
```dart
double _calculateOptimalCardWidth() {
  final screenWidth = MediaQuery.of(context).size.width;
  
  // Use different percentages based on screen size breakpoints
  double cardWidthPercent;
  if (screenWidth < AppConstants.MOBILE_BREAKPOINT) {
    cardWidthPercent = AppConstants.MOBILE_CARD_WIDTH_PERCENT; // Mobile: 2 columns
  } else if (screenWidth < AppConstants.TABLET_BREAKPOINT) {
    cardWidthPercent = AppConstants.TABLET_CARD_WIDTH_PERCENT; // Tablet: 3-4 columns
  } else {
    cardWidthPercent = AppConstants.DESKTOP_CARD_WIDTH_PERCENT; // Desktop: 4-5 columns
  }
  
  final calculatedWidth = screenWidth * cardWidthPercent;
  
  // Apply min/max constraints
  return calculatedWidth.clamp(
    AppConstants.MIN_CARD_WIDTH,
    AppConstants.MAX_CARD_WIDTH,
  );
}
```

## Benefits

### 1. Cross-Platform Consistency
- Cards maintain readable size across all devices
- Automatic column adjustment based on available space
- Consistent user experience regardless of screen size

### 2. Optimal Reading Experience
- Cards are never too small to read comfortably
- Cards are never too large to fit properly
- Text remains legible at all sizes

### 3. Responsive Design
- Automatically adapts to different screen orientations
- Works seamlessly on mobile, tablet, and desktop
- No manual configuration required

## Screen Size Examples

| Screen Width | Card Width | Columns | Device Type |
|--------------|------------|---------|-------------|
| 360px        | 151px      | 2       | Mobile      |
| 600px        | 168px      | 3       | Mobile      |
| 900px        | 198px      | 4       | Tablet      |
| 1200px       | 198px      | 5       | Desktop     |
| 1920px       | 198px      | 8+      | Desktop     |

## Files Modified

1. **lib/constants/app_constants.dart** - Added responsive constants
2. **lib/screens/home_screen.dart** - Updated grid implementation
3. **lib/screens/genre_comics_screen.dart** - Updated grid implementation

## Testing

To test the responsive behavior:

1. **Mobile**: Use device emulator or resize browser to ≤600px width
2. **Tablet**: Resize browser to 601-900px width  
3. **Desktop**: Resize browser to >900px width

The grid will automatically adjust the number of columns while maintaining optimal card dimensions for reading. 