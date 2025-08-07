# --- Lecturer: Get Attendance Records for Session ---
# --- Lecturer: Get Students for Course ---
from rest_framework.generics import get_object_or_404
# --- Lecturer: Get Courses with Sessions ---
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Geofence
from .serializers import GeofenceSerializer
from .models import Program
from .serializers import ProgramSerializer
from rest_framework import viewsets
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
from .models import User, Session, Attendance, LeaveRequest, ExitLog, SystemLog, Course
from .serializers import (
    UserSerializer, SessionSerializer, AttendanceSerializer,
    LeaveRequestSerializer, LeaveRequestCreateSerializer, ExitLogSerializer, SystemLogSerializer,
    UserRegistrationSerializer, FCMTokenSerializer, CourseSerializer, CourseWithSessionsSerializer,
    AttendanceRecordSummarySerializer
)
# --- Course ViewSet ---
from rest_framework import filters



class LecturerSessionAttendanceAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, session_id):
        user = request.user
        if getattr(user, 'role', None) != 'lecturer':
            return Response({'error': 'Permission denied'}, status=403)
        session = get_object_or_404(Session, id=session_id)
        # Only allow if lecturer owns the session
        if session.lecturer != user:
            return Response({'error': 'Permission denied'}, status=403)
        records = Attendance.objects.filter(session=session)
        serializer = AttendanceRecordSummarySerializer(records, many=True)
        return Response({'attendance_records': serializer.data})
class LecturerCourseStudentsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, course_id):
        user = request.user
        if getattr(user, 'role', None) != 'lecturer':
            return Response({'error': 'Permission denied'}, status=403)
        course = get_object_or_404(Course, id=course_id)
        # Get all programs linked to this course
        programs = course.programs.all()
        # Get all students in those programs
        students = User.objects.filter(role='student', program__in=programs).distinct()
        serializer = UserSerializer(students, many=True)
        return Response({'students': serializer.data})
class LecturerCoursesWithSessionsAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        if getattr(user, 'role', None) != 'lecturer':
            return Response({'error': 'Permission denied'}, status=403)
        sessions = Session.objects.filter(lecturer=user)
        course_ids = sessions.values_list('course_id', flat=True).distinct()
        courses = Course.objects.filter(id__in=course_ids).prefetch_related('programs', 'sessions')
        serializer = CourseWithSessionsSerializer(
            courses,
            many=True,
            context={'lecturer_sessions': sessions}
        )
        return Response({'courses': serializer.data})
class CourseViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Course.objects.all()
    serializer_class = CourseSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ['program__id', 'level']

    def get_queryset(self):
        queryset = Course.objects.all()
        program_ids = self.request.query_params.get('programs')
        level = self.request.query_params.get('level')
        if program_ids:
            # Accept comma-separated list of IDs
            try:
                id_list = [int(pid) for pid in program_ids.split(',') if pid.strip().isdigit()]
                queryset = queryset.filter(programs__id__in=id_list).distinct()
            except Exception:
                pass
        if level:
            queryset = queryset.filter(level=level)
        return queryset

User = get_user_model()

# ====================== ViewSets ======================
class SessionViewSet(viewsets.ModelViewSet):
    def list(self, request, *args, **kwargs):
        user = request.user
        queryset = self.get_queryset()
        # For students, filter sessions by program and level
        if user.role == 'student':
            user_program = getattr(user, 'program', None)
            user_level = getattr(user, 'level', None)
            # Ensure user_program is a Program instance
            from .models import Program
            if user_program and isinstance(user_program, str):
                user_program_obj = Program.objects.filter(name=user_program).first()
                user_program = user_program_obj
            if user_program and user_level:
                queryset = queryset.filter(
                    course__programs=user_program,
                    course__level=user_level
                )
        else:
            # For staff/admin, filter by username if provided
            username = request.query_params.get('username')
            if username:
                queryset = queryset.filter(lecturer__username=username)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)
    queryset = Session.objects.all()
    serializer_class = SessionSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request):
        import logging
        logger = logging.getLogger('django')
        logger.debug(f"[SessionViewSet.create] Incoming data: {request.data}")
        print(f"[SessionViewSet.create] Incoming data: {request.data}")

        active_sessions = Session.objects.filter(
            course_id=request.data.get('course_id'),
            level=request.data.get('level'),
            end_time__isnull=True
        )
        # You may want to block creation if a session is already active for this program
        # if active_sessions.exists():
        #     logger.debug('Active session exists for this program.')
        #     return Response({'error': 'SESSION_CONFLICT', 'message': 'Active session exists for this program.'}, status=status.HTTP_400_BAD_REQUEST)

        lecturer_username = request.data.get('lecturer')
        if lecturer_username:
            try:
                lecturer = User.objects.get(username=lecturer_username)
            except User.DoesNotExist:
                logger.error(f"Lecturer username not found: {lecturer_username}")
                print(f"Lecturer username not found: {lecturer_username}")
                return Response({'error': 'LECTURER_NOT_FOUND', 'message': 'Lecturer username not found.'}, status=status.HTTP_400_BAD_REQUEST)
        else:
            lecturer = request.user

        # Handle geofence data
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        radius = request.data.get('radius')
        geofence_obj = None
        if latitude and longitude and radius:
            from .models import Geofence
            geofence_obj = Geofence.objects.create(latitude=latitude, longitude=longitude, radius=radius)

        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            logger.debug(f"[SessionViewSet.create] Validated data: {serializer.validated_data}")
            print(f"[SessionViewSet.create] Validated data: {serializer.validated_data}")
            # Save session with geofence if available
            session = serializer.save(lecturer=lecturer, geofence=geofence_obj)

            SystemLog.objects.create(
                log_type='system',
                event='Session started',
                user=lecturer,
                details=f"Session {session.id} started"
            )
            logger.info(f"Session created successfully: {serializer.data}")
            print(f"Session created successfully: {serializer.data}")
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        except Exception as e:
            logger.error(f"Error creating session: {str(e)}")
            print(f"Error creating session: {str(e)}")
            return Response({'error': 'SESSION_CREATION_ERROR', 'message': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        import logging
        logger = logging.getLogger('django')
        logger.debug(f"[SessionViewSet.activate] Called with pk={pk}, user={request.user}, data={request.data}")
        print(f"[SessionViewSet.activate] Called with pk={pk}, user={request.user}, data={request.data}")
        session = self.get_object()
        logger.debug(f"[SessionViewSet.activate] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}, current_period={session.current_period}, total_sessions={session.total_sessions}, lecturer={session.lecturer}")
        print(f"[SessionViewSet.activate] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}, current_period={session.current_period}, total_sessions={session.total_sessions}, lecturer={session.lecturer}")
        if session.lecturer != request.user:
            logger.debug(f"[SessionViewSet.activate] PERMISSION_DENIED: user={request.user} is not session lecturer={session.lecturer}")
            print(f"[SessionViewSet.activate] PERMISSION_DENIED: user={request.user} is not session lecturer={session.lecturer}")
            return Response({'error': 'PERMISSION_DENIED', 'message': 'You do not own this session.'}, status=status.HTTP_403_FORBIDDEN)
        from django.utils import timezone
        # Allow re-activation as long as scheduled end_time is in the future
        if session.end_time is not None and session.end_time <= timezone.now():
            logger.debug(f"[SessionViewSet.activate] SESSION_ALREADY_ENDED: scheduled end_time={session.end_time} (<= now)")
            print(f"[SessionViewSet.activate] SESSION_ALREADY_ENDED: scheduled end_time={session.end_time} (<= now)")
            return Response({'error': 'SESSION_ALREADY_ENDED', 'message': 'Session already ended.'}, status=status.HTTP_400_BAD_REQUEST)

        # Increment current_period
        session.current_period += 1
        session.start_time = timezone.now()
        # If current_period >= total_sessions, close session
        if session.current_period >= session.total_sessions:
            session.is_active = False
            session.actual_end_time = timezone.now()
            logger.debug(f"[SessionViewSet.activate] Session permanently ended: current_period={session.current_period}, total_sessions={session.total_sessions}")
            print(f"[SessionViewSet.activate] Session permanently ended: current_period={session.current_period}, total_sessions={session.total_sessions}")
        else:
            session.is_active = True
            logger.debug(f"[SessionViewSet.activate] Session activated: current_period={session.current_period}")
            print(f"[SessionViewSet.activate] Session activated: current_period={session.current_period}")
        session.save()
        logger.debug(f"[SessionViewSet.activate] Session updated: id={session.id}, is_active={session.is_active}, end_time={session.end_time}, current_period={session.current_period}")
        print(f"[SessionViewSet.activate] Session updated: id={session.id}, is_active={session.is_active}, end_time={session.end_time}, current_period={session.current_period}")
        SystemLog.objects.create(
            log_type='system',
            event='Session activated',
            user=request.user,
            details=f"Session {session.id} activated (Period {session.current_period})"
        )
        return Response({
            'status': 'session activated',
            'session_id': session.id,
            'current_period': session.current_period,
            'is_active': session.is_active
        })
        
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
        import logging
        logger = logging.getLogger('django')
        logger.debug(f"[SessionViewSet.end] Called with pk={pk}, user={request.user}, data={request.data}")
        print(f"[SessionViewSet.end] Called with pk={pk}, user={request.user}, data={request.data}")
        session = self.get_object()
        logger.debug(f"[SessionViewSet.end] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}")
        print(f"[SessionViewSet.end] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}")
        session.actual_end_time = timezone.now()
        session.is_active = False
        session.save()
        logger.debug(f"[SessionViewSet.end] Session updated: id={session.id}, is_active={session.is_active}, actual_end_time={session.actual_end_time}")
        print(f"[SessionViewSet.end] Session updated: id={session.id}, is_active={session.is_active}, actual_end_time={session.actual_end_time}")
        SystemLog.objects.create(
            log_type='system',
            event='Session ended',
            user=request.user,
            details=f"Session {session.id} ended"
        )
        return Response({'status': 'session ended'})

# --- Geofence ViewSet ---
class GeofenceViewSet(viewsets.ModelViewSet):
    queryset = Geofence.objects.all()
    serializer_class = GeofenceSerializer
    permission_classes = [IsAuthenticated]


class AttendanceViewSet(viewsets.ModelViewSet):
    queryset = Attendance.objects.all()
    serializer_class = AttendanceSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request):
        # BLE validation removed

        # Geofence validation
        session_id = request.data.get('session')
        session = Session.objects.get(id=session_id)
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')

        print('[AttendanceViewSet.create] Incoming data:', request.data)  # <-- LOGGING

        # Accept either PK or university_id for user
        user_ref = request.data.get('user')
        user_obj = None
        if user_ref:
            # Try to get by PK (int)
            try:
                user_obj = User.objects.get(pk=int(user_ref))
            except (ValueError, User.DoesNotExist):
                # Try to get by university_id (string)
                try:
                    user_obj = User.objects.get(university_id=user_ref)
                except User.DoesNotExist:
                    print('[AttendanceViewSet.create] User not found for:', user_ref)
                    return Response({'error': 'USER_NOT_FOUND'}, status=status.HTTP_400_BAD_REQUEST)

        if not user_obj:
            print('[AttendanceViewSet.create] No user found for:', user_ref)
            return Response({'error': 'USER_NOT_FOUND'}, status=status.HTTP_400_BAD_REQUEST)

        # Prevent duplicate attendance for same user/session/period
        period = session.current_period
        existing = Attendance.objects.filter(user=user_obj, session=session, period=period).first()
        if existing:
            print('[AttendanceViewSet.create] Duplicate attendance detected for user:', user_obj.pk, 'session:', session.pk, 'period:', period)
            return Response({'error': 'ALREADY_MARKED', 'message': 'Attendance already marked for this period.'}, status=status.HTTP_409_CONFLICT)

        # Replace user field in data with PK
        data = request.data.copy()
        data['user'] = user_obj.pk

        serializer = self.get_serializer(data=data)
        try:
            serializer.is_valid(raise_exception=True)
        except Exception as e:
            print('[AttendanceViewSet.create] Serializer errors:', serializer.errors)  # <-- LOGGING
            raise
        # Set period to session.current_period
        serializer.save(user=user_obj, session=session, period=period)

        SystemLog.objects.create(
            log_type='attendance',
            event='Attendance marked',
            user=user_obj,
            details=f"Method: {request.data.get('method', 'unknown')}"
        )
        headers = self.get_success_headers(serializer.data)
        print('[AttendanceViewSet.create] Created attendance:', serializer.data)  # <-- LOGGING
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)
        # Set period to session.current_period
        serializer.save(user=request.user, session=session, period=session.current_period)

        SystemLog.objects.create(
            log_type='attendance',
            event='Attendance marked',
            user=request.user,
            details=f"Method: {request.data.get('method', 'unknown')}"
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['delete'])
    def remove(self, request, pk=None):
        attendance = self.get_object()
        if request.user.role not in ['lecturer', 'admin']:
            return Response({'error': 'PERMISSION_DENIED'}, status=status.HTTP_403_FORBIDDEN)
        attendance.delete()
        SystemLog.objects.create(
            log_type='attendance',
            event='Attendance removed',
            user=request.user,
            details=f"Attendance {pk} removed"
        )
        return Response({'status': 'attendance removed'})

    @action(detail=True, methods=['post'])
    def flag(self, request, pk=None):
        attendance = self.get_object()
        reason = request.data.get('reason', '')
        attendance.flagged = True
        attendance.flag_reason = reason
        attendance.save()
        SystemLog.objects.create(
            log_type='attendance',
            event='Attendance flagged',
            user=request.user,
            details=f"Attendance {pk} flagged: {reason}"
        )
        return Response({'status': 'attendance flagged'})

    def get_queryset(self):
        user = self.request.user
        queryset = Attendance.objects.all()
        user_id = self.request.query_params.get('user_id')
        username = self.request.query_params.get('username')
        if user_id:
            queryset = queryset.filter(user__university_id=user_id)
        elif username:
            queryset = queryset.filter(session__lecturer__username=username)
        else:
            # Fallback to user role-based filtering
            if user.role == 'student':
                queryset = queryset.filter(user=user)
            elif user.role == 'lecturer':
                queryset = queryset.filter(session__lecturer=user)
            elif user.role == 'admin':
                queryset = queryset.all()
            else:
                queryset = queryset.none()
        return queryset
class LeaveRequestViewSet(viewsets.ModelViewSet):
    queryset = LeaveRequest.objects.all()
    serializer_class = LeaveRequestSerializer
    permission_classes = [IsAuthenticated]

    def get_serializer_class(self):
        if self.action == 'create':
            return LeaveRequestCreateSerializer
        return LeaveRequestSerializer

    def get_queryset(self):
        if self.request.user.role == 'student':
            return LeaveRequest.objects.filter(user=self.request.user)
        return super().get_queryset()

    def create(self, request):
        print(f"[DEBUG] Received leave request data: {request.data}")
        
        # Filter out only the fields we need for creation
        filtered_data = {
            'start_date': request.data.get('start_date'),
            'end_date': request.data.get('end_date'),
            'reason': request.data.get('reason'),
        }
        print(f"[DEBUG] Filtered data for serializer: {filtered_data}")
        
        serializer = self.get_serializer(data=filtered_data)
        if not serializer.is_valid():
            print(f"[DEBUG] Serializer errors: {serializer.errors}")
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            print(f"[DEBUG] Current user: {request.user}, ID: {request.user.id}, Role: {request.user.role}")
            leave_request = serializer.save(user=request.user)
            print(f"[DEBUG] Successfully created leave request with ID: {leave_request.id}")
            
            # Return the created object with the read serializer
            response_serializer = LeaveRequestSerializer(leave_request)
            
            # Try to send notification (optional - don't fail if tasks aren't working)
            try:
                async_task('users.tasks.notify_admin_new_leave', leave_request.id)
            except Exception as task_error:
                print(f"[DEBUG] Task notification failed: {task_error}")
                
            return Response(response_serializer.data, status=status.HTTP_201_CREATED)
        except Exception as e:
            print(f"[DEBUG] Error saving leave request: {e}")
            import traceback
            print(f"[DEBUG] Full traceback: {traceback.format_exc()}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

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

# Program ViewSet
class ProgramViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Program.objects.all()
    serializer_class = ProgramSerializer

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
        else:
            # username required, university_id should be None or blank
            data['university_id'] = ''
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
def profile_view(request):
    user = request.user
    if request.method == 'GET':
        from .serializers import ProgramSerializer
        program_data = None
        if getattr(user, 'program', None):
            program_data = ProgramSerializer(user.program).data
        return Response({
            'id': user.id,
            'name': user.get_full_name(),
            'first_name': user.first_name,
            'last_name': user.last_name,
            'username': user.username,
            'email': user.email,
            'university_id': user.university_id,
            'role': getattr(user, 'role', None),
            'program': program_data,
            'level': getattr(user, 'level', None),
            'profile_picture_url': getattr(user, 'profile_picture_url', None),
            'is_on_campus': getattr(user, 'is_on_campus', None),
            'campus_tag': getattr(user, 'campus_tag', None),
        }, status=status.HTTP_200_OK)

    if request.method == 'PUT':
        first_name = request.data.get('first_name')
        last_name = request.data.get('last_name')
        profile_picture = request.data.get('profile_picture')
        email = request.data.get('email')
        program_id = request.data.get('program')
        if first_name:
            user.first_name = first_name
        if last_name:
            user.last_name = last_name
        if profile_picture:
            user.profile_picture_url = profile_picture
        if email:
            user.email = email
        if program_id:
            # Set program using ID
            from .models import Program
            try:
                program_obj = Program.objects.get(id=program_id)
                user.program = program_obj
            except Program.DoesNotExist:
                pass
        user.save()
        # Always serialize program as nested object
        from .serializers import ProgramSerializer
        program_data = None
        if getattr(user, 'program', None):
            program_data = ProgramSerializer(user.program).data
        return Response({
            'id': user.id,
            'name': user.get_full_name(),
            'first_name': user.first_name,
            'last_name': user.last_name,
            'username': user.username,
            'email': user.email,
            'university_id': user.university_id,
            'role': getattr(user, 'role', None),
            'program': program_data,
            'level': getattr(user, 'level', None),
            'profile_picture_url': getattr(user, 'profile_picture_url', None),
            'is_on_campus': getattr(user, 'is_on_campus', None),
            'campus_tag': getattr(user, 'campus_tag', None),
            'message': 'Profile updated successfully.'
        }, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def verify_token(request):
    return Response({'message': 'Token is valid'}, status=status.HTTP_200_OK)

@api_view(['POST'])
def verify_password(request):
    user = request.user
    password = request.data.get('password')
    if user.check_password(password):
        return Response({'detail': 'Password verified'}, status=200)
    return Response({'detail': 'Incorrect password'}, status=400)

@api_view(['PUT'])
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
        import logging
        logger = logging.getLogger('django')
        logger.debug(f"[SessionActionView.end] Called with pk={pk}, user={request.user}, data={request.data}")
        print(f"[SessionActionView.end] Called with pk={pk}, user={request.user}, data={request.data}")
        session = get_object_or_404(Session, pk=pk)
        logger.debug(f"[SessionActionView.end] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}")
        print(f"[SessionActionView.end] Session object: id={session.id}, is_active={session.is_active}, end_time={session.end_time}")
        if not session.is_active:
            logger.debug(f"[SessionActionView.end] Session already ended (is_active is False)!")
            print(f"[SessionActionView.end] Session already ended (is_active is False)!")
            return Response({'error': 'Session already ended'}, status=400)
        # Allow ending if is_active is True, regardless of end_time
        session.actual_end_time = timezone.now()
        session.is_active = False
        session.save()
        logger.debug(f"[SessionActionView.end] Session updated: id={session.id}, is_active={session.is_active}, actual_end_time={session.actual_end_time}")
        print(f"[SessionActionView.end] Session updated: id={session.id}, is_active={session.is_active}, actual_end_time={session.actual_end_time}")
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
        return Response({'data': serializer.data})
    
    @action(detail=True, methods=['put'], url_path='campus-tag')
    def update_campus_tag(self, request, pk=None):
        # Only allow admin users
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student = User.objects.get(pk=pk, role='student')
            is_on_campus = request.data.get('is_on_campus')
            if is_on_campus is not None:
                student.campus_tag = 'on-campus' if is_on_campus else 'off-campus'
                student.save()
                
                # Log the campus status change
                SystemLog.objects.create(
                    user=student,
                    log_type='system',
                    event=f'Campus status changed to {"on-campus" if is_on_campus else "off-campus"}',
                    details=f'Updated by admin: {request.user.username or request.user.first_name + " " + request.user.last_name}',
                    timestamp=timezone.now()
                )
                
                return Response({'message': 'Campus tag updated'})
            return Response({'error': 'is_on_campus field required'}, status=status.HTTP_400_BAD_REQUEST)
        except User.DoesNotExist:
            return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)


class AdminLeaveViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        # Only allow admin users
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        leave_requests = LeaveRequest.objects.all().order_by('-submitted_at')
        serializer = LeaveRequestSerializer(leave_requests, many=True)
        return Response({'data': serializer.data})
    
    def update(self, request, pk=None):
        # Only allow admin users
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        try:
            leave_request = LeaveRequest.objects.get(pk=pk)
            new_status = request.data.get('status')
            if new_status in ['approved', 'denied']:
                leave_request.status = new_status
                leave_request.reviewed_by = request.user
                leave_request.reviewed_at = timezone.now()
                leave_request.review_comments = request.data.get('comments', '')
                leave_request.save()
                
                # Log the leave request decision
                SystemLog.objects.create(
                    user=leave_request.user,
                    log_type='system',
                    event=f'Leave request {new_status}',
                    details=f'Leave request from {leave_request.start_date} to {leave_request.end_date} was {new_status} by {request.user.name}',
                    timestamp=timezone.now()
                )
                
                return Response({'message': f'Leave request {new_status}'})
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        except LeaveRequest.DoesNotExist:
            return Response({'error': 'Leave request not found'}, status=status.HTTP_404_NOT_FOUND)


class AdminSystemLogViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]
    
    def list(self, request):
        # Only allow admin users
        if request.user.role != 'admin':
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)
        
        logs = SystemLog.objects.all().order_by('-timestamp')
        serializer = SystemLogSerializer(logs, many=True)
        return Response({'data': serializer.data})

class BLEStatusAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        lecturer_username = request.data.get('lecturer_username')
        session_id = request.data.get('session_id')
        ble_enabled = request.data.get('ble_enabled')
        if not lecturer_username or not session_id:
            return Response({'error': 'Missing lecturer_username or session_id'}, status=status.HTTP_400_BAD_REQUEST)
        # Log BLE status to SystemLog
        try:
            lecturer = User.objects.get(username=lecturer_username)
        except User.DoesNotExist:
            lecturer = None
        SystemLog.objects.create(
            user=lecturer if lecturer else request.user,
            log_type='system',
            event='BLE status update',
            details=f'BLE enabled: {ble_enabled}, session: {session_id}',
            timestamp=timezone.now()
        )
        return Response({
            'status': 'BLE status updated',
            'lecturer_username': lecturer_username,
            'session_id': session_id,
            'ble_enabled': ble_enabled,
        }, status=status.HTTP_200_OK)