from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import TaskViewSet, ChecklistItemViewSet

router = DefaultRouter()
router.register('tasks', TaskViewSet, basename='task')
router.register('checklist-items', ChecklistItemViewSet, basename='checklist-item')

urlpatterns = [
    path('', include(router.urls)),
]
