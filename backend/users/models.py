from django.contrib.auth.models import AbstractUser
from django.db import models


class CustomUser(AbstractUser):
    email_verified = models.BooleanField(default=False)
    email_otp_hash = models.CharField(max_length=128, blank=True)
    email_otp_expires_at = models.DateTimeField(null=True, blank=True)
    email_otp_attempts = models.PositiveSmallIntegerField(default=0)
    bio = models.TextField(blank=True, default='')
    profile_image = models.ImageField(
        upload_to='profile_images/',
        blank=True,
        null=True,
    )

    def __str__(self):
        return self.email or self.username
