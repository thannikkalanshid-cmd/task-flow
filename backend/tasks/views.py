from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from .models import Task, ChecklistItem
from .serializers import TaskSerializer, ChecklistItemSerializer


class TaskViewSet(viewsets.ModelViewSet):
    """ViewSet for Task model with CRUD operations"""
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Get tasks for the current user"""
        return Task.objects.filter(owner=self.request.user).order_by('-created_at')

    def perform_create(self, serializer):
        """Save task with current user as owner"""
        serializer.save(owner=self.request.user)

    def perform_update(self, serializer):
        """Update task only if current user is the owner"""
        if serializer.instance.owner != self.request.user:
            raise PermissionDenied('Cannot edit tasks that do not belong to you.')
        serializer.save()

    def perform_destroy(self, instance):
        """Delete task only if current user is the owner"""
        if instance.owner != self.request.user:
            raise PermissionDenied('Cannot delete tasks that do not belong to you.')
        instance.delete()

    @action(detail=True, methods=['post'])
    def add_checklist_item(self, request, pk=None):
        """Add a checklist item to a task"""
        task = self.get_object()
        serializer = ChecklistItemSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(task=task)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ChecklistItemViewSet(viewsets.ModelViewSet):
    """ViewSet for ChecklistItem model"""
    serializer_class = ChecklistItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Get checklist items for tasks owned by current user"""
        return ChecklistItem.objects.filter(task__owner=self.request.user).order_by('order')

    def perform_create(self, serializer):
        """Verify task ownership before creating checklist item"""
        task_id = self.request.data.get('task_id')
        try:
            task = Task.objects.get(id=task_id, owner=self.request.user)
            serializer.save(task=task)
        except Task.DoesNotExist:
            raise PermissionDenied('Cannot add items to tasks that do not belong to you.')

    def perform_update(self, serializer):
        """Verify task ownership before updating checklist item"""
        if serializer.instance.task.owner != self.request.user:
            raise PermissionDenied('Cannot update items in tasks that do not belong to you.')
        serializer.save()

    def perform_destroy(self, instance):
        """Verify task ownership before deleting checklist item"""
        if instance.task.owner != self.request.user:
            raise PermissionDenied('Cannot delete items from tasks that do not belong to you.')
        instance.delete()
