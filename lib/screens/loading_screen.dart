import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/nettruyen_service.dart';
import '../models/comic.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late AnimationController _thunderLottieController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _thunderAnimation;
  
  List<Comic> _comics = [];
  List<Comic> _topComics = [];
  String? _currentDomain; // Store the domain for navigation
  
  // Thunder Lottie animation controller for playing 2 times
  int _thunderPlayCount = 0;
  final int _maxThunderPlays = 1; // Play exactly 1 time

  @override
  void initState() {
    super.initState();
    
    // Initialize main animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Initialize zoom controller for smooth zoom in/out effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),  // Smooth, gentle zoom
      vsync: this,
    );
    
    // Initialize thunder animation controller
    _thunderLottieController = AnimationController(vsync: this);
    _thunderLottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _thunderPlayCount++;
        if (_thunderPlayCount < _maxThunderPlays) {
          _thunderLottieController.forward(from: 0.0); // Restart the animation
        } else {
          // Animation has played the desired number of times
          print('✅ Thunder animation completed after $_maxThunderPlays plays');
        }
      }
    });
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,  // Start from invisible
      end: 1.0,   // Scale to full size
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,  // Start invisible
      end: 1.0,   // Fade to visible
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,  // Subtle zoom up to 108%
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,  // Smooth for zoom in/out
    ));
    
    // Thunder animation that fades in after logo finishes
    _thunderAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.83, 1.0, curve: Curves.easeInOut), // 1000-1300ms timing
    ));
    
    // Start main animation
    _animationController.forward();
    
    // Start continuous zoom in/out animation
    _pulseController.repeat(reverse: true);
    
    // Load comics in background while showing animation
    _loadComicsInBackground();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _thunderLottieController.dispose();
    super.dispose();
  }

  Future<void> _loadComicsInBackground() async {
    try {
      print('🔄 LoadingScreen: Starting to load comics and top comics in background...');
      final netTruyenService = NetTruyenService();
      
      // Load both main comics and top comics in parallel
      // First get the current domain to ensure consistency
      _currentDomain = await netTruyenService.getCurrentDomain();
      print('🌐 LoadingScreen: Using domain: $_currentDomain');
      final comics = await netTruyenService.fetchComics();
      final topComics = await netTruyenService.fetchComicsFromUrl('$_currentDomain/tim-truyen?status=&sort=10');
      
      print('✅ LoadingScreen: Successfully loaded ${comics.length} comics and ${topComics.length} top comics');
      
      if (mounted) {
        setState(() {
          _comics = comics;
          _topComics = topComics;
        });
        
        print('📱 LoadingScreen: All comics loaded, scheduling navigation with ${_comics.length} comics and ${_topComics.length} top comics');
        // Wait for animation to complete, then navigate with comics
        _scheduleNavigationWithComics();
      }
    } catch (e) {
      print('❌ LoadingScreen: Error loading comics: $e');
      // If loading fails, still navigate to home screen (it will handle its own loading)
      if (mounted) {
        print('🔄 LoadingScreen: Navigating to home screen despite error');
        _scheduleNavigationWithComics();
      }
    }
  }

  void _scheduleNavigationWithComics() {
    print('⏰ LoadingScreen: Scheduling navigation with ${_comics.length} comics and ${_topComics.length} top comics');
    // Wait for animation to complete, then navigate with comics
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        print('🚀 LoadingScreen: Navigating to HomeScreen with ${_comics.length} comics and ${_topComics.length} top comics');
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
              initialComics: _comics,
              initialTopComics: _topComics,
              initialDomain: _currentDomain, // Pass the domain used to fetch comics
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a1a),
              Color(0xFF2d2d2d),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with zoom Hero animation and thunder effect
              Hero(
                tag: 'app_logo',
                child: AnimatedBuilder(
                  animation: Listenable.merge([_animationController, _pulseController]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value * _pulseAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Logo as the base layer
                            Image.asset(
                              'assets/images/logo.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[800],
                                  child: const Center(
                                    child: Icon(
                                      Icons.auto_stories,
                                      size: 80,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Thunder animation overlaid on top of the logo
                            AnimatedOpacity(
                              opacity: _thunderAnimation.value,  // Fades in after logo finishes
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer( // Prevents thunder animation from blocking logo taps
                                child: Lottie.asset(
                                  'assets/animations/RL.json',
                                  width: 250,
                                  height: 200,
                                  controller: _thunderLottieController,
                                  repeat: false, // Don't repeat automatically
                                  animate: true,
                                  onLoaded: (composition) {
                                    print('✅ Thunder Lottie animation loaded successfully!');
                                    print('   - Duration: ${composition.duration}');
                                    print('   - Frame rate: ${composition.frameRate}');
                                    print('   - Bounds: ${composition.bounds}');
                                    
                                    // Set the duration and start the animation
                                    _thunderLottieController.duration = composition.duration;
                                    // Start thunder animation after logo animation completes
                                    Future.delayed(const Duration(milliseconds: 1200), () {
                                      if (mounted) {
                                        _thunderLottieController.forward();
                                      }
                                    });
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('❌ Thunder Lottie animation failed to load:');
                                    print('   - Error: $error');
                                    print('   - Stack trace: $stackTrace');
                                    // Fallback to static icon
                                    return Icon(
                                      Icons.flash_on,
                                      color: Colors.yellow,
                                      size: 40,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              

            ],
          ),
        ),
      ),
    );
  }
}
