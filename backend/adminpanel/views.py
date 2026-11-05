import mimetypes
from functools import wraps
from urllib.parse import quote

from django.contrib import messages
from django.contrib.auth import authenticate, get_user_model, login, logout
from django.core.cache import cache
from django.core.files.storage import default_storage
from django.core.paginator import Paginator
from django.db.models import Count, Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.utils import timezone
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.cache import never_cache
from django.views.decorators.http import require_POST

from tasks.models import Attachment, ChecklistItem, Task, TaskActivity, TaskComment, TaskMember, TaskNote

from .forms import (AttachmentEditForm, AttachmentUploadForm, NoteForm, TaskForm, UserForm)

User = get_user_model()

MAX_LOGIN_ATTEMPTS = 5
LOCKOUT_SECONDS = 300
# Only these types are shown in the browser; everything else is forced to download,
# so an uploaded .html/.svg can never run inside the admin's session.
INLINE_TYPES = {'image/png', 'image/jpeg', 'image/gif', 'image/webp', 'application/pdf',
                'audio/mpeg', 'audio/wav', 'video/mp4'}


# ---------------------------------------------------------------- helpers

def staff_required(view):
    @wraps(view)
    def wrapper(request, *args, **kwargs):
        u = request.user
        if not (u.is_authenticated and u.is_active and u.is_staff):
            return redirect('%s?next=%s' % (reverse('adminpanel:login'), quote(request.get_full_path())))
        return never_cache(view)(request, *args, **kwargs)
    return wrapper


def _bind(request):
    return (request.POST, request.FILES) if request.method == 'POST' else (None, None)


def _page(request, qs, per_page=20):
    page = Paginator(qs, per_page).get_page(request.GET.get('page'))
    params = request.GET.copy()
    params.pop('page', None)
    return page, params.urlencode()


def _back(request, default):
    target = request.POST.get('next') or request.GET.get('next')
    if target and url_has_allowed_host_and_scheme(target, {request.get_host()}, request.is_secure()):
        return redirect(target)
    return redirect(default)


def _guard(request, target, allow_self=True):
    """Return an error message if the acting admin may not manage `target`."""
    me = request.user
    if target.pk == me.pk:
        return None if allow_self else "You can't do that to your own account."
    if (target.is_superuser or target.is_staff) and not me.is_superuser:
        return 'Only superusers can manage other admin accounts.'
    return None


def _delete_files(names):
    for name in names:
        if name:
            try:
                default_storage.delete(name)
            except Exception:
                pass


def _log(task, user, text):
    TaskActivity.objects.create(task=task, actor=user, action=('admin: ' + text)[:100])


def _size(attachment):
    try:
        return attachment.file.size
    except Exception:
        return None


def _with_sizes(attachments):
    for a in attachments:
        a.size = _size(a)
    return attachments


# ---------------------------------------------------------------- auth

@never_cache
def login_view(request):
    u = request.user
    if u.is_authenticated and u.is_active and u.is_staff:
        return redirect('adminpanel:dashboard')
    error = None
    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        key = 'adminpanel-login:%s:%s' % (request.META.get('REMOTE_ADDR', ''), username.lower())
        attempts = cache.get(key, 0)
        if attempts >= MAX_LOGIN_ATTEMPTS:
            error = 'Too many failed attempts. Try again in a few minutes.'
        else:
            user = authenticate(request, username=username, password=request.POST.get('password', ''))
            if user is not None and user.is_staff:
                cache.delete(key)
                login(request, user)
                target = request.POST.get('next') or request.GET.get('next')
                if target and url_has_allowed_host_and_scheme(target, {request.get_host()}, request.is_secure()):
                    return redirect(target)
                return redirect('adminpanel:dashboard')
            cache.set(key, attempts + 1, LOCKOUT_SECONDS)
            error = 'Invalid credentials, or this account has no admin access.'
    return render(request, 'adminpanel/login.html',
                  {'error': error, 'next': request.GET.get('next', '')})


@require_POST
def logout_view(request):
    logout(request)
    return redirect('adminpanel:login')


# ---------------------------------------------------------------- dashboard

@staff_required
def dashboard(request):
    live_tasks = Task.objects.filter(trashed_at__isnull=True)
    storage = sum((_size(a) or 0) for a in Attachment.objects.only('file').iterator())
    stats = {
        'users': User.objects.count(),
        'active_users': User.objects.filter(is_active=True).count(),
        'blocked_users': User.objects.filter(is_active=False).count(),
        'staff_users': User.objects.filter(is_staff=True).count(),
        'tasks': live_tasks.count(),
        'completed': live_tasks.filter(completed=True).count(),
        'archived': live_tasks.filter(archived=True).count(),
        'trashed': Task.objects.filter(trashed_at__isnull=False).count(),
        'notes': TaskNote.objects.count(),
        'attachments': Attachment.objects.count(),
        'storage': storage,
        'comments': TaskComment.objects.count(),
    }
    return render(request, 'adminpanel/dashboard.html', {
        'stats': stats,
        'recent_users': User.objects.order_by('-date_joined')[:6],
        'recent_tasks': Task.objects.select_related('owner').order_by('-created_at')[:8],
        'recent_files': _with_sizes(list(Attachment.objects.select_related('task', 'uploaded_by', 'note')
                                         .order_by('-created_at')[:6])),
    })


# ---------------------------------------------------------------- users

@staff_required
def user_list(request):
    qs = User.objects.annotate(task_count=Count('tasks', distinct=True)).order_by('-date_joined')
    q = request.GET.get('q', '').strip()
    if q:
        qs = qs.filter(Q(username__icontains=q) | Q(email__icontains=q) |
                       Q(first_name__icontains=q) | Q(last_name__icontains=q))
    status = request.GET.get('status', '')
    if status == 'active':
        qs = qs.filter(is_active=True)
    elif status == 'blocked':
        qs = qs.filter(is_active=False)
    elif status == 'staff':
        qs = qs.filter(is_staff=True)
    page, qstr = _page(request, qs)
    return render(request, 'adminpanel/user_list.html', {'page': page, 'qstr': qstr, 'q': q, 'status': status})


@staff_required
def user_add(request):
    form = UserForm(*_bind(request), acting_user=request.user)
    if request.method == 'POST' and form.is_valid():
        user = form.save()
        messages.success(request, 'User "%s" created.' % user.username)
        return redirect('adminpanel:user_detail', pk=user.pk)
    return render(request, 'adminpanel/form.html', {
        'title': 'Add user', 'form': form, 'cancel_url': reverse('adminpanel:user_list'),
        'submit_label': 'Create user'})


@staff_required
def user_detail(request, pk):
    target = get_object_or_404(User, pk=pk)
    files = Attachment.objects.filter(Q(task__owner=target) | Q(uploaded_by=target)) \
        .select_related('task', 'note', 'uploaded_by').distinct().order_by('-created_at')
    return render(request, 'adminpanel/user_detail.html', {
        'target': target,
        'tasks': Task.objects.filter(owner=target).annotate(
            note_count=Count('task_notes', distinct=True)).order_by('-created_at')[:10],
        'task_total': Task.objects.filter(owner=target).count(),
        'shared_total': TaskMember.objects.filter(user=target).count(),
        'files': _with_sizes(list(files[:50])),
        'file_total': files.count(),
        'locked': _guard(request, target) is not None,
    })


@staff_required
def user_edit(request, pk):
    target = get_object_or_404(User, pk=pk)
    err = _guard(request, target)
    if err:
        messages.error(request, err)
        return redirect('adminpanel:user_detail', pk=pk)
    form = UserForm(*_bind(request), instance=target, acting_user=request.user)
    if request.method == 'POST' and form.is_valid():
        form.save()
        messages.success(request, 'User "%s" updated.' % target.username)
        return redirect('adminpanel:user_detail', pk=pk)
    return render(request, 'adminpanel/form.html', {
        'title': 'Edit user: %s' % target.username, 'form': form,
        'cancel_url': reverse('adminpanel:user_detail', args=[pk])})


@staff_required
@require_POST
def user_toggle_block(request, pk):
    target = get_object_or_404(User, pk=pk)
    err = _guard(request, target, allow_self=False)
    if err:
        messages.error(request, err)
    else:
        target.is_active = not target.is_active
        target.save(update_fields=['is_active'])
        messages.success(request, '%s has been %s.' % (
            target.username, 'unblocked' if target.is_active else 'blocked. They are signed out of the app'))
    return _back(request, reverse('adminpanel:user_detail', args=[pk]))


@staff_required
@require_POST
def user_delete(request, pk):
    target = get_object_or_404(User, pk=pk)
    err = _guard(request, target, allow_self=False)
    if not err and target.is_superuser and User.objects.filter(is_superuser=True).count() <= 1:
        err = "You can't delete the last superuser."
    if err:
        messages.error(request, err)
        return redirect('adminpanel:user_detail', pk=pk)
    names = list(Attachment.objects.filter(Q(task__owner=target) | Q(uploaded_by=target))
                 .values_list('file', flat=True))
    if target.profile_image:
        names.append(target.profile_image.name)
    username = target.username
    target.delete()
    _delete_files(names)
    messages.success(request, 'User "%s" and all their data were deleted.' % username)
    return redirect('adminpanel:user_list')


# ---------------------------------------------------------------- tasks

TASK_STATUS = {
    'pending': {'completed': False, 'trashed_at__isnull': True},
    'completed': {'completed': True, 'trashed_at__isnull': True},
    'archived': {'archived': True, 'trashed_at__isnull': True},
    'trashed': {'trashed_at__isnull': False},
}


@staff_required
def task_list(request):
    qs = Task.objects.select_related('owner').annotate(
        note_count=Count('task_notes', distinct=True),
        file_count=Count('attachments', distinct=True)).order_by('-created_at')
    q = request.GET.get('q', '').strip()
    if q:
        qs = qs.filter(Q(title__icontains=q) | Q(description__icontains=q) | Q(owner__username__icontains=q))
    owner = request.GET.get('owner', '')
    owner_user = None
    if owner.isdigit():
        qs = qs.filter(owner_id=owner)
        owner_user = User.objects.filter(pk=owner).first()
    status = request.GET.get('status', '')
    if status in TASK_STATUS:
        qs = qs.filter(**TASK_STATUS[status])
    priority = request.GET.get('priority', '')
    if priority in ('low', 'medium', 'high'):
        qs = qs.filter(priority=priority)
    page, qstr = _page(request, qs)
    return render(request, 'adminpanel/task_list.html', {
        'page': page, 'qstr': qstr, 'q': q, 'status': status, 'priority': priority,
        'owner': owner if owner_user else '', 'owner_user': owner_user,
        'status_options': [('pending', 'Pending'), ('completed', 'Completed'),
                           ('archived', 'Archived'), ('trashed', 'In trash')]})


@staff_required
def task_add(request):
    initial = {}
    if request.GET.get('owner', '').isdigit():
        initial['owner'] = request.GET['owner']
    data, files = _bind(request)
    form = TaskForm(data, initial=initial)
    if request.method == 'POST' and form.is_valid():
        task = form.save()
        _log(task, request.user, 'created this task')
        messages.success(request, 'Task created.')
        return redirect('adminpanel:task_detail', pk=task.pk)
    return render(request, 'adminpanel/form.html', {
        'title': 'Add task', 'form': form, 'cancel_url': reverse('adminpanel:task_list'),
        'submit_label': 'Create task'})


@staff_required
def task_detail(request, pk):
    task = get_object_or_404(Task.objects.select_related('owner'), pk=pk)
    data, _ = _bind(request)
    form = TaskForm(data, instance=task)
    if request.method == 'POST' and form.is_valid():
        form.save()
        _log(task, request.user, 'edited this task')
        messages.success(request, 'Task saved.')
        return redirect('adminpanel:task_detail', pk=pk)
    return render(request, 'adminpanel/task_detail.html', {
        'task': task, 'form': form,
        'notes': task.task_notes.annotate(file_count=Count('attachments')),
        'files': _with_sizes(list(task.attachments.select_related('note', 'uploaded_by', 'task')
                                  .order_by('-created_at'))),
        'upload_form': AttachmentUploadForm(task=task),
        'checklist': task.checklist_items.all(),
        'members': task.memberships.select_related('user'),
        'comments': task.comments.select_related('author').order_by('-created_at'),
        'activities': task.activities.select_related('actor')[:15],
    })


@staff_required
@require_POST
def task_action(request, pk, action):
    task = get_object_or_404(Task, pk=pk)
    changes = {
        'archive': {'archived': True}, 'unarchive': {'archived': False},
        'trash': {'trashed_at': timezone.now()}, 'restore': {'trashed_at': None},
        'complete': {'completed': True}, 'reopen': {'completed': False},
    }.get(action)
    if changes is None:
        raise Http404
    for field, value in changes.items():
        setattr(task, field, value)
    task.save(update_fields=list(changes) + ['updated_at'])
    _log(task, request.user, '%sd this task' % action if action.endswith('e') else '%sed this task' % action)
    messages.success(request, 'Task updated (%s).' % action)
    return _back(request, reverse('adminpanel:task_detail', args=[pk]))


@staff_required
@require_POST
def task_delete(request, pk):
    task = get_object_or_404(Task, pk=pk)
    names = list(task.attachments.values_list('file', flat=True))
    title = task.title
    task.delete()
    _delete_files(names)
    messages.success(request, 'Task "%s" was permanently deleted.' % title)
    return _back(request, reverse('adminpanel:task_list'))


# ---------------------------------------------------------------- notes

@staff_required
@require_POST
def note_add(request, pk):
    task = get_object_or_404(Task, pk=pk)
    form = NoteForm(request.POST)
    if form.is_valid():
        note = form.save(commit=False)
        note.task = task
        note.save()
        _log(task, request.user, 'added a note')
        messages.success(request, 'Note added.')
    else:
        messages.error(request, 'A note needs both a title and content.')
    return redirect('adminpanel:task_detail', pk=pk)


@staff_required
def note_edit(request, pk):
    note = get_object_or_404(TaskNote.objects.select_related('task'), pk=pk)
    data, _ = _bind(request)
    form = NoteForm(data, instance=note)
    if request.method == 'POST' and form.is_valid():
        form.save()
        _log(note.task, request.user, 'edited a note')
        messages.success(request, 'Note saved.')
        return redirect('adminpanel:task_detail', pk=note.task_id)
    return render(request, 'adminpanel/form.html', {
        'title': 'Edit note', 'form': form,
        'cancel_url': reverse('adminpanel:task_detail', args=[note.task_id])})


@staff_required
@require_POST
def note_delete(request, pk):
    note = get_object_or_404(TaskNote.objects.select_related('task'), pk=pk)
    task = note.task
    names = list(note.attachments.values_list('file', flat=True))
    note.delete()
    _delete_files(names)
    _log(task, request.user, 'deleted a note')
    messages.success(request, 'Note and its attachments were deleted.')
    return redirect('adminpanel:task_detail', pk=task.pk)


# ---------------------------------------------------------------- attachments

@staff_required
def attachment_list(request):
    qs = Attachment.objects.select_related('task', 'task__owner', 'note', 'uploaded_by').order_by('-created_at')
    q = request.GET.get('q', '').strip()
    if q:
        qs = qs.filter(Q(original_name__icontains=q) | Q(task__title__icontains=q) |
                       Q(uploaded_by__username__icontains=q) | Q(task__owner__username__icontains=q))
    kind = request.GET.get('kind', '')
    if kind == 'note':
        qs = qs.filter(note__isnull=False)
    elif kind == 'task':
        qs = qs.filter(note__isnull=True)
    page, qstr = _page(request, qs)
    _with_sizes(page.object_list)
    return render(request, 'adminpanel/attachment_list.html',
                  {'page': page, 'qstr': qstr, 'q': q, 'kind': kind})


@staff_required
@require_POST
def attachment_upload(request, pk):
    task = get_object_or_404(Task, pk=pk)
    form = AttachmentUploadForm(request.POST, request.FILES, task=task)
    if form.is_valid():
        upload = form.cleaned_data['file']
        Attachment.objects.create(task=task, note=form.cleaned_data['note'], uploaded_by=request.user,
                                  file=upload, original_name=upload.name[:255])
        _log(task, request.user, 'added an attachment')
        messages.success(request, 'File uploaded.')
    else:
        messages.error(request, ' '.join(str(e) for errs in form.errors.values() for e in errs))
    return redirect('adminpanel:task_detail', pk=pk)


@staff_required
def attachment_edit(request, pk):
    att = get_object_or_404(Attachment.objects.select_related('task'), pk=pk)
    form = AttachmentEditForm(*_bind(request), instance=att)
    if request.method == 'POST' and form.is_valid():
        form.save()
        _log(att.task, request.user, 'edited an attachment')
        messages.success(request, 'Attachment updated.')
        return _back(request, reverse('adminpanel:task_detail', args=[att.task_id]))
    return render(request, 'adminpanel/form.html', {
        'title': 'Edit attachment', 'form': form,
        'cancel_url': reverse('adminpanel:task_detail', args=[att.task_id])})


@staff_required
@require_POST
def attachment_delete(request, pk):
    att = get_object_or_404(Attachment.objects.select_related('task'), pk=pk)
    task, name, stored = att.task, att.original_name, att.file.name
    att.delete()
    _delete_files([stored])
    _log(task, request.user, 'removed an attachment')
    messages.success(request, 'Attachment "%s" was removed.' % name)
    return _back(request, reverse('adminpanel:attachment_list'))


@staff_required
def attachment_download(request, pk):
    att = get_object_or_404(Attachment, pk=pk)
    try:
        handle = att.file.open('rb')
    except (FileNotFoundError, ValueError):
        raise Http404('This file is missing from storage.')
    ctype = mimetypes.guess_type(att.original_name)[0] or 'application/octet-stream'
    inline = ctype in INLINE_TYPES and request.GET.get('download') != '1'
    return FileResponse(handle, as_attachment=not inline, filename=att.original_name,
                        content_type=ctype if inline else 'application/octet-stream')


# ---------------------------------------------------------------- checklist / members / comments

@staff_required
@require_POST
def checklist_add(request, pk):
    task = get_object_or_404(Task, pk=pk)
    title = request.POST.get('title', '').strip()[:255]
    if title:
        ChecklistItem.objects.create(task=task, title=title, order=task.checklist_items.count())
        messages.success(request, 'Checklist item added.')
    else:
        messages.error(request, 'Checklist item needs a title.')
    return redirect('adminpanel:task_detail', pk=pk)


@staff_required
@require_POST
def checklist_toggle(request, pk):
    item = get_object_or_404(ChecklistItem, pk=pk)
    item.completed = not item.completed
    item.save(update_fields=['completed', 'updated_at'])
    return redirect('adminpanel:task_detail', pk=item.task_id)


@staff_required
@require_POST
def checklist_delete(request, pk):
    item = get_object_or_404(ChecklistItem, pk=pk)
    task_id = item.task_id
    item.delete()
    messages.success(request, 'Checklist item deleted.')
    return redirect('adminpanel:task_detail', pk=task_id)


@staff_required
@require_POST
def member_add(request, pk):
    task = get_object_or_404(Task, pk=pk)
    user = User.objects.filter(username=request.POST.get('username', '').strip()).first()
    if not user:
        messages.error(request, 'No user with that username.')
    elif user.pk == task.owner_id:
        messages.error(request, 'That user already owns this task.')
    else:
        _, created = TaskMember.objects.get_or_create(task=task, user=user, defaults={'role': 'member'})
        messages.success(request, '%s %s.' % (user.username, 'added to the task' if created else 'is already a member'))
    return redirect('adminpanel:task_detail', pk=pk)


@staff_required
@require_POST
def member_delete(request, pk):
    member = get_object_or_404(TaskMember, pk=pk)
    task_id = member.task_id
    member.delete()
    messages.success(request, 'Member removed.')
    return redirect('adminpanel:task_detail', pk=task_id)


@staff_required
@require_POST
def comment_delete(request, pk):
    comment = get_object_or_404(TaskComment, pk=pk)
    task_id = comment.task_id
    comment.delete()
    messages.success(request, 'Comment deleted.')
    return redirect('adminpanel:task_detail', pk=task_id)
