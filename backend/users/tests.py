import base64
import tempfile

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from rest_framework.test import APITestCase


User = get_user_model()


class ProfileApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='owner', password='password123')
        self.client.force_authenticate(self.user)

    def test_user_can_update_own_profile(self):
        response = self.client.patch(
            '/api/profile/',
            {'username': 'updated-owner', 'email': 'owner@example.com', 'bio': 'Hello'},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.username, 'updated-owner')
        self.assertEqual(self.user.bio, 'Hello')

    def test_username_must_be_unique(self):
        User.objects.create_user(username='taken', password='password123')

        response = self.client.patch(
            '/api/profile/',
            {'username': 'TAKEN'},
            format='json',
        )

        self.assertEqual(response.status_code, 400)

    @override_settings(MEDIA_ROOT=tempfile.gettempdir())
    def test_user_can_upload_profile_image(self):
        gif = base64.b64decode(
            'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=='
        )
        image = SimpleUploadedFile('avatar.gif', gif, content_type='image/gif')

        response = self.client.post(
            '/api/profile/image/',
            {'profile_image': image},
            format='multipart',
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('profile_image_url', response.data)
