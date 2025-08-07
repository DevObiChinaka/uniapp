# Admin and Security User Management

## Overview

Admin and security user accounts cannot be created through the frontend registration form. These privileged accounts must be created by system administrators using one of the methods below.

## Frontend Changes

- The registration screen now only allows `student` and `lecturer` role selection
- Admin and security roles have been removed from the frontend dropdown
- Users see a note: "Admin and Security accounts are created by system administrators"

## Backend Restrictions

- The `UserRegistrationSerializer` now validates that only `student` and `lecturer` roles can be registered via the frontend
- Attempting to register admin/security users via the public registration endpoint will return a validation error

## Creating Admin/Security Users

### Method 1: Django Management Command

Use the custom management command to create admin or security users:

```bash
# Navigate to the Django project directory
cd backend/uniapp

# Create an admin user
python manage.py create_admin_user \
    --username admin_john \
    --email john.admin@university.edu \
    --first_name John \
    --last_name Doe \
    --password SecurePassword123! \
    --role admin

# Create a security user
python manage.py create_admin_user \
    --username security_jane \
    --email jane.security@university.edu \
    --first_name Jane \
    --last_name Smith \
    --password SecurePassword123! \
    --role security
```

### Method 2: Admin API Endpoint

Use the protected API endpoint (requires existing admin authentication):

**Endpoint:** `POST /api/admin/users/create/`

**Headers:**

```
Authorization: Bearer <admin_jwt_token>
Content-Type: application/json
```

**Request Body:**

```json
{
  "username": "security_mike",
  "email": "mike.security@university.edu",
  "first_name": "Mike",
  "last_name": "Johnson",
  "password": "SecurePassword123!",
  "role": "security"
}
```

**Response (Success):**

```json
{
  "message": "Successfully created security user",
  "user": {
    "id": 123,
    "username": "security_mike",
    "email": "mike.security@university.edu",
    "first_name": "Mike",
    "last_name": "Johnson",
    "role": "security",
    "created_at": "2025-08-07T04:22:00Z"
  },
  "created_by": "admin_john"
}
```

### Method 3: Django Admin Interface

1. Access Django admin at `http://127.0.0.1:8000/admin/`
2. Login with a superuser account
3. Navigate to Users section
4. Create new user with appropriate role

## Security Features

- **Authentication Required:** Admin API endpoint requires valid JWT token
- **Role Verification:** Only users with `admin` role can create admin/security accounts
- **Audit Logging:** All admin user creation actions are logged in SystemLog
- **Validation:** Usernames and emails must be unique across the system
- **Auto-Assignment:** Admin/security users automatically get:
  - Empty `university_id`
  - `null` campus_tag, program, and level

## Error Handling

The system handles various error cases:

- **Duplicate Username/Email:** Returns 400 with specific error message
- **Invalid Role:** Only 'admin' and 'security' roles accepted for admin endpoints
- **Missing Fields:** All required fields must be provided
- **Permission Denied:** Non-admin users receive 403 Forbidden
- **Validation Errors:** Detailed field-specific error messages

## Best Practices

1. **Strong Passwords:** Use complex passwords for admin/security accounts
2. **Unique Identifiers:** Ensure usernames and emails are unique and professional
3. **Role Assignment:** Only create security accounts for personnel with physical access
4. **Regular Audits:** Review SystemLog entries for user creation activities
5. **Limited Access:** Minimize the number of admin accounts

## Examples

### Creating Initial Admin User (via Management Command)

```bash
python manage.py create_admin_user \
    --username system_admin \
    --email admin@university.edu \
    --first_name System \
    --last_name Administrator \
    --password VerySecurePassword2025! \
    --role admin
```

### Creating Security Personnel (via API)

```bash
curl -X POST http://127.0.0.1:8000/api/admin/users/create/ \
     -H "Authorization: Bearer YOUR_ADMIN_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "username": "gate_security_01",
       "email": "gate1@university.edu",
       "first_name": "Security",
       "last_name": "Officer",
       "password": "SecureGatePass2025!",
       "role": "security"
     }'
```

## Migration Notes

- Existing admin/security users created before this update remain unchanged
- Frontend registration continues to work for students and lecturers
- No database migrations required for this change
