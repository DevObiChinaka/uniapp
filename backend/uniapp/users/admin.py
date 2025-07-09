from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog

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
    list_display = ('lecturer', 'program', 'start_time', 'end_time', 'total_sessions', 'pass_threshold', 'is_active')
    list_filter = ('program', 'start_time')
    search_fields = ('lecturer__username', 'program')
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