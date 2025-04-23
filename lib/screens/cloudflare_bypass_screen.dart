import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';








class CloudflareBypassScreen extends StatefulWidget {
  final String url;

  const CloudflareBypassScreen({Key? key, required this.url}) : super(key: key);

  @override
  _CloudflareBypassScreenState createState() => _CloudflareBypassScreenState();
}

class _CloudflareBypassScreenState extends State<CloudflareBypassScreen> {
  final CookieManager _cookieManager = CookieManager.instance();
  bool _hasClearance = false;
  bool _loading = true;
  bool _closing = false;
  Timer? _timeoutTimer;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!_hasClearance && !_closing && mounted) {
        _closeScreen();
      }
    });
  }

  void _closeScreen() {
    if (_closing) return;
    _closing = true;
    _timeoutTimer?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _saveCookies() async {
    final cookies = await _cookieManager.getCookies(url: WebUri(widget.url));
    final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookie', cookieString);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifying...'),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                javaScriptEnabled: true,
              ),
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },

            onTitleChanged: (controller, title) async {
              if (title == null) return;

              final lowerTitle = title.toLowerCase();
              print('WebView title changed: $lowerTitle');

              if (!lowerTitle.contains('checking your browser') &&
                  !lowerTitle.contains('just a moment') &&
                  !lowerTitle.contains('attention required')) {
                // ✅ Title is normal now
                print('Page is clean, closing WebView automatically.');

                // Save cookies if you need
                await _saveCookies();

                // Close the WebView screen
                if (mounted) {
                  Navigator.of(context).pop(true);
                }
              }
            },
            onLoadStop: (controller, url) async {
              setState(() {

                _loading = false;
              });

              // Inject JavaScript once page is loaded
              await controller.evaluateJavascript(source: """
                if (window._cfMonitorInterval == null) {
                  window._cfMonitorInterval = setInterval(function() {
                    if (document.cookie.includes('cf_clearance')) {
                      console.log('CF_CLEARANCE_FOUND');
                      clearInterval(window._cfMonitorInterval);
                    }
                  }, 300);
                }
              """);
            },
            onLoadStart: (controller, url) {
              setState(() {
                _loading = true;
              });
            },
            onConsoleMessage: (controller, consoleMessage) async {
              if (consoleMessage.message == 'CF_CLEARANCE_FOUND' && !_hasClearance && !_closing) {
                _hasClearance = true;
                await _saveCookies();
                _closeScreen();
              }
            },
          ),
          if (_loading)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
