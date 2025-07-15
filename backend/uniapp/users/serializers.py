from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    campus_tag = serializers.ChoiceField(choices=[('on-campus', 'On Campus'), ('off-campus', 'Off Campus')], required=False)
    program = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = [
            'university_id', 'username', 'first_name', 'last_name', 'email',
            'password', 'role', 'campus_tag', 'program'
        ]

    def create(self, validated_data):
        password = validated_data.pop('password')
        if 'username' not in validated_data or not validated_data['username']:
            validated_data['username'] = validated_data.get('university_id', None)
        user = User(**validated_data)
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
        elif role == 'admin':
            user_data['username'] = user.username
            user_data['is_superadmin'] = getattr(user, 'is_superadmin', False)

        data.update(user_data)
        return data


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password = serializers.CharField(write_only=True)
    role = serializers.ChoiceField(choices=['student', 'admin'])



class UserSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    name = serializers.SerializerMethodField()
    face_id = serializers.SerializerMethodField()
    is_on_campus = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'name', 'role', 'face_id', 'program', 'campus_tag', 'is_on_campus']
    
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
    class Meta:
        model = Session
        fields = '__all__'

class AttendanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Attendance
        fields = '__all__'

class LeaveRequestSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    reviewer_id = serializers.SerializerMethodField()
    
    class Meta:
        model = LeaveRequest
        fields = ['id', 'user_id', 'start_date', 'end_date', 'reason', 'status', 'submitted_at', 'reviewed_at', 'reviewer_id', 'review_comments']
    
    def get_id(self, obj):
        return str(obj.id)
    
    def get_user_id(self, obj):
        return str(obj.user.id) if obj.user else None
    
    def get_reviewer_id(self, obj):
        return str(obj.reviewer.id) if obj.reviewer else None

class SystemLogSerializer(serializers.ModelSerializer):
    id = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    type = serializers.CharField(source='log_type')
    
    class Meta:
        model = SystemLog
        fields = ['id', 'type', 'event', 'timestamp', 'user_id', 'details']
    
    def get_id(self, obj):
        return str(obj.id)
    
    def get_user_id(self, obj):
        return str(obj.user.id) if obj.user else None

class ExitLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ExitLog
        fields = '__all__'

class SystemLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemLog
        fields = '__all__'

class FCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['fcm_token']