import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Presents a visible WebView to solve Cloudflare challenge,
/// then captures & stores cookies for later headless usage.
class CFChallengeScreen extends StatefulWidget {
  @override
  _CFChallengeScreenState createState() => _CFChallengeScreenState();
}

class _CFChallengeScreenState extends State<CFChallengeScreen> {
  late InAppWebViewController _controller;
  static const _targetUrl = 'https://nettruyenvio.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify access')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_targetUrl)),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
        ),
        onWebViewCreated: (ctrl) => _controller = ctrl,
        onLoadStop: (ctrl, url) async {
          final uri = url?.toString() ?? '';
          // When we land back on the main page (no challenge)
          if (uri.startsWith(_targetUrl) && !uri.contains('challenge')) {
            // grab cookies
            final cm = CookieManager.instance();
            final cookies = await cm.getCookies(url: WebUri(_targetUrl));
            final prefs = await SharedPreferences.getInstance();
            final raw = cookies.map((c) => '${c.name}=${c.value}').toList();
            await prefs.setStringList('nettruyen_cookies', raw);
            await prefs.setBool('cf_solved', true);
            Navigator.of(context).pop(true);
          }
        },
      ),
    );
  }
}

/// Call this before any headless/scraper WebView run to ensure CF cookies are set.
class CloudflareService {
  /// Must pass a BuildContext to show the visible CF challenge if needed.
  static Future<void> ensureCookies(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('cf_solved') ?? false;
    if (!done) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CFChallengeScreen()),
      );
      if (success != true) throw Exception('Cloudflare challenge not solved');
    }
    // inject cookies into WebView cookie manager
    final raw = prefs.getStringList('nettruyen_cookies') ?? [];
    await Future.wait(raw.map((nv) {
      final parts = nv.split('=');
      return CookieManager.instance().setCookie(
        url: WebUri('https://nettruyenvio.com'),
        name: parts[0],
        value: parts[1],
      );
    }));
  }
}

/// Example usage before headless run:
/// await CloudflareService.ensureCookies(context);
/// await headless.run();
