from django.urls import path
from .views import RegisterUserView, LoginView, profile_view, verify_token, biometric_login, verify_password, change_password, user_info
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views


router = DefaultRouter()
router.register(r'programs', views.ProgramViewSet, basename='program')
router.register(r'sessions', views.SessionViewSet, basename='session')
router.register(r'attendance', views.AttendanceViewSet, basename='attendance')
router.register(r'leave', views.LeaveRequestViewSet, basename='leave')
router.register(r'logs', views.SystemLogViewSet, basename='log')
router.register(r'exits', views.ExitViewSet, basename='exit')  # Fixed: use ExitViewSet

# Admin routes
router.register(r'admin/students', views.AdminStudentViewSet, basename='admin-students')
router.register(r'admin/leave-requests', views.AdminLeaveViewSet, basename='admin-leave')
router.register(r'admin/system-logs', views.AdminSystemLogViewSet, basename='admin-logs')

urlpatterns = [
    path('register/', RegisterUserView.as_view(), name='register'),
    path('login/', LoginView.as_view(), name='login'),  # new login view
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('verify-token/', verify_token, name='verify_token'),
    path('verify-password/', verify_password, name='verify_password'),
    path('change-password/', change_password, name='change_password'),
    path('user-info/', user_info, name='user_info'),
    path('biometric-login/', biometric_login, name='biometric-login'),
    path('my-profile/', profile_view, name='get_update_profile'),

    # Custom endpoints
    path('exit/process/', views.ExitViewSet.as_view({'post': 'process'}), name='exit-process'),
    path('users/<int:pk>/update-tag/', views.UserViewSet.as_view({'patch': 'update_tag'}), name='user-update-tag'),
    path('fcm/register/', views.FCMViewSet.as_view({'post': 'register'}), name='fcm-register'),
    path('fcm/', views.FCMViewSet.as_view({'post': 'register'}), name='fcm'),
    path('ble-status/', views.BLEStatusAPIView.as_view(), name='ble-status'),  # New BLE status endpoint
    
    # Session management
    path('sessions/<int:pk>/activate/', views.SessionViewSet.as_view({'post': 'activate'}), name='session-activate'),
    path('sessions/<int:pk>/end/', views.SessionActionView.as_view({'post': 'end'}), name='session-end'),
    
    # Reports
    path('reports/attendance/', views.AttendanceReportView.as_view(), name='attendance-report'),
    path('reports/exit/', views.ExitReportView.as_view(), name='exit-report'),
    # Place profile endpoint last to avoid router masking
    
    # Router-generated URLs (must be last)
    # Note: Use plural endpoints, e.g. /api/sessions/, /api/programs/
    path('', include(router.urls)),
]
