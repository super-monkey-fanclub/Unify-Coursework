# Implementation Summary: Notifications, Account Settings, Email Opt-In & Enhanced Analytics

## Overview
Implemented per-society notifications with admin alerts for reviews, account settings page with password/email/mailing-list management, email opt-in during signup & settings, and enhanced analytics dashboard. All features follow the app's blue theme (#003087).

---

## Backend Changes (Django)

### 1. **New Model: Notification** (`backend/core/models.py`)
- Fields:
  - `user` (FK to User) — recipient
  - `society` (FK to Society) — context
  - `notif_type` — 'info', 'review', or 'poll'
  - `message` (max 500 chars)
  - `link` — optional URL
  - `created_at` — timestamp
  - `read` — boolean flag
- Ordering by `-created_at`
- Admin interface registered

### 2. **User Model Enhancement** (`backend/core/models.py`)
- Added `opt_in_email` field (BooleanField, default=False) to User model
- Captures user preference for mailing list communications

### 3. **New Migration** (`backend/core/migrations/0007_add_notification.py`)
- Creates notification table with proper indexes and constraints
- Already applied: `python manage.py migrate` ✓

### 4. **API Endpoints** (`backend/core/views.py`)

#### `POST /api/auth/register/` (Enhanced)
- Accepts `opt_in_email` boolean from request body
- Stores preference on user record during signup
- Returns `opt_in_email` in user response

#### `POST /api/auth/settings/` (New)
- Update email, password, and opt-in preference
- Auth via Bearer token or email+current_password
- Validates new email uniqueness and password length (min 8)
- Returns updated user object

#### `GET /api/notifications/` (New)
- Query params: `society` (required), `viewer_email`, `auth_token`
- Returns list of notifications for authenticated user in that society
- Only society members can fetch
- Response: `{'notifications': [...]}`

#### `POST /api/notifications/mark_read/` (New)
- Body: `{'notification_id': <int>}`
- Marks single notification as read by current user
- Auth via Bearer token

#### **Auto-emit on Review Creation**
- When new Review is created via `add_review_view`, system creates Notification objects for all society admins
- Message: `"New review for {society_name} by {user.email}"`
- Type: 'review'

### 5. **URL Routing** (`backend/unify/urls.py`)
- `/api/notifications/` → `get_notifications_view`
- `/api/notifications/mark_read/` → `mark_notification_read_view`
- `/api/auth/settings/` → `account_settings_view`

### 6. **Tests** (`backend/core/tests_notifications.py`)
- 9 new tests, all passing ✅
  - Notification retrieval auth/membership checks
  - Mark-as-read functionality
  - Account settings updates (email, password, opt-in)
  - Registration with opt-in flag

---

## Frontend Changes (Flutter)

### 1. **Auth Service Enhancement** (`unify_frontend/lib/services/auth_service.dart`)

#### `register()` - Enhanced
```dart
register({
  required String name,
  required String email,
  required String password,
  bool optInEmail = false,  // NEW
})
```
- Sends `opt_in_email` to backend

#### `updateSettings()` - New
```dart
updateSettings({
  String? authToken,
  String? email,
  String? currentPassword,
  String? newEmail,
  String? newPassword,
  bool? optInEmail,
})
```
- Calls `POST /api/auth/settings/`
- Returns updated user object

### 2. **Account Settings Page** (`unify_frontend/lib/account_settings.dart` - New File)
- Blue header bar matching app theme (#003087)
- Fields:
  - Email field (with validation)
  - Current password (required for security)
  - New password (optional, 8+ chars)
  - Mailing list checkbox
- Save button calls `updateSettings()` and pops result

### 3. **Profile Page Enhancement** (`unify_frontend/lib/profile.dart`)
- Registration form: added checkbox for "Join the mailing list for updates"
  - Updates state on checkbox change
  - Passes `optInEmail` to `_authService.register()`
- Logged-in view: added "Account settings" button (blue styling)
  - Navigates to `AccountSettingsPage`
  - Refreshes user data on return
- Import `account_settings.dart`

### 4. **Notifications UI** (`unify_frontend/lib/socieites.dart`)

#### `SocietyNotificationsPage` - Enhanced
- New state: `List<_NotificationItem> _notifications`
- New method: `_loadNotifications()` 
  - Calls `_societyService.getNotifications()`
  - Parses response into `_NotificationItem` objects
- Modified `initState` → `_loadData()` 
  - Calls `_loadPolls()` and `_loadNotifications()` in parallel
- Notifications card displays above polls/info:
  - List of notifications with timestamps
  - Unread notifications have bold text
  - "Mark read" button for unread items
  - Calls `_societyService.markNotificationRead()` on click

#### `_NotificationItem` Model (New)
```dart
class _NotificationItem {
  final int id;
  final String type;      // 'info', 'review', 'poll'
  final String message;
  final String link;
  final DateTime createdAt;
  final bool read;
  // fromJson factory method
}
```

### 5. **Society Service Enhancement** (`unify_frontend/lib/services/society_service.dart`)

#### `getNotifications()` - New
```dart
getNotifications({
  required String societyName,
  String? viewerEmail,
  String? authToken,
})
```
- Calls `GET /api/notifications/?society=<name>`
- Returns `{'success': bool, 'notifications': List<Map>}`

#### `markNotificationRead()` - New
```dart
markNotificationRead({
  required int notificationId,
  String? authToken,
})
```
- Calls `POST /api/notifications/mark_read/`
- Returns `{'success': bool, 'message': str}`

### 6. **Enhanced Analytics Dialog** (`unify_frontend/lib/socieites.dart`)
- **Summary stats card** (blue background):
  - Total reviews
  - Average rating (displayed in primary color)
- **Improved table**:
  - Month, Rating (bold + primary color), Reviews
  - Better formatting and spacing
- **Title**: "Review Analytics – {SocietyName}" (blue header text)
- Maintains existing monthly trend data visualization

---

## Styling & Theme Consistency

### Blue Theme (UoP Colors)
- Primary: `#003087` (UoP Blue)
- Secondary: `#7B2D8E` (UoP Purple)
- Applied to all new headers, buttons, and highlights:
  - Account Settings page AppBar
  - Analytics dialog title
  - Summary stats card
  - Avg rating value in table
  - "Settings" button (blue-styled)

### Header Consistency
- All new pages use `AppBar` with:
  ```dart
  backgroundColor: Theme.of(context).colorScheme.primary
  foregroundColor: Colors.white
  ```
- Matches existing app design language

---

## Database & Migrations

### Applied Migration
```
Applying core.0007_add_notification... OK
```

### New Tables/Columns
- `core_notification` table (ID, user_id, society_id, type, message, link, created_at, read)
- `core_user.opt_in_email` column (boolean, default=false)

---

## API Contract Summary

### Registration (Enhanced)
```
POST /api/auth/register/
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "secure123",
  "opt_in_email": true  // NEW
}
→ 201 {"user": {..., "opt_in_email": true}, "auth_token": "..."}
```

### Account Settings (New)
```
POST /api/auth/settings/
Authorization: Bearer <token>
{
  "email": "john@example.com",
  "current_password": "secure123",
  "new_email": "john.doe@example.com",  // optional
  "new_password": "newsecure456",        // optional
  "opt_in_email": false                  // optional
}
→ 200 {"message": "Settings updated.", "user": {...}}
```

### Get Notifications (New)
```
GET /api/notifications/?society=Chess%20Club&viewer_email=user@example.com
→ 200 {"notifications": [
    {"id": 1, "type": "review", "message": "New review...", "created_at": "...", "read": false},
    ...
  ]}
```

### Mark Notification Read (New)
```
POST /api/notifications/mark_read/
Authorization: Bearer <token>
{"notification_id": 123}
→ 200 {"message": "Notification marked read."}
```

---

## Testing

### Backend Tests ✅
- 9 new tests in `core/tests_notifications.py`
- All passing (Run: `python manage.py test core.tests_notifications -v 2`)
- Coverage:
  - Notification retrieval auth/membership validation
  - Mark-as-read with auth
  - Account settings updates (email, password, opt-in)
  - Registration opt-in flag persistence

### Flutter Analysis ✅
- `flutter analyze --no-fatal-infos` 
- No issues found

---

## Features Enabled

1. ✅ **Per-society notifications** displayed in Events & Polls page
2. ✅ **Admin review alerts** — admins notified when reviews added
3. ✅ **Account Settings page** — change email, password, mailing-list opt-in
4. ✅ **Signup opt-in** — checkbox on registration form
5. ✅ **Enhanced analytics** — summary stats + better table formatting
6. ✅ **Blue theme consistency** — all new UI follows UoP color scheme
7. ✅ **Mark notifications read** — unread/read state tracking

---

## Known Limitations

- Email notifications not yet sent (as requested)
- Notifications page shows per-society only (global notifications can be added later)
- Chart library not added (data table sufficient for MVP; can enhance with `fl_chart` or `charts_flutter` if needed)

---

## Next Steps (Optional Enhancements)

1. Add email-sending logic (requires mail service config)
2. Add chart visualization to analytics (add `fl_chart` dependency)
3. Add notification badge count to app icons
4. Implement notification preferences per user (which event types to notify)
5. Add push notifications (Firebase Cloud Messaging)

