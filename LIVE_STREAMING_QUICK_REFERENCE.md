# 🎥 Live Streaming Quick Reference Card

## 🚀 Quick Start

### Import Services
```dart
import 'package:talowa/services/social_feed/index.dart';
```

### Initialize
```dart
final streaming = LiveStreamingService();
final bitrate = AdaptiveBitrateManager();
final moderation = StreamModerationService();
final analytics = StreamAnalyticsService();
final recording = StreamRecordingService();

bitrate.initialize();
```

## 📡 Host a Stream

```dart
// 1. Create session
final session = await streaming.createStreamSession(
  hostId: userId,
  config: StreamConfiguration(
    hostName: 'Your Name',
    title: 'Stream Title',
    quality: StreamQuality.hd720p,
    chatEnabled: true,
    recordingEnabled: true,
  ),
);

// 2. Start broadcast
await streaming.startBroadcast(session.id);

// 3. Monitor analytics
analytics.startTracking(session.id);

// 4. End broadcast
await streaming.endBroadcast(session.id);
analytics.stopTracking(session.id);
```

## 👥 Join as Viewer

```dart
// Join
await streaming.joinStream(streamId, viewerId);

// Chat
await streaming.sendChatMessage(
  streamId,
  ChatMessage(
    userId: userId,
    userName: 'Name',
    message: 'Hello!',
    timestamp: DateTime.now(),
  ),
);

// React
await streaming.sendReaction(
  streamId,
  StreamReaction(
    userId: userId,
    type: ReactionType.like,
    timestamp: DateTime.now(),
  ),
);

// Leave
await streaming.leaveStream(streamId, viewerId);
```

## 🛡️ Moderate

```dart
// Ban viewer
await moderation.banViewer(
  streamId: streamId,
  viewerId: userId,
  moderatorId: modId,
  duration: Duration(hours: 24),
);

// Delete message
await moderation.deleteChatMessage(
  streamId: streamId,
  messageId: msgId,
  moderatorId: modId,
);

// Slow mode
await moderation.enableSlowMode(
  streamId: streamId,
  intervalSeconds: 30,
  moderatorId: modId,
);
```

## 📊 Analytics

```dart
// Get stats
final stats = await analytics.getStreamAnalytics(streamId);
print('Views: ${stats.totalViews}');
print('Peak: ${stats.peakViewers}');
print('Engagement: ${stats.engagementRate}%');

// Real-time stream
analytics.getStreamAnalyticsStream(streamId).listen((stats) {
  // Update UI
});
```

## 🎬 Recording

```dart
// Get URL
final url = await recording.getRecordingUrl(streamId);

// Save as post
await recording.saveStreamAsPost(
  streamId,
  PostMetadata(
    title: 'Recording Title',
    hashtags: ['tag1', 'tag2'],
  ),
);
```

## 🎚️ Quality Levels

| Quality | Resolution | Bitrate | Network |
|---------|-----------|---------|---------|
| SD 480p | 854x480 | 1 Mbps | 2G/3G |
| HD 720p | 1280x720 | 2.5 Mbps | 4G |
| HD 1080p | 1920x1080 | 5 Mbps | WiFi |
| UHD 4K | 3840x2160 | 15 Mbps | Fiber |

## 🔧 Common Tasks

### Enable Screen Share
```dart
await streaming.enableScreenShare(streamId);
```

### Get Viewers
```dart
streaming.getViewersStream(streamId).listen((viewers) {
  print('${viewers.length} viewers');
});
```

### Get Chat
```dart
streaming.getChatMessagesStream(streamId).listen((messages) {
  // Display messages
});
```

### Check if Banned
```dart
final banned = await moderation.isViewerBanned(streamId, userId);
```

### Get Top Chatters
```dart
final top = await analytics.getTopChatters(streamId, limit: 10);
```

## ⚠️ Error Handling

```dart
try {
  await streaming.startBroadcast(streamId);
} catch (e) {
  if (e is LiveStreamException) {
    print('Stream error: ${e.message}');
  }
}
```

## 🔒 Security

- All operations require authentication
- Host/moderators only for management
- Banned/muted users can't chat
- Firestore rules enforce permissions

## 📱 Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Desktop (Windows, macOS, Linux)

## 🆘 Troubleshooting

**No video?**
- Check camera permissions
- Verify WebRTC support

**Poor quality?**
- Lower quality manually
- Check network speed

**Chat not working?**
- Check if muted/banned
- Verify Firestore rules

## 📚 Full Documentation

See `docs/LIVE_STREAMING_SYSTEM.md` for complete guide.

---

**Quick Reference v1.0** | TALOWA Live Streaming
