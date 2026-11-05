import os

from django import forms
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.files.storage import default_storage

from tasks.models import Attachment, Task, TaskNote

User = get_user_model()

# Same list the mobile app allows.
ALLOWED_EXTENSIONS = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'pdf', 'doc', 'docx',
                      'xls', 'xlsx', 'zip', 'mp4', 'mov', 'mp3', 'wav'}


def check_extension(upload):
    ext = os.path.splitext(upload.name)[1].lower().lstrip('.')
    if ext not in ALLOWED_EXTENSIONS:
        raise forms.ValidationError(
            'File type ".%s" is not allowed. Allowed: %s.' % (ext or '?', ', '.join(sorted(ALLOWED_EXTENSIONS))))
    return upload


class UserForm(forms.ModelForm):
    password1 = forms.CharField(label='Password', required=False,
                                widget=forms.PasswordInput(attrs={'autocomplete': 'new-password'}))
    password2 = forms.CharField(label='Confirm password', required=False,
                                widget=forms.PasswordInput(attrs={'autocomplete': 'new-password'}))

    class Meta:
        model = User
        fields = ('username', 'email', 'first_name', 'last_name', 'bio', 'profile_image', 'is_active', 'is_staff')
        labels = {'is_active': 'Active (untick to block this user)',
                  'is_staff': 'Can sign in to this admin panel (staff)'}
        widgets = {'bio': forms.Textarea(attrs={'rows': 3})}

    def __init__(self, *args, acting_user, **kwargs):
        super().__init__(*args, **kwargs)
        self.is_new = self.instance.pk is None
        self._old_image = '' if self.is_new else (self.instance.profile_image.name or '')
        editing_self = not self.is_new and self.instance.pk == acting_user.pk
        # Only superusers may grant panel access, and nobody can lock themselves out.
        if not acting_user.is_superuser or editing_self:
            self.fields.pop('is_staff')
        if editing_self:
            self.fields.pop('is_active')
        if self.is_new:
            self.fields['password1'].required = True
            self.fields['password2'].required = True
        else:
            self.fields['password1'].label = 'New password'
            self.fields['password1'].help_text = 'Leave blank to keep the current password.'

    def clean(self):
        data = super().clean()
        p1, p2 = data.get('password1'), data.get('password2')
        if p1 or p2:
            if p1 != p2:
                self.add_error('password2', 'Passwords do not match.')
            else:
                try:
                    validate_password(p1, self.instance)
                except forms.ValidationError as exc:
                    self.add_error('password1', exc)
        return data

    def save(self, commit=True):
        user = super().save(commit=False)
        if self.cleaned_data.get('password1'):
            user.set_password(self.cleaned_data['password1'])
        if commit:
            user.save()
            if self._old_image and self._old_image != (user.profile_image.name or ''):
                default_storage.delete(self._old_image)
        return user


class TaskForm(forms.ModelForm):
    class Meta:
        model = Task
        fields = ('owner', 'title', 'description', 'category', 'priority', 'due_date', 'due_time',
                  'completed', 'archived', 'recurrence', 'reminder_minutes')
        widgets = {
            'due_date': forms.DateInput(attrs={'type': 'date'}, format='%Y-%m-%d'),
            'due_time': forms.TimeInput(attrs={'type': 'time'}, format='%H:%M'),
            'description': forms.Textarea(attrs={'rows': 4}),
        }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['owner'].queryset = User.objects.order_by('username')


class NoteForm(forms.ModelForm):
    class Meta:
        model = TaskNote
        fields = ('title', 'content')
        widgets = {'content': forms.Textarea(attrs={'rows': 8})}


class AttachmentUploadForm(forms.Form):
    file = forms.FileField()
    note = forms.ModelChoiceField(queryset=TaskNote.objects.none(), required=False,
                                  empty_label='Task itself (not tied to a note)')

    def __init__(self, *args, task, **kwargs):
        super().__init__(*args, **kwargs)
        self.fields['note'].queryset = task.task_notes.all()

    def clean_file(self):
        return check_extension(self.cleaned_data['file'])


class AttachmentEditForm(forms.ModelForm):
    class Meta:
        model = Attachment
        fields = ('original_name', 'note', 'file')
        labels = {'original_name': 'File name', 'note': 'Attached to note', 'file': 'Replace file'}

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._old_file = self.instance.file.name
        self.fields['note'].queryset = self.instance.task.task_notes.all()
        self.fields['note'].empty_label = 'Task itself (not tied to a note)'

    def clean_file(self):
        upload = self.cleaned_data['file']
        if 'file' in self.changed_data:
            check_extension(upload)
        return upload

    def save(self, commit=True):
        obj = super().save(commit=False)
        if 'file' in self.changed_data and 'original_name' not in self.changed_data:
            obj.original_name = os.path.basename(self.cleaned_data['file'].name)[:255]
        if commit:
            obj.save()
            if self._old_file and self._old_file != obj.file.name:
                default_storage.delete(self._old_file)
        return obj
