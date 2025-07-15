from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    email = serializers.EmailField(required=False, allow_blank=True)
    campus_tag = serializers.ChoiceField(choices=[('on-campus', 'On Campus'), ('off-campus', 'Off Campus')], required=False, allow_null=True)
    program = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = User
        fields = [
            'university_id', 'username', 'first_name', 'last_name', 'email',
            'password', 'role', 'campus_tag', 'program'
        ]

    def validate(self, attrs):
        role = attrs.get('role')
        
        # Role-based validation
        if role == 'admin':
            # Admin users don't need campus_tag or program
            if 'campus_tag' not in attrs or attrs['campus_tag'] is None:
                attrs['campus_tag'] = 'on-campus'  # Set default for admin
            if 'program' not in attrs or attrs['program'] is None:
                attrs['program'] = None  # Allow None for admin
        elif role == 'student':
            # Students should have campus_tag and program
            if not attrs.get('campus_tag'):
                attrs['campus_tag'] = 'on-campus'  # Default
        
        return attrs

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
    class Meta:
        model = User
        fields = ['id', 'username', 'role', 'face_id', 'campus_tag', 'program']

class SessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Session
        fields = '__all__'

class AttendanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Attendance
        fields = '__all__'

class LeaveRequestSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveRequest
        fields = '__all__'

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