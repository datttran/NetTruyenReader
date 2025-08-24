import 'package:flutter/material.dart';

class NetworkErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData? icon;

  const NetworkErrorWidget({
    Key? key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.wifi_off,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NetworkErrorSnackBar {
  static void show(BuildContext context, String message,
      {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
