from django.db import models
from django.core.exceptions import ValidationError
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.utils import timezone

class CustomUserManager(BaseUserManager):
    def create_user(self, university_id=None, username=None, password=None, **extra_fields):
        role = extra_fields.get('role')

        if role == 'student':
            if not university_id:
                raise ValueError("Students must have a university ID")
            username = None  # ensure username is empty for students
        elif role == 'admin':
            if not username:
                raise ValueError("Admins must have a username")
            university_id = None  # ensure university_id is empty for admins
        else:
            raise ValueError("User role must be either 'student' or 'admin'")

        user = self.model(
            university_id=university_id,
            username=username,
            **extra_fields
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, university_id=None, username=None, password=None, **extra_fields):
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('role', 'admin')

        if not username:
            raise ValueError("Superuser must have a username")

        return self.create_user(university_id=university_id, username=username, password=password, **extra_fields)

class User(AbstractUser):
    ROLE_CHOICES = (
        ('student', 'Student'),
        ('lecturer', 'Lecturer'),
        ('security', 'Security'),
        ('admin', 'Admin'),
    )
    university_id = models.CharField(max_length=20, unique=True, null=True, blank=True)
    profile_image = models.ImageField(upload_to='profiles/', null=True, blank=True)
    fingerprint_hash = models.TextField(null=True, blank=True)
    face_hash = models.TextField(null=True, blank=True)
    face_id = models.CharField(max_length=100, blank=True, null=True)
    campus_tag = models.CharField(max_length=20, choices=(('on-campus', 'On Campus'), ('off-campus', 'Off Campus')), default='on-campus', null=True, blank=True)
    program = models.CharField(max_length=100, blank=True, null=True)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)

    objects = CustomUserManager()

    def __str__(self):
        return f"{self.get_identifier()} ({self.role})"

    def get_identifier(self):
        # Returns university_id for students, username for admins
        return self.university_id if self.role == 'student' else self.username

    def clean(self):
        # Validate that only one of university_id or username is set depending on role
        if self.role == 'student':
            if not self.university_id:
                raise ValidationError("Students must have a university ID.")
            self.username = None
        elif self.role == 'admin':
            if not self.username:
                raise ValidationError("Admins must have a username.")
            self.university_id = None
        else:
            raise ValidationError("Role must be either 'student' or 'admin'.")

class Session(models.Model):
    lecturer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sessions')
    program = models.CharField(max_length=100)
    start_time = models.DateTimeField(default=timezone.now)
    end_time = models.DateTimeField(blank=True, null=True)
    total_sessions = models.IntegerField(default=10)
    pass_threshold = models.FloatField(default=0.7)

    @property
    def is_active(self):
        return self.end_time is None

class Attendance(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    method = models.CharField(max_length=50)
    face_verified = models.BooleanField(default=False)
    ble_device_id = models.CharField(max_length=100, blank=True, null=True)
    ble_rssi = models.IntegerField(blank=True, null=True)

class LeaveRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('denied', 'Denied'),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    start_date = models.DateField()
    end_date = models.DateField()
    reason = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    submitted_at = models.DateTimeField(auto_now_add=True)
    reviewed_at = models.DateTimeField(blank=True, null=True)
    reviewer = models.ForeignKey(User, on_delete=models.SET_NULL, blank=True, null=True, related_name='reviewed_leave_requests')
    review_comments = models.TextField(blank=True, null=True)

class ExitLog(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    allowed = models.BooleanField(default=False)
    reason = models.TextField()
    qr_data = models.TextField()
    face_verified = models.BooleanField(default=False)

class SystemLog(models.Model):
    LOG_TYPE_CHOICES = (
        ('attendance', 'Attendance'),
        ('exit', 'Exit'),
        ('security', 'Security'),
        ('system', 'System'),
    )
    log_type = models.CharField(max_length=20, choices=LOG_TYPE_CHOICES)
    event = models.CharField(max_length=255)
    timestamp = models.DateTimeField(auto_now_add=True)
    user = models.ForeignKey(User, on_delete=models.SET_NULL, blank=True, null=True)
    details = models.TextField(blank=True, null=True)