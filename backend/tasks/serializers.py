from rest_framework import serializers
from .models import Task, ChecklistItem


class ChecklistItemSerializer(serializers.ModelSerializer):
    """Serializer for ChecklistItem model"""
    class Meta:
        model = ChecklistItem
        fields = ('id', 'title', 'completed', 'order', 'created_at', 'updated_at')
        read_only_fields = ('id', 'created_at', 'updated_at')


class TaskSerializer(serializers.ModelSerializer):
    """Serializer for Task model with nested checklist items"""
    owner = serializers.ReadOnlyField(source='owner.id')
    checklist_items = ChecklistItemSerializer(many=True, read_only=True)

    class Meta:
        model = Task
        fields = ('id', 'title', 'description', 'category', 'priority', 'due_date', 'due_time', 
                  'notes', 'completed', 'created_at', 'updated_at', 'owner', 'checklist_items')
        read_only_fields = ('id', 'created_at', 'updated_at', 'owner')
