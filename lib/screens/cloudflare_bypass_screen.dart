import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CloudflareBypassScreen extends StatefulWidget {
  final String url;
  const CloudflareBypassScreen({Key? key, required this.url})
      : super(key: key);

  @override
  _CloudflareBypassScreenState createState() =>
      _CloudflareBypassScreenState();
}

class _CloudflareBypassScreenState extends State<CloudflareBypassScreen> {
  late InAppWebViewController _controller;
  bool _hasBypassed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify you are human')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(javaScriptEnabled: true),
        ),
        onWebViewCreated: (ctrl) => _controller = ctrl,
        onLoadStop: (ctrl, uri) async {
          final title = await ctrl.getTitle() ?? '';
          // once it’s no longer the “Just a moment…” page, assume success
          if (!_hasBypassed &&
              !title.toLowerCase().contains('just a moment')) {
            _hasBypassed = true;
            Navigator.pop(context, true);
          }
        },
      ),
    );
  }
}
