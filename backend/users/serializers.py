from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'password', 'bio')
        extra_kwargs = {'bio': {'required': False}}

    def create(self, validated_data):
        password = validated_data.pop('password')
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserSerializer(serializers.ModelSerializer):
    profile_image_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ('id', 'username', 'email', 'bio', 'profile_image_url')
        read_only_fields = ('id', 'profile_image_url')

    def get_profile_image_url(self, obj):
        if not obj.profile_image:
            return None
        request = self.context.get('request')
        url = obj.profile_image.url
        return request.build_absolute_uri(url) if request else url

    def validate_username(self, value):
        queryset = User.objects.filter(username__iexact=value)
        if self.instance:
            queryset = queryset.exclude(pk=self.instance.pk)
        if queryset.exists():
            raise serializers.ValidationError('This username is already taken.')
        return value


class ProfileImageSerializer(serializers.ModelSerializer):
    profile_image_url = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = User
        fields = ('profile_image', 'profile_image_url')
        extra_kwargs = {'profile_image': {'write_only': True, 'required': True}}

    def get_profile_image_url(self, obj):
        request = self.context.get('request')
        url = obj.profile_image.url
        return request.build_absolute_uri(url) if request else url

    def validate_profile_image(self, image):
        if image.size > 5 * 1024 * 1024:
            raise serializers.ValidationError('Image size must not exceed 5 MB.')
        return image
