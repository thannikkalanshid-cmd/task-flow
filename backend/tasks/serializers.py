from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Attachment, ChecklistItem, Tag, Task, TaskActivity, TaskComment, TaskMember, TaskNote


class ChecklistItemSerializer(serializers.ModelSerializer):
    """Serializer for ChecklistItem model"""
    class Meta:
        model = ChecklistItem
        fields = ('id', 'title', 'completed', 'order', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class TaskNoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = TaskNote
        fields = ('id', 'task', 'title', 'content', 'created_at', 'updated_at')
        read_only_fields = ('id', 'task', 'created_at', 'updated_at')


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ('id', 'name', 'color', 'created_at')
        read_only_fields = ('id', 'created_at')


class AttachmentSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = Attachment
        fields = ('id', 'original_name', 'file', 'url', 'created_at', 'uploaded_by')
        read_only_fields = ('id', 'url', 'created_at', 'uploaded_by')

    def get_url(self, obj):
        request = self.context.get('request')
        return request.build_absolute_uri(obj.file.url) if request else obj.file.url


class TaskMemberSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = TaskMember
        fields = ('id', 'user', 'username', 'role', 'joined_at')
        read_only_fields = ('id', 'username', 'joined_at')


class TaskCommentSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)

    class Meta:
        model = TaskComment
        fields = ('id', 'body', 'author', 'author_name', 'created_at')
        read_only_fields = ('id', 'author', 'author_name', 'created_at')


class TaskActivitySerializer(serializers.ModelSerializer):
    actor_name = serializers.CharField(source='actor.username', read_only=True)

    class Meta:
        model = TaskActivity
        fields = ('id', 'action', 'actor_name', 'created_at')


class TaskSerializer(serializers.ModelSerializer):
    """Serializer for Task model with nested checklist items"""
    owner = serializers.ReadOnlyField(source='owner.id')
    checklist_items = ChecklistItemSerializer(many=True, read_only=True)
    tags = TagSerializer(many=True, read_only=True)
    tag_ids = serializers.PrimaryKeyRelatedField(source='tags', many=True, queryset=Tag.objects.all(), write_only=True, required=False)
    attachments = AttachmentSerializer(many=True, read_only=True)
    members = TaskMemberSerializer(source='memberships', many=True, read_only=True)

    class Meta:
        model = Task
        fields = ('id', 'title', 'description', 'category', 'priority', 'due_date', 'due_time',
                  'notes', 'completed', 'archived', 'trashed_at', 'sort_order', 'recurrence',
                  'reminder_minutes', 'created_at', 'updated_at', 'owner', 'checklist_items',
                  'tags', 'tag_ids', 'attachments', 'members')
        read_only_fields = ('id', 'created_at', 'updated_at', 'owner')

    def validate_tag_ids(self, tags):
        user = self.context['request'].user
        if any(tag.owner != user for tag in tags):
            raise serializers.ValidationError('Tags must belong to the current user.')
        return tags
