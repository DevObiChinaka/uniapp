from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

# API Documentation setup
schema_view = get_schema_view(
    openapi.Info(
        title="SALMS API",
        default_version='v1',
        description="Smart Attendance & Leave Management System API",
        contact=openapi.Contact(email="support@salms.example.com"),
        license=openapi.License(name="Proprietary License"),
    ),
    public=True,
    permission_classes=[permissions.AllowAny],
)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('users.urls')),
    # API Documentation
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    # Authentication
    path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # Core API endpoints
    # path('api/v1/', include([
    #     # Attendance app endpoints
    #     # path('attendance/', include('attendance.urls')),
    #     # User management
    #     # path('users/', include('users.urls')),
    #     # System management
    #     # path('system/', include('system.urls')),
    # ])),
    # Health check
    # path('health/', include('health_check.urls')),
]
