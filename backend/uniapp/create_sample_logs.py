from users.models import SystemLog, User
from django.utils import timezone
import datetime

# Get or create a test user (admin)
admin_user, created = User.objects.get_or_create(
    username='admin_test',
    defaults={
        'role': 'admin',
        'is_staff': True,
        'is_superuser': True,
    }
)

# Create sample system logs
sample_logs = [
    {
        'log_type': 'system',
        'event': 'System startup',
        'user': admin_user,
        'details': 'SALMS system started successfully'
    },
    {
        'log_type': 'security',
        'event': 'Failed login attempt',
        'user': None,
        'details': 'Multiple failed login attempts from IP 192.168.1.100'
    },
    {
        'log_type': 'attendance',
        'event': 'Attendance marked',
        'user': admin_user,
        'details': 'Face recognition verification successful'
    },
    {
        'log_type': 'exit',
        'event': 'Student exit',
        'user': admin_user,
        'details': 'QR code scan successful for emergency exit'
    },
    {
        'log_type': 'system',
        'event': 'Database backup',
        'user': admin_user,
        'details': 'Automated database backup completed'
    },
]

# Create the logs
for log_data in sample_logs:
    SystemLog.objects.create(**log_data)

print(f"Created {len(sample_logs)} sample system logs")
print(f"Total system logs in database: {SystemLog.objects.count()}")
