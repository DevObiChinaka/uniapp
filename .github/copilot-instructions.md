# Copilot Instructions for UniApp (SALMS)

## Project Overview

**Smart Attendance & Leave Management System (SALMS)** - A Flutter mobile app with Django REST backend for university attendance tracking using biometric verification, BLE proximity, and QR codes.

### Architecture

- **Frontend**: Flutter (Provider state management, Go Router navigation)
- **Backend**: Django REST Framework with JWT auth, PostgreSQL/SQLite
- **Key Features**: Face recognition, BLE proximity detection, QR scanning, Firebase push notifications

## Critical File Structure

```
backend/uniapp/
├── users/          # All models, views, serializers (attendance, sessions, leave requests)
├── uniapp/         # Settings, URLs, main config
frontend/uniapp/lib/
├── services/       # core_services.dart (API), face_service.dart (biometrics)
├── screens/        # app_provider.dart (global state), admin_dashboard.dart
├── models/         # models.dart (User, AttendanceRecord, LeaveRequest, etc.)
├── routes/         # app_router.dart (Go Router config)
```

## Development Patterns

### API Integration

- **Frontend-Backend Field Mapping**: Frontend uses camelCase, backend snake_case
  - Frontend `universityId` ↔ Backend `university_id`
  - Frontend `isOnCampus` ↔ Backend `is_on_campus`
- **API Endpoints**: All in `users/urls.py` with admin routes under `/api/admin/`
- **Auth Flow**: JWT tokens stored in SharedPreferences, auto-refresh in Dio interceptors

### State Management

- **Provider Pattern**: `AppProvider` in `screens/app_provider.dart` manages global state
- **Core Services**: `CoreServices` class handles all API calls, BLE, Firebase FCM
- **Service Initialization**: Deferred in `main.dart` to prevent main thread blocking

### Role-Based Features

- **Students**: Face/fingerprint verification, QR scanning, leave requests
- **Admins**: Dashboard with tabs (Students, Leave Requests, System Logs, Profile)
- **User Model**: Role-based auth with university_id (students) vs username (admins)

### Data Synchronization

- **Pull-to-Refresh**: Implemented on all admin dashboard tabs
- **Debug Logging**: Extensive `debugPrint()` statements for API responses and data parsing
- **Error Handling**: Standardized error responses with specific error codes (BLE_RANGE_ERROR, SESSION_CONFLICT)

## Key Development Commands

```bash
# Frontend (run from frontend/uniapp/)
flutter run --debug                    # Development build
flutter build apk --release           # Production build
flutter clean && flutter pub get      # Reset dependencies

# Backend (run from backend/uniapp/)
python manage.py runserver 0.0.0.0:8000    # Development server
python manage.py makemigrations && python manage.py migrate  # Database updates
python manage.py createsuperuser          # Admin user
```

## Critical Integration Points

### API Parameter Naming

Always check `API_SYNC_ANALYSIS.md` when adding new endpoints. Frontend camelCase must map to backend snake_case in serializers.

### Authentication Flow

1. Login → JWT tokens stored in SharedPreferences
2. CoreServices Dio interceptor adds Bearer token automatically
3. Token refresh on 401 errors
4. FCM token registration after successful login

### Biometric Integration

- Face recognition via `face_service.dart` using Google ML Kit
- BLE proximity detection with RSSI thresholds (-70 dBm limit)
- Fallback QR code scanning for attendance

### Admin Dashboard Tabs

Each tab has RefreshIndicator, empty states, and proper error handling:

- **Students Tab**: University ID display, campus status toggle
- **Leave Requests Tab**: Approval/denial with status management
- **System Logs Tab**: Filterable logs with type-based icons
- **Profile Tab**: Admin info display and campus status toggle

## Common Gotchas

- **Method Signatures**: Always include BuildContext when methods use Theme.of(context)
- **Model Validation**: User model requires either university_id (students) OR username (admins), not both
- **API Endpoints**: Backend ViewSets need custom update() methods for campus tag and leave status
- **Performance**: Heavy initialization (Firebase, services) must be deferred to prevent frame drops

## Testing & Debugging

- Use extensive `debugPrint()` for API call tracing
- Check browser network tab for 404s when testing admin endpoints
- Verify JWT token storage with SharedPreferences debug output
- Test BLE functionality requires physical devices (simulators lack BLE)
