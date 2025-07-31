from django.db import models
from django.core.exceptions import ValidationError
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.utils import timezone

class Program(models.Model):
    PROGRAM_CHOICES = [
        ('Software Engineering', 'Software Engineering'),
        ('Cyber Security', 'Cyber Security'),
        ('Computer Science', 'Computer Science'),
        ('Forensic Science', 'Forensic Science'),
        ('Applied Physics', 'Applied Physics'),
        ('Environmental and Conservative Biology', 'Environmental and Conservative Biology'),
    ]
    name = models.CharField(max_length=100, choices=PROGRAM_CHOICES, unique=True)

    def __str__(self):
        return self.name

class CustomUserManager(BaseUserManager):
    def create_user(self, university_id=None, username=None, password=None, **extra_fields):
        role = extra_fields.get('role')

        if role == 'student':
            if not university_id:
                raise ValueError("Students must have a university ID")
            username = None
        elif role == 'admin':
            if not username:
                raise ValueError("Admins must have a username")
            university_id = None
        elif role == 'lecturer':
            if not username:
                raise ValueError("Lecturers must have a username")
            university_id = None
        elif role == 'security':
            if not username:
                raise ValueError("Security staff must have a username")
            university_id = None
        else:
            raise ValueError("User role must be student, admin, lecturer, or security")

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
    email = models.EmailField(unique=True, null=True, blank=True)
    profile_image = models.ImageField(upload_to='profiles/', null=True, blank=True)
    profile_picture_url = models.URLField(null=True, blank=True)  # For Firebase URLs
    fingerprint_hash = models.TextField(null=True, blank=True)
    face_hash = models.TextField(null=True, blank=True)
    face_id = models.CharField(max_length=100, blank=True, null=True)
    campus_tag = models.CharField(max_length=20, choices=(('on-campus', 'On Campus'), ('off-campus', 'Off Campus')), default='on-campus', null=True, blank=True)
    program = models.ForeignKey(Program, on_delete=models.SET_NULL, blank=True, null=True)
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
        elif self.role in ['admin', 'lecturer', 'security']:
            if not self.username:
                raise ValidationError(f"{self.role.capitalize()}s must have a username.")
            self.university_id = None
        else:
            raise ValidationError("Role must be student, admin, lecturer, or security.")


# --- Geofence model for session-based geofencing ---
class Geofence(models.Model):
    label = models.CharField(max_length=100, blank=True, null=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    radius = models.FloatField(help_text="Radius in meters")

    def __str__(self):
        return self.label or f"Geofence ({self.latitude}, {self.longitude})"


# Updated Session model with geofence relation
class Session(models.Model):
    lecturer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sessions')
    program = models.ForeignKey(Program, on_delete=models.CASCADE)
    start_time = models.DateTimeField(default=timezone.now)
    end_time = models.DateTimeField(blank=True, null=True)
    total_sessions = models.IntegerField(default=10)
    pass_threshold = models.FloatField(default=0.7)
    is_active = models.BooleanField(default=False)
    current_period = models.IntegerField(default=0, help_text="Current attendance period/cycle.")
    geofence = models.OneToOneField(Geofence, on_delete=models.SET_NULL, blank=True, null=True, related_name='session')

    def __str__(self):
        return f"Session {self.id} ({self.program}) - Active: {self.is_active}"

class Attendance(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    session = models.ForeignKey(Session, on_delete=models.CASCADE)
    timestamp = models.DateTimeField(auto_now_add=True)
    method = models.CharField(max_length=50)
    face_verified = models.BooleanField(default=False)
    period = models.IntegerField(default=1, help_text="Attendance period/cycle for this record.")
    flagged = models.BooleanField(default=False)
    flag_reason = models.TextField(blank=True, null=True)
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