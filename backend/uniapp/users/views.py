from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.utils import timezone
from django_q.tasks import async_task
from azure.cognitiveservices.vision.face import FaceClient
from msrest.authentication import CognitiveServicesCredentials
from django.conf import settings
import hashlib
import hmac
import json

from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog
from .serializers import (
    UserSerializer, SessionSerializer, AttendanceSerializer,
    LeaveRequestSerializer, ExitLogSerializer, SystemLogSerializer,
    UserRegistrationSerializer, FCMTokenSerializer
)

User = get_user_model()

# ====================== ViewSets ======================
class SessionViewSet(viewsets.ModelViewSet):
    queryset = Session.objects.all()
    serializer_class = SessionSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request):
        active_sessions = Session.objects.filter(
            program=request.data['program'],
            end_time__isnull=True
        )
        if active_sessions.exists():
            return Response({
                'error': 'SESSION_CONFLICT',
                'message': 'Cannot start session: Conflict with existing session'
            }, status=status.HTTP_409_CONFLICT)
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(lecturer=request.user)
        
        SystemLog.objects.create(
            log_type='system',
            event='Session started',
            user=request.user,
            details=f"Session {serializer.data['id']} started"
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def end(self, request, pk=None):
        session = self.get_object()
        session.end_time = timezone.now()
        session.save()
        
        SystemLog.objects.create(
            log_type='system',
            event='Session ended',
            user=request.user,
            details=f"Session {session.id} ended"
        )
        return Response({'status': 'session ended'})

class AttendanceViewSet(viewsets.ModelViewSet):
    queryset = Attendance.objects.all()
    serializer_class = AttendanceSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request):
        if request.data.get('ble_rssi', 0) > -70:
            SystemLog.objects.create(
                log_type='attendance',
                event='Weak BLE signal',
                user=request.user,
                details=f"RSSI: {request.data['ble_rssi']}"
            )
            return Response({
                'error': 'BLE_RANGE_ERROR',
                'message': 'Device too far away'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        
        SystemLog.objects.create(
            log_type='attendance',
            event='Attendance marked',
            user=request.user,
            details=f"Method: {request.data.get('method', 'unknown')}"
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

class LeaveRequestViewSet(viewsets.ModelViewSet):
    queryset = LeaveRequest.objects.all()
    serializer_class = LeaveRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'student':
            return LeaveRequest.objects.filter(user=self.request.user)
        return super().get_queryset()

    def create(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user)
        
        async_task('users.tasks.notify_admin_new_leave', serializer.data['id'])
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['patch'])
    def update_status(self, request, pk=None):
        leave_request = self.get_object()
        new_status = request.data.get('status')
        comments = request.data.get('comments')
        
        if new_status not in ['approved', 'denied']:
            return Response({'error': 'INVALID_STATUS'}, status=status.HTTP_400_BAD_REQUEST)
        
        leave_request.status = new_status
        leave_request.reviewed_at = timezone.now()
        leave_request.reviewer = request.user
        leave_request.review_comments = comments
        leave_request.save()
        
        async_task(
            'users.tasks.notify_leave_status_update',
            leave_request.user_id,
            new_status,
            comments
        )
        return Response({'status': 'updated'})

class ExitViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['post'])
    def process(self, request):
        if not self.validate_qr(request.data['qr_data']):
            SystemLog.objects.create(
                log_type='security',
                event='Invalid QR',
                user=request.user,
                details=f"QR: {request.data['qr_data']}"
            )
            return Response({
                'error': 'INVALID_QR',
                'message': 'QR validation failed'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        face_verified = self.verify_face(
            request.user.face_id,
            request.data['face_image']
        )
        if not face_verified:
            SystemLog.objects.create(
                log_type='security',
                event='Face verification failed',
                user=request.user
            )
            return Response({
                'error': 'FACE_VERIFICATION_FAILED',
                'message': 'Face verification failed'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if not self.can_exit_campus(request.user):
            SystemLog.objects.create(
                log_type='security',
                event='Exit denied',
                user=request.user,
                details='Not eligible to exit'
            )
            return Response({
                'allowed': False,
                'message': 'Exit denied: No approved leave request found',
                'student_name': request.user.get_full_name()
            })
        
        ExitLog.objects.create(
            user=request.user,
            allowed=True,
            reason='Approved exit',
            qr_data=request.data['qr_data'],
            face_verified=True
        )
        
        SystemLog.objects.create(
            log_type='exit',
            event='Exit approved',
            user=request.user
        )
        return Response({
            'allowed': True,
            'message': 'Exit approved',
            'student_name': request.user.get_full_name()
        })
    
    def validate_qr(self, qr_data):
        try:
            data = json.loads(qr_data)
            timestamp = data['t']
            received_signature = data['s']
            
            if (timezone.now().timestamp() * 1000) - timestamp > 45000:
                return False
            
            secret = settings.HMAC_SECRET_KEY.encode()
            expected_signature = hmac.new(secret, str(timestamp).encode(), hashlib.sha256).hexdigest()
            return expected_signature == received_signature
        except:
            return False
    
    def verify_face(self, face_id, face_image):
        face_client = FaceClient(
            settings.AZURE_FACE_ENDPOINT,
            CognitiveServicesCredentials(settings.AZURE_FACE_KEY)
        )
        try:
            detected_faces = face_client.face.detect_with_stream(
                face_image,
                detection_model='detection_03',
                recognition_model='recognition_04'
            )
            if not detected_faces:
                return False
                
            verify_result = face_client.face.verify_face_to_face(
                face_id,
                detected_faces[0].face_id
            )
            return verify_result.is_identical
        except:
            return False
    
    def can_exit_campus(self, user):
        if user.campus_tag != 'on-campus':
            return False
        
        today = timezone.now().date()
        return LeaveRequest.objects.filter(
            user=user,
            status='approved',
            start_date__lte=today,
            end_date__gte=today
        ).exists()

class SystemLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SystemLog.objects.all()
    serializer_class = SystemLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role != 'admin':
            return SystemLog.objects.filter(user=self.request.user)
        return super().get_queryset()

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    @action(detail=True, methods=['patch'])
    def update_tag(self, request, pk=None):
        user = self.get_object()
        tag = request.data.get('campus_tag')
        if tag:
            user.campus_tag = tag
            user.save()
            return Response({'status': 'tag updated'})
        return Response({'error': 'No tag provided'}, status=400)

class FCMViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['post'])
    def register(self, request):
        serializer = FCMTokenSerializer(instance=request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({'status': 'FCM token registered'})
        return Response(serializer.errors, status=400)

# ====================== Authentication Views ======================
def get_tokens_and_user_data(user):
    refresh = RefreshToken.for_user(user)
    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': {
            'first_name': user.first_name,
            'last_name': user.last_name,
            'role': user.role,
            'university_id': user.university_id if user.role == 'student' else None,
            'username': user.username if user.role == 'admin' else None,
        }
    }

class RegisterUserView(APIView):
    def post(self, request):
        print('Incoming registration data:', request.data)  # <-- LOGGING
        data = request.data.copy()
        role = data.get('role')
        
        # Clean up fields based on role
        if role == 'student':
            # university_id required, username should be set to university_id
            if not data.get('university_id'):
                print('Error: university_id is required for students.')  # <-- LOGGING
                return Response({'detail': 'university_id is required for students.'}, status=status.HTTP_400_BAD_REQUEST)
            data['username'] = data['university_id']  # <-- Set username to university_id
        elif role == 'admin':
            # Admin users: username required, university_id should be None
            data['university_id'] = None
            if not data.get('username'):
                print('Error: username is required for admin role.')  # <-- LOGGING
                return Response({'detail': 'username is required for admin role.'}, status=status.HTTP_400_BAD_REQUEST)
            # Ensure campus_tag and program are properly handled for admin
            if 'campus_tag' not in data or data['campus_tag'] is None:
                data['campus_tag'] = 'on-campus'  # Set default for admin
            if 'program' not in data or data['program'] is None:
                data['program'] = None  # Explicitly allow None for admin
        else:
            # Other roles (lecturer, security): username required, university_id should be None
            data['university_id'] = None
            if not data.get('username'):
                print('Error: username is required for this role.')  # <-- LOGGING
                return Response({'detail': 'username is required for this role.'}, status=status.HTTP_400_BAD_REQUEST)
                
        serializer = UserRegistrationSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            role_disp = serializer.validated_data['role'].capitalize()
            print(f'{role_disp} registered successfully')  # <-- LOGGING
            return Response({'message': f'{role_disp} registered successfully'}, status=status.HTTP_201_CREATED)
        print('Serializer errors:', serializer.errors)  # <-- LOGGING
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    def post(self, request):
        identifier = request.data.get('identifier')
        password = request.data.get('password')
        role = request.data.get('role')

        if not all([identifier, password, role]):
            return Response({'detail': 'identifier, password, and role are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        # Allow student, admin, lecturer, security
        if role not in ['student', 'admin', 'lecturer', 'security']:
            return Response({'detail': 'Invalid role provided.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            if role == 'student':
                user = User.objects.get(university_id=identifier, role=role)
            else:  # admin, lecturer, security
                user = User.objects.get(username=identifier, role=role)
        except User.DoesNotExist:
            return Response({'detail': f'Invalid {role} credentials.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not user.check_password(password):
            return Response({'detail': 'Incorrect password.'}, status=status.HTTP_401_UNAUTHORIZED)

        return Response(get_tokens_and_user_data(user), status=status.HTTP_200_OK)

@api_view(['POST'])
def biometric_login(request):
    identifier = request.data.get('university_id')
    if not identifier:
        return Response({'detail': 'university_id is required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(university_id=identifier)
    except User.DoesNotExist:
        try:
            user = User.objects.get(username=identifier)
        except User.DoesNotExist:
            return Response({'detail': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    return Response(get_tokens_and_user_data(user), status=status.HTTP_200_OK)

@api_view(['GET', 'PUT'])
@permission_classes([IsAuthenticated])
def profile_view(request):
    user = request.user
    if request.method == 'GET':
        return Response({
            'first_name': user.first_name,
            'last_name': user.last_name
        }, status=status.HTTP_200_OK)

    if request.method == 'PUT':
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')
        if not all([first_name, last_name]):
            return Response({'detail': 'Both first_name and last_name are required.'},
                            status=status.HTTP_400_BAD_REQUEST)

        user.first_name = first_name
        user.last_name = last_name
        user.save()
        return Response({'message': 'Profile updated successfully.'}, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def verify_token(request):
    return Response({'message': 'Token is valid'}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def verify_password(request):
    user = request.user
    password = request.data.get('password')
    if user.check_password(password):
        return Response({'detail': 'Password verified'}, status=200)
    return Response({'detail': 'Incorrect password'}, status=400)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def change_password(request):
    user = request.user
    new_password = request.data.get('new_password')

    try:
        validate_password(new_password, user)
    except ValidationError as e:
        return Response({'detail': e.messages}, status=400)

    user.set_password(new_password)
    user.save()
    return Response({'detail': 'Password changed successfully.'}, status=200)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_info(request):
    user = request.user
    data = {
        'first_name': user.first_name,
        'last_name': user.last_name,
        'role': user.role,
    }
    if user.role == 'admin':
        data['username'] = user.username
    else:
        data['university_id'] = user.university_id
    return Response(data)

from rest_framework.generics import get_object_or_404

class SessionActionView(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def start(self, request, pk=None):
        session = get_object_or_404(Session, pk=pk)
        if session.start_time:
            return Response({'error': 'Session already started'}, status=400)
        session.start_time = timezone.now()
        session.save()
        SystemLog.objects.create(
            log_type='system',
            event='Session started',
            user=request.user,
            details=f"Session {session.id} started"
        )
        return Response({'status': 'session started'})

    def end(self, request, pk=None):
        session = get_object_or_404(Session, pk=pk)
        if session.end_time:
            return Response({'error': 'Session already ended'}, status=400)
        session.end_time = timezone.now()
        session.save()
        SystemLog.objects.create(
            log_type='system',
            event='Session ended',
            user=request.user,
            details=f"Session {session.id} ended"
        )
        return Response({'status': 'session ended'})

class AttendanceReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'admin':
            # Admins see all attendance
            records = Attendance.objects.all()
        elif user.role == 'lecturer':
            # Lecturers see attendance for their sessions
            records = Attendance.objects.filter(session__lecturer=user)
        else:
            # Students see their own attendance
            records = Attendance.objects.filter(user=user)
        serializer = AttendanceSerializer(records, many=True)
        return Response(serializer.data)

class ExitReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if user.role == 'admin':
            records = ExitLog.objects.all()
        else:
            records = ExitLog.objects.filter(user=user)
        serializer = ExitLogSerializer(records, many=True)
        return Response(serializer.data)

# ====================== Admin ViewSets ======================
class AdminStudentViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        # Only allow admin users
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        students = User.objects.filter(role='student')
        serializer = UserSerializer(students, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['patch'])
    def campus_tag(self, request, pk=None):
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student = User.objects.get(pk=pk, role='student')
            campus_tag = request.data.get('campus_tag')
            
            if campus_tag not in ['on-campus', 'off-campus']:
                return Response({'error': 'Invalid campus tag'}, status=status.HTTP_400_BAD_REQUEST)
            
            student.campus_tag = campus_tag
            student.save()
            
            SystemLog.objects.create(
                log_type='system',
                event='Campus tag updated',
                user=request.user,
                details=f'Student {student.university_id} tagged as {campus_tag}'
            )
            
            return Response({'status': 'updated'})
        except User.DoesNotExist:
            return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)

class AdminLeaveViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        leave_requests = LeaveRequest.objects.all()
        serializer = LeaveRequestSerializer(leave_requests, many=True)
        return Response(serializer.data)
    
    @action(detail=True, methods=['patch'])
    def status(self, request, pk=None):
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            leave_request = LeaveRequest.objects.get(pk=pk)
            new_status = request.data.get('status')
            
            if new_status not in ['approved', 'denied']:
                return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
            
            leave_request.status = new_status
            leave_request.reviewer = request.user
            leave_request.reviewed_at = timezone.now()
            leave_request.review_comments = request.data.get('comments', '')
            leave_request.save()
            
            SystemLog.objects.create(
                log_type='system',
                event=f'Leave request {new_status}',
                user=request.user,
                details=f'Leave request for {leave_request.user.university_id} {new_status}'
            )
            
            return Response({'status': 'updated'})
        except LeaveRequest.DoesNotExist:
            return Response({'error': 'Leave request not found'}, status=status.HTTP_404_NOT_FOUND)

class AdminSystemLogViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        logs = SystemLog.objects.all().order_by('-timestamp')
        serializer = SystemLogSerializer(logs, many=True)
        return Response(serializer.data)