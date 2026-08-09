from django.contrib.auth import get_user_model
from django.db.models import Q
from django.utils import timezone
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from .models import Attachment, ChecklistItem, Tag, Task, TaskActivity, TaskComment, TaskMember, TaskNote
from .serializers import (AttachmentSerializer, ChecklistItemSerializer, TagSerializer,
                          TaskActivitySerializer, TaskCommentSerializer, TaskMemberSerializer, TaskNoteSerializer, TaskSerializer)


class TaskViewSet(viewsets.ModelViewSet):
    """ViewSet for Task model with CRUD operations"""
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Get tasks for the current user"""
        shared = Q(memberships__user=self.request.user)
        queryset = Task.objects.filter(Q(owner=self.request.user) | shared).distinct()
        if self.request.query_params.get('include_archived') != 'true':
            queryset = queryset.filter(archived=False, trashed_at__isnull=True)
        return queryset.order_by('sort_order', '-created_at')

    def perform_create(self, serializer):
        """Save task with current user as owner"""
        task = serializer.save(owner=self.request.user)
        TaskMember.objects.get_or_create(task=task, user=self.request.user, defaults={'role': 'owner'})
        TaskActivity.objects.create(task=task, actor=self.request.user, action='created the task')

    def perform_update(self, serializer):
        """Update task only if current user is the owner"""
        if not self._can_edit(serializer.instance):
            raise PermissionDenied('Cannot edit tasks that do not belong to you.')
        task = serializer.save()
        TaskActivity.objects.create(task=task, actor=self.request.user, action='updated the task')

    def perform_destroy(self, instance):
        """Delete task only if current user is the owner"""
        if instance.owner != self.request.user:
            raise PermissionDenied('Cannot delete tasks that do not belong to you.')
        instance.delete()

    def _can_edit(self, task):
        return task.owner == self.request.user or task.memberships.filter(user=self.request.user, role='member').exists()

    @action(detail=True, methods=['get', 'post'])
    def notes(self, request, pk=None):
        task = self.get_object()
        if request.method == 'GET':
            return Response(TaskNoteSerializer(task.task_notes.all(), many=True).data)
        if not self._can_edit(task):
            raise PermissionDenied('Cannot add notes to this task.')
        serializer = TaskNoteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        note = serializer.save(task=task)
        TaskActivity.objects.create(task=task, actor=request.user, action='added a note')
        return Response(TaskNoteSerializer(note).data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'])
    def analytics(self, request):
        tasks = self.get_queryset()
        active = tasks.filter(trashed_at__isnull=True)
        total = active.count()
        completed = active.filter(completed=True).count()
        return Response({'total': total, 'completed': completed, 'pending': total - completed,
                         'completion_percentage': round(completed / total * 100, 1) if total else 0,
                         'average_tasks_per_day': round(total / max((timezone.now().date() - (active.order_by('created_at').first().created_at.date() if total else timezone.now().date())).days + 1, 1), 1)})

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        task = self.get_object()
        if not self._can_edit(task): raise PermissionDenied('Cannot archive this task.')
        task.archived = True; task.save(update_fields=['archived', 'updated_at'])
        return Response(self.get_serializer(task).data)

    @action(detail=True, methods=['post'])
    def trash(self, request, pk=None):
        task = self.get_object()
        if not self._can_edit(task): raise PermissionDenied('Cannot trash this task.')
        task.trashed_at = timezone.now(); task.save(update_fields=['trashed_at', 'updated_at'])
        return Response(self.get_serializer(task).data)

    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        task = self.get_object()
        if task.owner != request.user: raise PermissionDenied('Only the owner can restore this task.')
        task.trashed_at = None; task.archived = False; task.save(update_fields=['trashed_at', 'archived', 'updated_at'])
        return Response(self.get_serializer(task).data)

    @action(detail=True, methods=['post'])
    def members(self, request, pk=None):
        task = self.get_object()
        if task.owner != request.user: raise PermissionDenied('Only the owner can invite members.')
        username = request.data.get('username', '').strip()
        user = get_user_model().objects.filter(username=username).first()
        if not user: return Response({'username': ['User not found.']}, status=status.HTTP_400_BAD_REQUEST)
        membership, created = TaskMember.objects.get_or_create(task=task, user=user, defaults={'role': 'member'})
        return Response(TaskMemberSerializer(membership).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)

    @members.mapping.delete
    def remove_member(self, request, pk=None):
        task = self.get_object()
        if task.owner != request.user: raise PermissionDenied('Only the owner can remove members.')
        TaskMember.objects.filter(task=task, user_id=request.data.get('user_id'), role='member').delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        task = self.get_object()
        if task.owner == request.user: return Response({'detail': 'Owners cannot leave their task.'}, status=status.HTTP_400_BAD_REQUEST)
        TaskMember.objects.filter(task=task, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['get', 'post'])
    def comments(self, request, pk=None):
        task = self.get_object()
        if request.method == 'GET': return Response(TaskCommentSerializer(task.comments.all(), many=True).data)
        if not self._can_edit(task): raise PermissionDenied('Cannot comment on this task.')
        serializer = TaskCommentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True); serializer.save(task=task, author=request.user)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'])
    def activity(self, request, pk=None):
        return Response(TaskActivitySerializer(self.get_object().activities.all(), many=True).data)

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
        return ChecklistItem.objects.filter(
            Q(task__owner=self.request.user) | Q(task__memberships__user=self.request.user)
        ).distinct().order_by('order')

    def perform_create(self, serializer):
        """Verify task ownership before creating checklist item"""
        task_id = self.request.data.get('task_id')
        try:
            task = Task.objects.filter(id=task_id).filter(
                Q(owner=self.request.user) | Q(memberships__user=self.request.user)
            ).first()
            if not task:
                raise Task.DoesNotExist
            serializer.save(task=task)
        except Task.DoesNotExist:
            raise PermissionDenied('Cannot add items to tasks that do not belong to you.')

    def perform_update(self, serializer):
        """Verify task ownership before updating checklist item"""
        if not (serializer.instance.task.owner == self.request.user or serializer.instance.task.memberships.filter(user=self.request.user).exists()):
            raise PermissionDenied('Cannot update items in tasks that do not belong to you.')
        serializer.save()

    def perform_destroy(self, instance):
        """Verify task ownership before deleting checklist item"""
        if not (instance.task.owner == self.request.user or instance.task.memberships.filter(user=self.request.user).exists()):
            raise PermissionDenied('Cannot delete items from tasks that do not belong to you.')
        instance.delete()


class TaskNoteViewSet(viewsets.ModelViewSet):
    serializer_class = TaskNoteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return TaskNote.objects.filter(
            Q(task__owner=self.request.user) | Q(task__memberships__user=self.request.user)
        ).distinct()

    def perform_create(self, serializer):
        # Creation is intentionally only supported by /tasks/<task_id>/notes/.
        raise PermissionDenied('Create notes through the task notes endpoint.')

    def perform_update(self, serializer):
        task = serializer.instance.task
        if not (task.owner == self.request.user or task.memberships.filter(user=self.request.user, role='member').exists()):
            raise PermissionDenied('Cannot update notes in this task.')
        note = serializer.save()
        TaskActivity.objects.create(task=task, actor=self.request.user, action='updated a note')

    def perform_destroy(self, instance):
        task = instance.task
        if not (task.owner == self.request.user or task.memberships.filter(user=self.request.user, role='member').exists()):
            raise PermissionDenied('Cannot delete notes in this task.')
        TaskActivity.objects.create(task=task, actor=self.request.user, action='deleted a note')
        instance.delete()


class TagViewSet(viewsets.ModelViewSet):
    serializer_class = TagSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self): return Tag.objects.filter(owner=self.request.user)
    def perform_create(self, serializer): serializer.save(owner=self.request.user)


class AttachmentViewSet(viewsets.ModelViewSet):
    serializer_class = AttachmentSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Attachment.objects.filter(
            Q(task__owner=self.request.user) | Q(task__memberships__user=self.request.user)
        ).distinct()
    def perform_create(self, serializer):
        task = Task.objects.filter(pk=self.request.data.get('task_id')).filter(Q(owner=self.request.user) | Q(memberships__user=self.request.user)).first()
        if not task: raise PermissionDenied('Cannot attach files to this task.')
        file = self.request.FILES.get('file')
        if not file: raise PermissionDenied('A file is required.')
        serializer.save(task=task, uploaded_by=self.request.user, original_name=file.name)
