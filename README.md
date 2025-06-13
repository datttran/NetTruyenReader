# NetTruyen Reader

A polished, ad-free comic reading experience for NetTruyen.

## Features

- **Network Error Handling**: Comprehensive error handling for network connectivity issues
- **Retry Logic**: Automatic retry with exponential backoff for failed requests
- **User-Friendly Error Messages**: Clear, actionable error messages instead of technical jargon
- **Network Status Indicator**: Real-time network connectivity status
- **Offline Support**: Cached content for offline reading

## Network Error Handling

The app includes robust error handling for various network scenarios:

### Connection Refused Error
- **Cause**: Server is down, blocked, or unreachable
- **Solution**: The app will automatically retry with exponential backoff
- **User Action**: Check internet connection and try again later

### Connection Timeout
- **Cause**: Slow network or server response
- **Solution**: Automatic retry with increased timeout
- **User Action**: Check network speed and try again

### DNS Resolution Issues
- **Cause**: Unable to resolve domain names
- **Solution**: Check internet connection and DNS settings
- **User Action**: Try switching networks or using a VPN

### Server Errors (403, 404, 500)
- **Cause**: Server-side issues or access restrictions
- **Solution**: App shows appropriate error messages
- **User Action**: Wait and retry, or contact support

## Troubleshooting

### If you're getting "Connection refused" errors:

1. **Check your internet connection**
   - Try accessing other websites
   - Restart your router if needed

2. **Try using a VPN**
   - The site might be blocked in your region
   - Use a VPN service to bypass restrictions

3. **Check if the site is down**
   - Visit nettruyenvio.com in your browser
   - Check if the site is accessible

4. **Clear app cache**
   - Go to Settings > Apps > NetTruyen Reader > Clear Cache
   - Restart the app

### If you're getting "Cloudflare blocked" errors:

1. **Wait a few minutes**
   - Cloudflare protection might be temporary
   - Try again after 5-10 minutes

2. **Use the "Verify you are human" option**
   - The app will open a browser window
   - Complete the Cloudflare challenge
   - Return to the app

3. **Try a different network**
   - Switch from WiFi to mobile data
   - Or vice versa

## Error Messages

The app provides user-friendly error messages:

- **"Unable to connect to the server"** - Network connectivity issue
- **"Connection timed out"** - Slow network or server response
- **"Access blocked by Cloudflare"** - Site protection active
- **"Server error"** - Temporary server issues

## Technical Details

### Retry Logic
- Maximum 3 retry attempts
- Exponential backoff (2s, 4s, 6s delays)
- Different handling for different error types

### Network Status Indicator
- Shows real-time connectivity status
- Checks both general internet and site accessibility
- Auto-refreshes when tapped

### Error Recovery
- Automatic retry on network restoration
- Manual retry buttons on error screens
- Graceful degradation for offline scenarios

## Development

### Running the app
```bash
flutter pub get
flutter run
```

### Testing network error handling
- Disconnect from internet to test offline scenarios
- Use network throttling tools to test slow connections
- Block specific domains to test DNS issues

## License

This project is for educational purposes only.
