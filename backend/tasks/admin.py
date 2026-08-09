from django.contrib import admin
from .models import Attachment, Tag, Task, TaskComment, TaskMember, TaskNote


@admin.register(Task)
class TaskAdmin(admin.ModelAdmin):
    list_display = ('title', 'owner', 'completed', 'archived', 'created_at')
    list_filter = ('completed',)
    search_fields = ('title', 'description', 'owner__username')


admin.site.register(Tag)
admin.site.register(Attachment)
admin.site.register(TaskMember)
admin.site.register(TaskComment)
admin.site.register(TaskNote)
