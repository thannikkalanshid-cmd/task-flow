from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import AttachmentViewSet, ChecklistItemViewSet, TagViewSet, TaskNoteViewSet, TaskViewSet

router = DefaultRouter()
router.register('tasks', TaskViewSet, basename='task')
router.register('checklist-items', ChecklistItemViewSet, basename='checklist-item')
router.register('tags', TagViewSet, basename='tag')
router.register('attachments', AttachmentViewSet, basename='attachment')
router.register('notes', TaskNoteViewSet, basename='note')

urlpatterns = [
    path('', include(router.urls)),
]
