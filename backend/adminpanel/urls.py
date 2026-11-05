from django.urls import path

from . import views

app_name = 'adminpanel'

urlpatterns = [
    path('admin_login/', views.login_view, name='login'),
    path('admin_login/logout/', views.logout_view, name='logout'),
    path('admin_panel/', views.dashboard, name='dashboard'),

    path('admin_panel/users/', views.user_list, name='user_list'),
    path('admin_panel/users/add/', views.user_add, name='user_add'),
    path('admin_panel/users/<int:pk>/', views.user_detail, name='user_detail'),
    path('admin_panel/users/<int:pk>/edit/', views.user_edit, name='user_edit'),
    path('admin_panel/users/<int:pk>/block/', views.user_toggle_block, name='user_toggle_block'),
    path('admin_panel/users/<int:pk>/delete/', views.user_delete, name='user_delete'),

    path('admin_panel/tasks/', views.task_list, name='task_list'),
    path('admin_panel/tasks/add/', views.task_add, name='task_add'),
    path('admin_panel/tasks/<int:pk>/', views.task_detail, name='task_detail'),
    path('admin_panel/tasks/<int:pk>/delete/', views.task_delete, name='task_delete'),
    path('admin_panel/tasks/<int:pk>/do/<str:action>/', views.task_action, name='task_action'),
    path('admin_panel/tasks/<int:pk>/notes/add/', views.note_add, name='note_add'),
    path('admin_panel/tasks/<int:pk>/attachments/add/', views.attachment_upload, name='attachment_upload'),
    path('admin_panel/tasks/<int:pk>/checklist/add/', views.checklist_add, name='checklist_add'),
    path('admin_panel/tasks/<int:pk>/members/add/', views.member_add, name='member_add'),

    path('admin_panel/notes/<int:pk>/edit/', views.note_edit, name='note_edit'),
    path('admin_panel/notes/<int:pk>/delete/', views.note_delete, name='note_delete'),

    path('admin_panel/attachments/', views.attachment_list, name='attachment_list'),
    path('admin_panel/attachments/<int:pk>/edit/', views.attachment_edit, name='attachment_edit'),
    path('admin_panel/attachments/<int:pk>/delete/', views.attachment_delete, name='attachment_delete'),
    path('admin_panel/attachments/<int:pk>/download/', views.attachment_download, name='attachment_download'),

    path('admin_panel/checklist/<int:pk>/toggle/', views.checklist_toggle, name='checklist_toggle'),
    path('admin_panel/checklist/<int:pk>/delete/', views.checklist_delete, name='checklist_delete'),
    path('admin_panel/members/<int:pk>/delete/', views.member_delete, name='member_delete'),
    path('admin_panel/comments/<int:pk>/delete/', views.comment_delete, name='comment_delete'),
]
