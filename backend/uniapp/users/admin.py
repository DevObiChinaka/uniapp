from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog
from .models import Program, Course

# Proxy models for admin use only (not in models.py, not migrated)
admin.site.register(Program)

@admin.register(Course)
class CourseAdmin(admin.ModelAdmin):
    filter_horizontal = ('programs',)
    list_display = ('code', 'name', 'level',)

# Proxy models for admin use only (not in models.py, not migrated)
class StudentUser(User):
    class Meta:
        proxy = True
        verbose_name = "Student"
        verbose_name_plural = "Students"

class AdminUser(User):
    class Meta:
        proxy = True
        verbose_name = "Admin"
        verbose_name_plural = "Admins"

class LecturerUser(User):
    class Meta:
        proxy = True
        verbose_name = "Lecturer"
        verbose_name_plural = "Lecturers"

class SecurityUser(User):
    class Meta:
        proxy = True
        verbose_name = "Security"
        verbose_name_plural = "Security Staff"


@admin.register(StudentUser)
class StudentUserAdmin(admin.ModelAdmin):
    list_display = ['university_id', 'first_name', 'last_name', 'fingerprint_hash', 'face_hash']
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(role='student')

@admin.register(AdminUser)
class AdminUserAdmin(admin.ModelAdmin):
    list_display = ['username', 'first_name', 'last_name', 'fingerprint_hash', 'face_hash']
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(role='admin')

@admin.register(LecturerUser)
class LecturerUserAdmin(admin.ModelAdmin):
    list_display = ['username', 'first_name', 'last_name', 'fingerprint_hash', 'face_hash']
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(role='lecturer')

@admin.register(SecurityUser)
class SecurityUserAdmin(admin.ModelAdmin):
    list_display = ['username', 'first_name', 'last_name', 'fingerprint_hash', 'face_hash']
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        return qs.filter(role='security')

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'first_name', 'last_name', 'role', 'campus_tag', 'program')
    list_filter = ('role', 'campus_tag', 'is_staff', 'is_superuser')
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        ('Personal Info', {'fields': ('first_name', 'last_name', 'email', 'university_id', 'profile_image', 'fingerprint_hash', 'face_hash')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
        ('Custom Fields', {'fields': ('role', 'face_id', 'campus_tag', 'program', 'fcm_token')}),
    )
    search_fields = ('username', 'email', 'first_name', 'last_name', 'university_id')

@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = (
        'lecturer', 'course', 'level', 'start_time', 'end_time', 'total_sessions', 'pass_threshold',
        'get_latitude', 'get_longitude', 'get_radius', 'is_active'
    )
    list_filter = ('start_time', 'course', 'level')
    search_fields = ('lecturer__username', 'course__name')

    def get_latitude(self, obj):
        return obj.geofence.latitude if obj.geofence else None
    get_latitude.short_description = 'Latitude'

    def get_longitude(self, obj):
        return obj.geofence.longitude if obj.geofence else None
    get_longitude.short_description = 'Longitude'

    def get_radius(self, obj):
        return obj.geofence.radius if obj.geofence else None
    get_radius.short_description = 'Range (m)'

    @admin.display(boolean=True, description='Active?')
    def is_active(self, obj):
        return obj.end_time is None

@admin.register(Attendance)
class AttendanceAdmin(admin.ModelAdmin):
    list_display = ('user', 'session', 'timestamp', 'method', 'face_verified', 'ble_device_id')
    list_filter = ('method', 'face_verified', 'timestamp')
    search_fields = ('user__username', 'session__program')

@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ('user', 'start_date', 'end_date', 'status', 'submitted_at', 'reviewed_at', 'reviewer')
    list_filter = ('status', 'start_date', 'end_date')
    search_fields = ('user__username', 'reason')
    raw_id_fields = ('reviewer',)

@admin.register(ExitLog)
class ExitLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'timestamp', 'allowed', 'face_verified', 'reason_short')
    list_filter = ('allowed', 'face_verified', 'timestamp')
    search_fields = ('user__username', 'qr_data')
    @admin.display(description='Reason')
    def reason_short(self, obj):
        return obj.reason[:50] + '...' if len(obj.reason) > 50 else obj.reason

@admin.register(SystemLog)
class SystemLogAdmin(admin.ModelAdmin):
    list_display = ('log_type', 'event_short', 'timestamp', 'user')
    list_filter = ('log_type', 'timestamp')
    search_fields = ('event', 'details')
    @admin.display(description='Event')
    def event_short(self, obj):
        return obj.event[:50] + '...' if len(obj.event) > 50 else obj.event