import 'package:flutter/material.dart';
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
  late Animation<double> _scaleAnimation;
  
  List<Comic> _comics = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize single animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // Start animation
    _animationController.forward();
    
    // Load comics in background while showing animation
    _loadComicsInBackground();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadComicsInBackground() async {
    try {
      print('🔄 LoadingScreen: Starting to load comics in background...');
      final netTruyenService = NetTruyenService();
      final comics = await netTruyenService.fetchComics();
      
      print('✅ LoadingScreen: Successfully loaded ${comics.length} comics');
      
      if (mounted) {
        setState(() {
          _comics = comics;
        });
        
        print('📱 LoadingScreen: Comics loaded, scheduling navigation with ${_comics.length} comics');
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
    print('⏰ LoadingScreen: Scheduling navigation with ${_comics.length} comics');
    // Wait for animation to complete, then navigate with comics
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        print('🚀 LoadingScreen: Navigating to HomeScreen with ${_comics.length} comics');
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(initialComics: _comics),
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
              // Logo with Hero animation
              Hero(
                tag: 'app_logo',
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Image.asset(
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
