from django.conf import settings
from pyfcm import FCMNotification
from .models import User, LeaveRequest, SystemLog

push_service = FCMNotification(api_key=settings.FCM_API_KEY)

def notify_admin_new_leave(leave_request_id):
    try:
        leave_request = LeaveRequest.objects.get(id=leave_request_id)
        admins = User.objects.filter(role='admin')
        
        message = {
            'title': 'New Leave Request',
            'body': f'Student {leave_request.user.username} submitted a leave request',
            'type': 'new_leave'
        }
        
        for admin in admins:
            if admin.fcm_token:
                push_service.notify_single_device(
                    registration_id=admin.fcm_token,
                    data_message=message
                )
                SystemLog.objects.create(
                    log_type='system',
                    event='Admin notified',
                    details=f"Leave request {leave_request_id} notification sent"
                )
    except Exception as e:
        SystemLog.objects.create(
            log_type='system',
            event='Notification failed',
            details=f"Error: {str(e)}"
        )

def notify_leave_status_update(user_id, status, comments):
    try:
        user = User.objects.get(id=user_id)
        if not user.fcm_token:
            return
            
        message = {
            'title': 'Leave Request Update',
            'body': f'Your leave request has been {status}',
            'type': 'leave_status_update',
            'status': status,
            'comments': comments or ''
        }
        
        push_service.notify_single_device(
            registration_id=user.fcm_token,
            data_message=message
        )
    except Exception as e:
        SystemLog.objects.create(
            log_type='system',
            event='Notification failed',
            details=f"Error: {str(e)}"
        )

def cleanup_expired_leave():
    from django.utils import timezone
    expired_leave = LeaveRequest.objects.filter(
        end_date__lt=timezone.now().date(),
        status='pending'
    )
    
    for leave in expired_leave:
        leave.status = 'denied'
        leave.review_comments = 'Automatically denied (expired)'
        leave.save()
        
        SystemLog.objects.create(
            log_type='system',
            event='Leave auto-denied',
            details=f"Leave ID: {leave.id} automatically denied"
        )