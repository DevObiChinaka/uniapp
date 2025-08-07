# Backend Leave Request Endpoint Testing

## API Endpoint: `/api/leave/`

### Expected Frontend Data Format

The frontend sends data in this format:

```json
{
  "start_date": "2025-08-07T00:00:00.000Z",
  "end_date": "2025-08-10T00:00:00.000Z",
  "reason": "Medical appointment and family emergency"
}
```

### Backend Changes Made

1. **New Serializer**: Created `LeaveRequestCreateSerializer` to handle input data

   - Only accepts: `start_date`, `end_date`, `reason`
   - Validates that end_date >= start_date
   - User is automatically assigned from request.user

2. **Updated ViewSet**: Modified `LeaveRequestViewSet`

   - Uses `LeaveRequestCreateSerializer` for creation
   - Uses `LeaveRequestSerializer` for responses
   - Added debug logging
   - Made async_task optional to prevent failures

3. **Response Format**: Backend returns complete leave request data:

```json
{
  "id": "123",
  "user_id": "456",
  "start_date": "2025-08-07",
  "end_date": "2025-08-10",
  "reason": "Medical appointment and family emergency",
  "status": "pending",
  "submitted_at": "2025-08-06T22:21:44.123456Z",
  "reviewed_at": null,
  "reviewer_id": null,
  "review_comments": null,
  "student_name": "John Doe",
  "student_university_id": "UNI123456"
}
```

### Testing

To test the endpoint manually:

```bash
curl -X POST http://localhost:8000/api/leave/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "start_date": "2025-08-07T00:00:00.000Z",
    "end_date": "2025-08-10T00:00:00.000Z",
    "reason": "Test leave request"
  }'
```

The backend should now properly handle the frontend data format and return appropriate responses.
