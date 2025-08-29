# Changelog - Version 0.0.2

## 🎯 **Features**

### 🌐 **Connectivity Monitoring**
- **Added `connectivity_plus` package** for real-time internet connectivity monitoring
- **Implemented ConnectivityService** that monitors both network state and actual internet access
- **Created NoInternetScreen** with fun animations when offline:
  - Rotating WiFi-off icon animation
  - Bouncing main content with elastic animation
  - Fading "checking connection" message
  - Scaling emoji animations (📱💔📶)
  - Anime-themed humor: "Even anime characters need WiFi! 🎌"
- **Added ConnectivityWrapper** that overlays the no internet screen when offline
- **Smooth slide animations** when showing/hiding connectivity screen
- **Automatic detection** of connectivity changes with instant response
- **Non-blocking initialization** with proper loading states

### 📅 **Episode Calendar Sync**
- **Replaced share button with calendar sync** in anime details screen
- **Smart button visibility**: Calendar button only appears when episodes are available
- **Created EpisodeCalendarSyncDialog** for syncing future episodes to device calendar
- **Multi-select episode selection** with checkbox list and "All/None" quick actions
- **Smart episode filtering**: Only shows today's episodes and future episodes
- **Calendar and time selection**: Choose target calendar and notification time
- **30-minute calendar events** with rich episode information:
  - Anime title and episode details in event title and description
  - Episode air date, score, and anime synopsis
  - Direct link to anime page
  - Anime emoji decorations (🎌📺🎬)
- **Error handling** with permissions requests and validation
- **Progress tracking** with success/failure counts

### 📅 **In-App Review System**
- **Added comprehensive review functionality**
- **Manual review button in Settings page**
- **Automatic review trigger after following 3rd anime**
- **10-day cooldown period between review requests**
- **Persistent review tracking to avoid repeated requests**
- **Graceful fallback for unsupported devices**

### 📅 **Account Management**
- **Added account deletion functionality**
- **Delete account button in Settings page (authenticated users only)**
- **Comprehensive confirmation dialog explaining irreversible consequences**
- **Soft delete approach: preserves Firebase Auth account but marks data as deleted**
- **Complete data cleanup (Firestore + Firebase Auth)**
- **Proper service cleanup (OneSignal, Crashlytics, Analytics)**
- **Automatic navigation to login screen after deletion**

### 📅 **UI Improvements**
- **Enhanced dialog layouts for better mobile experience**
- **Add to Watchlist dialog now uses 98% screen width while remaining centered**
- **Calendar sync dialog now uses 98% screen width while remaining centered**
- **Better space utilization on mobile devices**
- **Maintained maximum width constraints for larger screens**

## 🐛 **Bug Fixes**

### 👤 **Apple Sign In Display Fix**
- **Fixed Apple Sign In users showing "Anonymous User"** instead of their email in the profile screen
- **Enhanced user display logic** with intelligent fallback system:
  - Users with both name and email → Show both
  - Users with no name but with email → Show email as main display *(fixes Apple Sign In)*
  - Users with name but no email → Show only name
  - Anonymous users → Show "Anonymous User" (fallback)
- **Improved UX for Apple Sign In** users who typically don't provide display names during signup
- **Clean profile layout** that only shows relevant user information

### 🔍 **Duplicate Anime Prevention**
- **Eliminated duplicate animes** across all lists, searches, and calendar views
- **Implemented AnimeUtils deduplication system** based on `malId` (MyAnimeList ID)
- **Applied to all anime displays**:
  - Home screen (Popular, This Season, Next Season, Airing Today)
  - Search results and pagination
  - Anime list screens with infinite scroll
  - User profile followed anime grid
  - Calendar release schedules
- **Smart deduplication** keeps the first occurrence of each unique anime
- **Debug logging** shows how many duplicates were removed from each list

## 🔧 **Technical Improvements**

### 🔌 **Connectivity Implementation**
- Added connectivity checking with real internet access validation (pings Google)
- Integrated connectivity wrapper at the app root level
- Proper Android permissions already in place (`INTERNET`, `ACCESS_NETWORK_STATE`)
- iOS compatibility without additional permissions required

### 👤 **User Profile Enhancements**
- Refactored user display logic into reusable `_buildUserDisplayInfo()` method
- Better handling of different authentication provider scenarios
- Improved code maintainability and readability

### 🔧 **Anime Data Management**
- Created new `AnimeUtils` class with comprehensive deduplication utilities
- Support for deduplicating Map<String, dynamic>, MockAnime, and UserAnime lists
- Additional utilities for anime list filtering, merging, and ID extraction
- Centralized anime data manipulation logic for consistency across the app

### 📅 **Calendar Integration**
- New EpisodeCalendarSyncDialog widget with comprehensive calendar management
- Integration with device_calendar plugin and timezone handling
- TZDateTime conversion for proper calendar event scheduling
- Intelligent episode filtering based on air dates
- Calendar permissions handling with user-friendly error messages

### 🔧 **Cache System**
- Implemented comprehensive caching strategy
- Memory cache for instant access
- SQLite cache for persistent storage
- R2 cache for cloud backup
- Smart cache invalidation and refresh

### 🔧 **Code Organization**
- Improved code structure and maintainability
- Created utility classes for common operations
- Better separation of concerns
- Enhanced error handling and logging

## 📱 **Platform Support**

- **Android**: Full connectivity monitoring support
- **iOS**: Full connectivity monitoring support
- **Apple Sign In**: Enhanced display name handling
- **Google Sign In**: Maintains existing functionality

---

**Release Date**: January 2025  
**Build**: 0.0.2+1

## 📱 **TLDR - App Store "Latest Changes"**

**🌐 Never lose connection!** New offline detection with fun animations shows when you need internet - even anime characters need WiFi! 🎌

**👤 Apple Sign In fixed!** No more "Anonymous User" - your email now displays properly in your profile.

**✨ What's New:**
• 📅 **NEW!** Sync anime episodes to your calendar - never miss a release!
• Real-time connectivity monitoring with animated offline screen
• Fixed Apple Sign In profile display issue
• Eliminated duplicate animes across all lists and searches
• Smoother user experience with better error handling
• Fun anime-themed animations when offline

*Perfect for tracking your favorite anime releases! Download now and never miss an episode.* 📺 