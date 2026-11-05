import secrets
import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.utils import timezone
from datetime import timedelta
from rest_framework import generics, parsers, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from .serializers import (
    ProfileImageSerializer,
    EmailOtpSerializer,
    ResendEmailOtpSerializer,
    UserRegistrationSerializer,
    UserSerializer,
)

User = get_user_model()
logger = logging.getLogger(__name__)


def send_email_otp(user):
    code = f'{secrets.randbelow(1_000_000):06d}'
    user.email_otp_hash = make_password(code)
    user.email_otp_expires_at = timezone.now() + timedelta(minutes=10)
    user.email_otp_attempts = 0
    user.save(update_fields=['email_otp_hash', 'email_otp_expires_at', 'email_otp_attempts'])
    send_mail(
        subject='Verify your TaskFlow email',
        message=(
            f'Your TaskFlow verification code is {code}.\n\n'
            'It expires in 10 minutes. Do not share this code with anyone.'
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )


class RegisterUserView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserRegistrationSerializer
    permission_classes = [permissions.AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        try:
            send_email_otp(user)
        except Exception:
            logger.exception('Unable to send account-verification email')
            user.delete()
            return Response(
                {'detail': 'We could not send the verification email. Please try again later.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        return Response(
            {'detail': 'Verification code sent. Check your email.', 'email': user.email},
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailOtpView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = EmailOtpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = User.objects.filter(email__iexact=data['email'].strip()).first()
        if not user:
            return Response({'detail': 'Invalid verification code.'}, status=status.HTTP_400_BAD_REQUEST)
        if user.email_verified:
            return Response({'detail': 'This email is already verified.'}, status=status.HTTP_400_BAD_REQUEST)
        if not user.email_otp_expires_at or user.email_otp_expires_at <= timezone.now():
            return Response({'detail': 'This code has expired. Request a new code.'}, status=status.HTTP_400_BAD_REQUEST)
        if user.email_otp_attempts >= 5:
            return Response({'detail': 'Too many attempts. Request a new code.'}, status=status.HTTP_429_TOO_MANY_REQUESTS)
        if not check_password(data['otp'], user.email_otp_hash):
            user.email_otp_attempts += 1
            user.save(update_fields=['email_otp_attempts'])
            return Response({'detail': 'Invalid verification code.'}, status=status.HTTP_400_BAD_REQUEST)
        user.email_verified = True
        user.is_active = True
        user.email_otp_hash = ''
        user.email_otp_expires_at = None
        user.email_otp_attempts = 0
        user.save(update_fields=['email_verified', 'is_active', 'email_otp_hash', 'email_otp_expires_at', 'email_otp_attempts'])
        return Response({'detail': 'Email verified. You can now log in.'})


class ResendEmailOtpView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = ResendEmailOtpSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(email__iexact=serializer.validated_data['email'].strip()).first()
        if user and not user.email_verified:
            try:
                send_email_otp(user)
            except Exception:
                logger.exception('Unable to resend account-verification email')
                return Response({'detail': 'We could not send the verification email. Please try again later.'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return Response({'detail': 'If the account needs verification, a new code has been sent.'})


class ProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    def put(self, request):
        return self._update(request)

    def patch(self, request):
        return self._update(request)

    def _update(self, request):
        serializer = UserSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class ProfileImageUploadView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [parsers.MultiPartParser, parsers.FormParser]

    def post(self, request):
        serializer = ProfileImageSerializer(
            request.user,
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
