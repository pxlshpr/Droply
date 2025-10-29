# Droply Setup Guide

## Overview

I've built a complete music marker app integrated into your Droply project with the following features:

### Features Implemented:
- **Apple Music Integration**: Uses modern MusicKit for playback and authorization
- **Now Playing View**: Beautiful UI showing album artwork, song info, and playback controls
- **Marker System**: Add markers to songs with emojis and optional names
- **Buffer Time**: Configure each marker to start playback X seconds before the marker position
- **Visual Timeline**: See all markers on an interactive timeline with the current playback position
- **Quick Cue**: Tap any marker to instantly jump to that position (with buffer applied)
- **SwiftData Persistence**: All markers are saved locally
- **CloudKit Sync**: Markers sync across all your devices automatically

### Use Cases Supported:
1. **Gym goer**: Mark the drop in a song, set a 30s buffer, tap the button while walking to the squat rack
2. **Guitarist**: Mark where the solo starts with a 5s buffer to get ready before it begins
3. **Dancer**: Mark key choreography moments to practice specific sections
4. **Podcaster**: Mark important timestamps in music tracks for editing

## Project Structure

```
Droply/
├── Models/
│   ├── MarkedSong.swift       # Song with markers
│   └── SongMarker.swift       # Individual marker (timestamp, emoji, name, buffer)
├── Services/
│   └── MusicKitService.swift  # Apple Music playback & authorization
└── Views/
    ├── ContentView.swift      # Main entry with authorization flow
    └── Music/
        ├── NowPlayingView.swift       # Main playback view
        ├── MarkerTimelineView.swift   # Visual timeline with markers
        ├── AddMarkerView.swift        # Add/edit marker sheet
        └── MarkerListView.swift       # List of markers below timeline
```

## Required Xcode Configuration

### 1. Add MusicKit Capability
1. Open the Xcode project
2. Select your target (Droply)
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add **"MusicKit"**

### 2. Add iCloud Capability (for CloudKit sync)
1. In the same "Signing & Capabilities" tab
2. Click "+ Capability"
3. Add **"iCloud"**
4. Check **"CloudKit"**
5. Add a container: `iCloud.com.yourcompany.droply` (or use your own identifier)
6. Update the cloudKitDatabase identifier in `DroplyApp.swift:23` to match your container

### 3. Add Background Modes (already configured in Info.plist)
- ✅ Audio (for background playback)
- ✅ Remote notifications (for CloudKit sync)

### 4. Update Team & Bundle ID
1. In "Signing & Capabilities"
2. Select your development team
3. Ensure your bundle identifier is unique

### 5. Test on Physical Device
- MusicKit requires a physical device to test (Simulator has limited support)
- Device must be signed into Apple Music

## How to Use the App

### First Launch:
1. App will request Apple Music authorization
2. Grant permission to access your Apple Music library
3. Play a song from the Apple Music app

### Adding Markers:
1. While a song is playing, tap the **bookmark button** (orange circle)
2. Select an emoji that represents this moment
3. Optionally add a name (e.g., "Drop", "Solo", "Chorus")
4. Set a buffer time (0-30 seconds) - playback will start this many seconds BEFORE the marker
5. Tap "Save Marker"

### Using Markers:
- **Tap on the timeline**: Jump to that exact position
- **Tap a marker emoji on timeline**: Jump to the marker with buffer applied
- **Tap a marker in the list**: Same as tapping on timeline
- **Long-press a marker**: Delete it via context menu

### Buffer Time Example:
If you mark a drop at 1:30 and set a 10s buffer:
- Marker shows at 1:30 on timeline
- Tapping it starts playback at 1:20
- You get 10 seconds to prepare before the drop

## Code Highlights

### SwiftData Models
- **MarkedSong**: Stores song metadata and has a relationship to markers
- **SongMarker**: Individual markers with emoji, name, timestamp, and buffer time
- Automatic cascade delete: Removing a song removes all its markers

### MusicKit Service
- Singleton service managing all Apple Music interactions
- Observable object publishing current playback state
- Real-time playback time updates (10 times per second)
- Methods for seeking, playing, pausing, and cueing markers

### CloudKit Sync
- Configured in `DroplyApp.swift` with `cloudKitDatabase: .private()`
- SwiftData automatically syncs all models to your private CloudKit database
- Markers appear on all devices signed into the same iCloud account

## Next Steps

### Enhancements You Could Add:
1. **Song Browser**: Add a view to search and browse Apple Music
2. **Playlists**: Create playlists of songs with markers
3. **Sharing**: Share marker sets with friends
4. **Waveform Visualization**: Display actual audio waveform (requires additional processing)
5. **Haptic Feedback**: Vibrate when approaching a marker
6. **Apple Watch Companion**: Control markers from your wrist
7. **Marker Colors**: Assign colors to different marker types
8. **Export**: Export marker positions as timestamps for other uses

### Testing Checklist:
- [ ] Authorization flow works
- [ ] Can add markers while playing
- [ ] Markers appear on timeline
- [ ] Tapping markers seeks correctly
- [ ] Buffer time works as expected
- [ ] Markers persist after closing app
- [ ] Markers sync to other devices (test with 2 devices)

## Troubleshooting

### "Not Authorized" Error:
- Check Settings > Privacy > Media & Apple Music > Droply
- Ensure MusicKit capability is added in Xcode

### CloudKit Not Syncing:
- Verify iCloud is enabled on all devices
- Check iCloud capability is properly configured
- Ensure container identifier matches in code and Xcode

### Playback Issues:
- Ensure you have an active Apple Music subscription
- Test on a physical device (Simulator support is limited)
- Check audio output is not muted

## API Reference

### Key Methods:

#### MusicKitService
```swift
await musicService.requestAuthorization() // Request access
await musicService.play() // Start playback
musicService.pause() // Pause playback
await musicService.seek(to: time) // Seek to position
await musicService.seekToMarker(marker) // Seek with buffer
```

#### Adding Markers
```swift
let marker = SongMarker(
    timestamp: currentTime,
    emoji: "🔥",
    name: "Drop",
    bufferTime: 5.0
)
marker.song = markedSong
modelContext.insert(marker)
```

---

**Note**: Remember to update the CloudKit container identifier in `DroplyApp.swift` line 23 to match your actual container!

Enjoy your music marker app! 🎵
