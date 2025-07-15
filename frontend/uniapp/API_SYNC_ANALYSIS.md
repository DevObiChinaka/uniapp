# API Parameter Sync Analysis Report

# Generated: July 15, 2025

## 🔍 **Critical Parameter Mismatches Found**

### 1. **ATTENDANCE ENDPOINT MISMATCHES**

#### Frontend → Backend Parameter Mapping Issues:

**📍 Core Services → Backend API**

**Frontend Call (core_services.dart:287):**

```dart
final success = await coreServices.markQRAttendance(
  userId: _userId!,
  sessionId: sessionId,
  faceVerified: true,
);
```

**Backend Expected (AttendanceSerializer):**

```python
# Expected fields in Attendance model:
- user (ForeignKey to User) ❌ MISMATCH: Frontend sends 'userId'
- session (ForeignKey to Session) ❌ MISMATCH: Frontend sends 'sessionId'
- timestamp (auto_now_add=True) ✅ OK: Auto-generated
- method (CharField) ✅ OK: Sent as 'qr'
- face_verified (BooleanField) ✅ OK: Matches
- ble_device_id (CharField) ❌ MISSING: Not sent in QR attendance
- ble_rssi (IntegerField) ❌ MISSING: Not sent in QR attendance
```

**🚨 CRITICAL ISSUE: Field Name Mismatches**

- Frontend: `userId` → Backend expects: `user`
- Frontend: `sessionId` → Backend expects: `session`

---

### 2. **BLE ATTENDANCE MISMATCHES**

**Frontend Call (core_services.dart:601):**

```dart
final success = await coreServices.markAttendance(
  userId: _userId!,           // ❌ Should be 'user'
  sessionId: sessionId,       // ❌ Should be 'session'
  faceVerified: true,         // ✅ OK
  bleDeviceId: device.id,     // ❌ Should be 'ble_device_id'
  bleRssi: bleRssi,          // ❌ Should be 'ble_rssi'
);
```

**Backend Expected (models.py:95-102):**

```python
class Attendance(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    method = models.CharField(max_length=50)
    face_verified = models.BooleanField(default=False)
    ble_device_id = models.CharField(max_length=100, blank=True, null=True)
    ble_rssi = models.IntegerField(blank=True, null=True)
```

---

### 3. **EXIT ENDPOINT MISMATCHES**

**Frontend Call (app_provider.dart:1208):**

```dart
final exitResult = await coreServices.processExit(
  userId: universityId,       // ❌ Should reference existing user
  faceId: faceId,            // ❌ Should be 'face_image'
  qrData: qrData,            // ✅ OK: Matches 'qr_data'
);
```

**Backend Expected (views.py:146):**

```python
@action(detail=False, methods=['post'])
def process(self, request):
    # Expected fields:
    - qr_data ✅ OK: Matches
    - face_image ❌ MISMATCH: Frontend sends 'faceId'
    # Note: userId not needed as it comes from request.user
```

---

### 4. **EMERGENCY EXIT MISMATCHES**

**Frontend Call (core_services.dart:675):**

```dart
final response = await _dio.post(
  '${AppConstants.exitEndpoint}/emergency',  // ❌ WRONG URL
  data: {
    'user_id': userId,       // ❌ Not needed (comes from auth)
    'reason': reason,        // ✅ OK
    'emergency': true        // ❌ Not expected by backend
  }
);
```

**Backend Reality:**

- No `/emergency` endpoint exists in urls.py
- Only `/exit/process/` endpoint available
- Emergency flag should be in reason field

---

## 🔧 **REQUIRED FIXES**

### Fix 1: Core Services Parameter Names

**File: `core_services.dart`**

```dart
// BEFORE (Lines 287-295):
final success = await coreServices.markQRAttendance(
  userId: _userId!,
  sessionId: sessionId,
  faceVerified: true,
);

// AFTER:
final success = await coreServices.markQRAttendance(
  user: _userId!,              // ✅ Fixed field name
  session: sessionId,          // ✅ Fixed field name
  face_verified: true,         // ✅ Fixed field name
  method: 'qr',               // ✅ Added missing field
);
```

### Fix 2: BLE Attendance Parameters

**File: `core_services.dart`**

```dart
// BEFORE (Lines 601-607):
await coreServices.markAttendance(
  userId: _userId!,
  sessionId: sessionId,
  faceVerified: true,
  bleDeviceId: device.id,
  bleRssi: bleRssi,
);

// AFTER:
await coreServices.markAttendance(
  user: _userId!,              // ✅ Fixed
  session: sessionId,          // ✅ Fixed
  face_verified: true,         // ✅ Fixed
  ble_device_id: device.id,    // ✅ Fixed
  ble_rssi: bleRssi,          // ✅ Fixed
  method: 'ble',              // ✅ Added
);
```

### Fix 3: Exit Processing Parameters

**File: `core_services.dart`**

```dart
// BEFORE:
final response = await _dio.post(
  AppConstants.exitEndpoint,
  data: {'user_id': userId, 'face_id': faceId, 'qr_data': qrData},
);

// AFTER:
final response = await _dio.post(
  '${AppConstants.exitEndpoint}process/',  // ✅ Fixed URL
  data: {
    'qr_data': qrData,         // ✅ OK
    'face_image': faceId,      // ✅ Fixed field name
    // user comes from authentication
  },
);
```

### Fix 4: Emergency Exit Endpoint

**File: `core_services.dart`**

```dart
// BEFORE:
final response = await _dio.post(
  '${AppConstants.exitEndpoint}/emergency',
  data: {'user_id': userId, 'reason': reason, 'emergency': true},
);

// AFTER:
final response = await _dio.post(
  '${AppConstants.exitEndpoint}process/',  // ✅ Use existing endpoint
  data: {
    'qr_data': emergencyQrData,            // ✅ Generate emergency QR
    'face_image': faceImage,               // ✅ Fixed field name
    // Reason embedded in QR data
  },
);
```

---

## 📋 **ENDPOINT VALIDATION**

### ✅ **Correct Endpoints (from urls.py):**

- `/api/attendance/` (POST) - For attendance marking
- `/api/exit/process/` (POST) - For exit processing
- `/api/sessions/` (POST/GET) - For session management
- `/api/leave/` (POST/GET) - For leave requests

### ❌ **Invalid Endpoints Used by Frontend:**

- `/api/exit/emergency` - Does not exist
- Direct session creation without proper parameters

---

## 🎯 **ACTION ITEMS**

1. **IMMEDIATE** - Fix parameter names in core_services.dart
2. **IMMEDIATE** - Update exit endpoint URLs
3. **HIGH** - Add proper error handling for parameter mismatches
4. **MEDIUM** - Create emergency exit endpoint on backend OR use existing with proper data
5. **LOW** - Add parameter validation on frontend before API calls

---

## 📊 **IMPACT ASSESSMENT**

**🔴 HIGH IMPACT:**

- Attendance marking completely broken (wrong field names)
- Exit processing failing (wrong endpoint + parameters)

**🟡 MEDIUM IMPACT:**

- Emergency exits not working (wrong endpoint)
- Data validation errors in backend

**🟢 LOW IMPACT:**

- Minor inconsistencies in response formatting
