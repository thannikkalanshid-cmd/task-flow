from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import (
    ProfileImageUploadView, RegisterUserView, ProfileView, VerifyEmailOtpView,
    ResendEmailOtpView,
)

urlpatterns = [
    path('register/', RegisterUserView.as_view(), name='register'),
    path('verify-email/', VerifyEmailOtpView.as_view(), name='verify_email'),
    path('resend-verification/', ResendEmailOtpView.as_view(), name='resend_verification'),
    path('token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('profile/image/', ProfileImageUploadView.as_view(), name='profile_image'),
]
