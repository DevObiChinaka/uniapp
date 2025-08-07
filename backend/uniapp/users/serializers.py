from .models import Geofence
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog, Program, Course

# --- Geofence Serializer ---
class GeofenceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Geofence
        fields = ['id', 'label', 'latitude', 'longitude', 'radius']

# --- Program Serializer ---
class ProgramSerializer(serializers.ModelSerializer):
    class Meta:
        model = Program
        fields = ['id', 'name']

# --- Course Serializer ---

class CourseSerializer(serializers.ModelSerializer):
    programs = ProgramSerializer(many=True, read_only=True)
    program_ids = serializers.PrimaryKeyRelatedField(queryset=Program.objects.all(), many=True, write_only=True, source='programs')
    class Meta:
        model = Course
        fields = ['id', 'code', 'name', 'level', 'programs', 'program_ids']


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    campus_tag = serializers.ChoiceField(choices=[('on-campus', 'On Campus'), ('off-campus', 'Off Campus')], required=False, allow_null=True)
    program = serializers.PrimaryKeyRelatedField(queryset=Program.objects.all(), required=False, allow_null=True)
    level = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    
    def validate_role(self, value):
        """Restrict frontend registration to only student and lecturer roles"""
        if value not in ['student', 'lecturer']:
            raise serializers.ValidationError('Only student and lecturer roles can be registered from the frontend. Admin and security users must be created by administrators.')
        return value
    
    def validate(self, attrs):
        role = attrs.get('role')
        if role == 'student':
            if not attrs.get('campus_tag'):
                raise serializers.ValidationError({'campus_tag': 'This field is required for students.'})
            if not attrs.get('program'):
                raise serializers.ValidationError({'program': 'This field is required for students.'})
            if not attrs.get('level'):
                raise serializers.ValidationError({'level': 'This field is required for students.'})
        else:
            attrs['campus_tag'] = None
            attrs['program'] = None
            attrs['level'] = None
        return attrs

    class Meta:
        model = User
        fields = [
            'university_id', 'username', 'first_name', 'last_name', 'email',
            'password', 'role', 'campus_tag', 'program', 'level'
        ]

    def create(self, validated_data):
        password = validated_data.pop('password')
        if 'username' not in validated_data or not validated_data['username']:
            validated_data['username'] = validated_data.get('university_id', None)
        level = validated_data.pop('level', None)
        user = User(**validated_data)
        if level:
            user.level = level
        user.set_password(password)
        user.save()
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)

        user = self.user
        role = user.role

        user_data = {
            "first_name": user.first_name,
            "last_name": user.last_name,
            "role": role,
        }

        if role == 'student':
            user_data['university_id'] = user.university_id
        elif role in ['admin', 'security', 'lecturer']:
            user_data['username'] = user.username
            if role == 'admin':
                user_data['is_superadmin'] = getattr(user, 'is_superadmin', False)

        data.update(user_data)
        return data


class AdminUserCreateSerializer(serializers.ModelSerializer):
    """
    Serializer for creating admin and security users via admin endpoint.
    Only for backend admin use - not exposed to frontend registration.
    """
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=True)
    
    def validate_role(self, value):
        """Only allow admin and security roles for this serializer"""
        if value not in ['admin', 'security']:
            raise serializers.ValidationError('This endpoint only supports admin and security roles.')
        return value

    class Meta:
        model = User
        fields = ['username', 'first_name', 'last_name', 'email', 'password', 'role']

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data['university_id'] = ''  # Empty for admin/security users
        validated_data['campus_tag'] = None
        validated_data['program'] = None
        validated_data['level'] = None
        
        user = User.objects.create_user(password=password, **validated_data)
        return user


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password = serializers.CharField(write_only=True)
    role = serializers.ChoiceField(choices=['student', 'admin', 'lecturer', 'security'])



class UserSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()
    face_id = serializers.SerializerMethodField()
    is_on_campus = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id',                # PK (integer)
            'name',
            'role',
            'face_id',
            'program',
            'campus_tag',
            'is_on_campus',
            'university_id',     # university ID string
            'email',
            'username',
            'first_name',
            'last_name',
            'profile_picture_url',
            'level',             # Add level field
            'last_activity',     # Add last activity field
        ]
    
    def get_id(self, obj):
        """Convert id to string for frontend compatibility"""
        return str(obj.id)
    
    def get_name(self, obj):
        """Combine first_name and last_name for the frontend"""
        return f"{obj.first_name} {obj.last_name}".strip()
    
    def get_face_id(self, obj):
        """Map face_hash to face_id for frontend compatibility"""
        return obj.face_hash
    
    def get_is_on_campus(self, obj):
        """Convert campus_tag to boolean for frontend compatibility"""
        return obj.campus_tag == 'on-campus' if obj.campus_tag else False

class SessionSerializer(serializers.ModelSerializer):
    lecturer = serializers.SlugRelatedField(
        slug_field='username', queryset=User.objects.all(), required=False
    )

    # Removed programs field; Session model does not have 'programs' anymore
    course = CourseSerializer(read_only=True)
    course_id = serializers.PrimaryKeyRelatedField(queryset=Course.objects.all(), source='course', write_only=True)
    level = serializers.CharField()
    is_active = serializers.BooleanField(required=False)
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    radius = serializers.FloatField(required=False, allow_null=True)

    def validate(self, attrs):
        programs = attrs.get('programs', [])
        course = attrs.get('course')
        level = attrs.get('level')
        if course and programs:
            for program in programs:
                if not course.programs.filter(id=program.id).exists():
                    raise serializers.ValidationError({'course_id': f'Selected course is not linked to program {program.id}.'})
            if level and course.level != level:
                raise serializers.ValidationError({'level': 'Selected course does not match the selected level.'})
        return attrs

    id = serializers.SerializerMethodField()
    lecturer_username = serializers.SerializerMethodField()
    geofence = GeofenceSerializer(read_only=True)
    geofence_id = serializers.PrimaryKeyRelatedField(
        queryset=Geofence.objects.all(), source='geofence', write_only=True, required=False, allow_null=True
    )

    class Meta:
        model = Session
        fields = [
            'id', 'lecturer', 'lecturer_username', 'course', 'course_id', 'level',
            'start_time', 'end_time', 'total_sessions', 'pass_threshold', 'is_active',
            'current_period', 'geofence', 'geofence_id', 'latitude', 'longitude', 'radius'
        ]

    def get_id(self, obj):
        return str(obj.id)

    def get_lecturer_username(self, obj):
        username = getattr(obj.lecturer, 'username', None)
        return str(username) if username is not None else ''

    def create(self, validated_data):
        latitude = validated_data.pop('latitude', None)
        longitude = validated_data.pop('longitude', None)
        radius = validated_data.pop('radius', None)
        session = Session.objects.create(**validated_data)
        if latitude is not None and longitude is not None and radius is not None:
            session.latitude = latitude
            session.longitude = longitude
            session.radius = radius
            session.save()
        return session

class AttendanceSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    session_id = serializers.IntegerField(source='session.id', read_only=True)
    
    class Meta:
        model = Attendance
        fields = ['id', 'user_id', 'session_id', 'timestamp', 'method', 'face_verified', 'period', 'ble_device_id', 'ble_rssi']

class LeaveRequestSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField(read_only=True)
    user_id = serializers.SerializerMethodField(read_only=True)
    reviewer_id = serializers.SerializerMethodField(read_only=True)
    student_name = serializers.SerializerMethodField(read_only=True)
    student_university_id = serializers.SerializerMethodField(read_only=True)
    status = serializers.CharField(read_only=True)
    submitted_at = serializers.DateTimeField(read_only=True)
    reviewed_at = serializers.DateTimeField(read_only=True)
    review_comments = serializers.CharField(read_only=True)
    
    class Meta:
        model = LeaveRequest
        fields = ['id', 'user_id', 'start_date', 'end_date', 'reason', 'status', 'submitted_at', 'reviewed_at', 'reviewer_id', 'review_comments', 'student_name', 'student_university_id']
        read_only_fields = ['id', 'user_id', 'status', 'submitted_at', 'reviewed_at', 'reviewer_id', 'review_comments', 'student_name', 'student_university_id']
    
    def get_id(self, obj):
        return str(obj.id)
    
    def get_user_id(self, obj):
        return str(obj.user.id) if obj.user else None
    
    def get_reviewer_id(self, obj):
        return str(obj.reviewer.id) if obj.reviewer else None
    
    def get_student_name(self, obj):
        if obj.user:
            return f"{obj.user.first_name} {obj.user.last_name}".strip()
        return "Unknown Student"
    
    def get_student_university_id(self, obj):
        return obj.user.university_id if obj.user else "N/A"


class LeaveRequestCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating leave requests - handles frontend data format"""
    
    # Use DateTimeField to handle ISO format, then convert to date
    start_date = serializers.DateTimeField()
    end_date = serializers.DateTimeField()
    
    class Meta:
        model = LeaveRequest
        fields = ['start_date', 'end_date', 'reason']
        
    def validate(self, attrs):
        start_datetime = attrs.get('start_date')
        end_datetime = attrs.get('end_date')
        
        if start_datetime and end_datetime:
            # Convert datetime to date for comparison
            start_date = start_datetime.date()
            end_date = end_datetime.date()
            
            if end_date < start_date:
                raise serializers.ValidationError("End date cannot be before start date")
            
            # Store the date parts in attrs for saving
            attrs['start_date'] = start_date
            attrs['end_date'] = end_date
                
        return attrs

class SystemLogSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    user_name = serializers.SerializerMethodField()
    type = serializers.CharField(source='log_type')
    time_ago = serializers.SerializerMethodField()
    
    class Meta:
        model = SystemLog
        fields = ['id', 'type', 'event', 'timestamp', 'user_id', 'user_name', 'details', 'time_ago']
    
    def get_id(self, obj):
        return str(obj.id)
    
    def get_user_id(self, obj):
        return str(obj.user.id) if obj.user else None
    
    def get_user_name(self, obj):
        if obj.user:
            return f"{obj.user.first_name} {obj.user.last_name}".strip() or obj.user.username or str(obj.user.id)
        return "System"
    
    def get_time_ago(self, obj):
        from django.utils.timesince import timesince
        return f"{timesince(obj.timestamp)} ago"

class ExitLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExitLog
        fields = '__all__'

class FCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['fcm_token']

class SessionSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = Session
        fields = ['id', 'is_active', 'current_period', 'total_sessions', 'start_time', 'end_time']

class CourseWithSessionsSerializer(serializers.ModelSerializer):
    sessions = serializers.SerializerMethodField()
    programs = serializers.PrimaryKeyRelatedField(many=True, read_only=True)

    class Meta:
        model = Course
        fields = ['id', 'code', 'name', 'level', 'programs', 'sessions']

    def get_sessions(self, obj):
        # Context should provide 'lecturer_sessions' queryset
        lecturer_sessions = self.context.get('lecturer_sessions', Session.objects.none())
        course_sessions = lecturer_sessions.filter(course=obj)
        return SessionSummarySerializer(course_sessions, many=True).data

class AttendanceRecordSummarySerializer(serializers.ModelSerializer):
    user_id = serializers.SerializerMethodField()
    session_id = serializers.SerializerMethodField()
    
    class Meta:
        model = Attendance
        fields = ['id', 'user_id', 'session_id', 'period', 'timestamp', 'method']
    
    def get_user_id(self, obj):
        return str(obj.user.id) if obj.user else None
    
    def get_session_id(self, obj):
        return str(obj.session.id) if obj.session else None