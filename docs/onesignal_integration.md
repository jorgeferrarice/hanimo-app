# OneSignal Integration

This document describes the OneSignal integration implemented in the HaniMo app.

## Overview

The OneSignal integration automatically registers authenticated users and saves their OneSignal ID to Firestore under the path `users/{firebase_uid}`.

## Features

- ✅ Automatic OneSignal initialization on app startup
- ✅ User registration with OneSignal on authentication (Google, Apple, Anonymous)
- ✅ OneSignal ID saved to Firestore under `users/{firebase_uid}`
- ✅ User unregistration on sign out
- ✅ Automatic retry mechanism if OneSignal ID is not immediately available
- ✅ User tagging with provider information and Firebase UID

## Configuration

**OneSignal App ID**: `dd96efea-6c12-40c3-ad8d-9ab8b16bdda2`

## Implementation Details

### 1. Dependencies Added

```yaml
dependencies:
  cloud_firestore: ^5.5.0
  onesignal_flutter: ^5.2.6
```

### 2. OneSignal Service (`lib/services/onesignal_service.dart`)

A singleton service that handles:
- OneSignal initialization
- User registration and deregistration
- Firestore integration
- Event listeners for notifications

### 3. Authentication Integration

The `AuthService` has been updated to automatically register users with OneSignal after successful authentication:

- **Google Sign-In**: Registers user after Google authentication
- **Apple Sign-In**: Registers user after Apple authentication  
- **Anonymous Sign-In**: Registers anonymous users
- **Sign Out**: Unregisters user from OneSignal

### 4. App Initialization

OneSignal is initialized during app startup in `main.dart` along with other services.

### 5. Existing User Handling

The `AuthWrapper` checks for existing authenticated users and registers them with OneSignal if they haven't been registered yet.

## Firestore Document Structure

When a user is registered with OneSignal, their document in Firestore (`users/{firebase_uid}`) will contain:

```json
{
  "oneSignalId": "onesignal-generated-user-id",
  "lastUpdated": "2024-01-01T00:00:00.000Z"
}
```

## User Tags

The following tags are automatically set for each user:

- `firebase_uid`: The Firebase user ID
- `provider`: Authentication provider (`google`, `apple`, `anonymous`, etc.)
- `display_name`: User's display name (if available)

## Usage Examples

### Get OneSignal User ID

```dart
// Get current OneSignal user ID
final oneSignalId = await OneSignalService.instance.oneSignalUserId;
print('OneSignal ID: $oneSignalId');
```

### Check Subscription Status

```dart
// Check if user is subscribed to push notifications
final isSubscribed = OneSignalService.instance.isSubscribed;
print('Push notifications enabled: $isSubscribed');
```

### Manual User Registration

```dart
// Manually register a user (usually not needed as it's automatic)
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  await OneSignalService.instance.registerUser(user);
}
```

## Flow Diagram

```
App Start
    ↓
Initialize OneSignal
    ↓
User Authentication
    ↓
Register with OneSignal
    ↓
Get OneSignal User ID
    ↓
Save to Firestore (users/{firebase_uid})
    ↓
Set User Tags
```

## Error Handling

The integration includes comprehensive error handling:

- Graceful failure if OneSignal initialization fails
- Retry mechanism if OneSignal ID is not immediately available
- Error logging for debugging
- Firestore write failures are logged but don't break the flow

## Testing

To test the integration:

1. Run the app
2. Sign in with any provider (Google, Apple, or Anonymous)
3. Check the console logs for OneSignal registration messages
4. Verify the OneSignal ID is saved in Firestore under `users/{firebase_uid}`
5. Test push notifications from the OneSignal dashboard

## Notes

- OneSignal debug logging is enabled by default (can be disabled in production)
- The integration automatically handles existing users when they open the app
- Push notification permission is requested automatically on initialization
- Users are automatically unregistered from OneSignal when they sign out 