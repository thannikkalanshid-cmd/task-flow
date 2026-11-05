import os
import shutil
import tempfile

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.urls import reverse

from tasks.models import Attachment, ChecklistItem, Task, TaskComment, TaskMember, TaskNote

User = get_user_model()
MEDIA = tempfile.mkdtemp()


@override_settings(MEDIA_ROOT=MEDIA, SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=['*'])
class AdminPanelTests(TestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(MEDIA, ignore_errors=True)

    def setUp(self):
        cache.clear()
        self.root = User.objects.create_superuser('root', 'root@x.com', 'RootPass#12345')
        self.staff = User.objects.create_user('staff', password='StaffPass#12345', is_staff=True)
        self.alice = User.objects.create_user('alice', 'alice@x.com', 'AlicePass#12345')
        self.bob = User.objects.create_user('bob', password='BobPass#12345')
        self.task = Task.objects.create(owner=self.alice, title='Write report')
        self.note = TaskNote.objects.create(task=self.task, title='Draft', content='hello')
        self.client.login(username='root', password='RootPass#12345')

    def upload(self, name='a.pdf', note=None, task=None):
        f = SimpleUploadedFile(name, b'%PDF-1.4 data', content_type='application/pdf')
        data = {'file': f}
        if note:
            data['note'] = note.pk
        return self.client.post(reverse('adminpanel:attachment_upload', args=[(task or self.task).pk]), data)

    # ------------------------------------------------------------ login / access
    def test_anonymous_redirected_to_login(self):
        self.client.logout()
        r = self.client.get('/admin_panel/users/')
        self.assertEqual(r.status_code, 302)
        self.assertTrue(r['Location'].startswith('/admin_login/?next='))

    def test_login_page_and_staff_login(self):
        self.client.logout()
        self.assertEqual(self.client.get('/admin_login/').status_code, 200)
        r = self.client.post('/admin_login/', {'username': 'staff', 'password': 'StaffPass#12345'})
        self.assertRedirects(r, '/admin_panel/', fetch_redirect_response=False)
        self.assertEqual(self.client.get('/admin_panel/').status_code, 200)

    def test_regular_user_cannot_sign_in(self):
        self.client.logout()
        r = self.client.post('/admin_login/', {'username': 'alice', 'password': 'AlicePass#12345'})
        self.assertEqual(r.status_code, 200)
        self.assertContains(r, 'no admin access')
        self.assertEqual(self.client.get('/admin_panel/').status_code, 302)

    def test_login_lockout_after_repeated_failures(self):
        self.client.logout()
        for _ in range(5):
            self.client.post('/admin_login/', {'username': 'root', 'password': 'wrong'})
        r = self.client.post('/admin_login/', {'username': 'root', 'password': 'RootPass#12345'})
        self.assertContains(r, 'Too many failed attempts')
        self.assertEqual(self.client.get('/admin_panel/').status_code, 302)

    def test_open_redirect_is_blocked(self):
        self.client.logout()
        r = self.client.post('/admin_login/', {'username': 'root', 'password': 'RootPass#12345',
                                               'next': 'https://evil.example/'})
        self.assertRedirects(r, '/admin_panel/', fetch_redirect_response=False)

    def test_logout_requires_post_and_ends_session(self):
        self.assertEqual(self.client.get('/admin_login/logout/').status_code, 405)
        self.client.post('/admin_login/logout/')
        self.assertEqual(self.client.get('/admin_panel/').status_code, 302)

    # ------------------------------------------------------------ pages render
    def test_all_pages_render(self):
        self.upload(note=self.note)
        att = Attachment.objects.get()
        pages = ['/admin_panel/', '/admin_panel/users/', '/admin_panel/users/add/',
                 f'/admin_panel/users/{self.alice.pk}/', f'/admin_panel/users/{self.alice.pk}/edit/',
                 '/admin_panel/tasks/', '/admin_panel/tasks/add/', f'/admin_panel/tasks/{self.task.pk}/',
                 f'/admin_panel/notes/{self.note.pk}/edit/', '/admin_panel/attachments/',
                 f'/admin_panel/attachments/{att.pk}/edit/',
                 f'/admin_panel/tasks/?owner={self.alice.pk}&status=pending&priority=medium&q=rep',
                 '/admin_panel/users/?status=blocked&q=al', '/admin_panel/attachments/?kind=note&q=a']
        for url in pages:
            self.assertEqual(self.client.get(url).status_code, 200, url)

    # ------------------------------------------------------------ users
    def test_add_edit_user_and_password(self):
        r = self.client.post('/admin_panel/users/add/', {
            'username': 'carol', 'email': 'c@x.com', 'password1': 'CarolPass#12345',
            'password2': 'CarolPass#12345', 'is_active': 'on'})
        carol = User.objects.get(username='carol')
        self.assertRedirects(r, f'/admin_panel/users/{carol.pk}/', fetch_redirect_response=False)
        self.assertTrue(carol.check_password('CarolPass#12345'))
        self.client.post(f'/admin_panel/users/{carol.pk}/edit/', {
            'username': 'carol2', 'email': 'c@x.com', 'is_active': 'on',
            'password1': 'NewPass#98765', 'password2': 'NewPass#98765'})
        carol.refresh_from_db()
        self.assertEqual(carol.username, 'carol2')
        self.assertTrue(carol.check_password('NewPass#98765'))

    def test_add_user_validation(self):
        r = self.client.post('/admin_panel/users/add/', {
            'username': 'dave', 'password1': 'abc', 'password2': 'xyz'})
        self.assertEqual(r.status_code, 200)
        self.assertFalse(User.objects.filter(username='dave').exists())

    def test_block_unblock_and_api_access(self):
        tok = self.client.post('/api/token/', {'username': 'alice', 'password': 'AlicePass#12345'},
                               content_type='application/json')
        self.assertEqual(tok.status_code, 200)
        access = tok.json()['access']
        auth = {'HTTP_AUTHORIZATION': 'Bearer ' + access}
        self.assertEqual(self.client.get('/api/tasks/', **auth).status_code, 200)

        self.client.post(f'/admin_panel/users/{self.alice.pk}/block/')
        self.alice.refresh_from_db()
        self.assertFalse(self.alice.is_active)
        # existing token is rejected and a new login fails
        self.assertEqual(self.client.get('/api/tasks/', **auth).status_code, 401)
        relog = self.client.post('/api/token/', {'username': 'alice', 'password': 'AlicePass#12345'},
                                 content_type='application/json')
        self.assertEqual(relog.status_code, 401)

        self.client.post(f'/admin_panel/users/{self.alice.pk}/block/')
        self.alice.refresh_from_db()
        self.assertTrue(self.alice.is_active)
        self.assertEqual(self.client.get('/api/tasks/', **auth).status_code, 200)

    def test_cannot_block_or_delete_self(self):
        self.client.post(f'/admin_panel/users/{self.root.pk}/block/')
        self.client.post(f'/admin_panel/users/{self.root.pk}/delete/')
        self.root.refresh_from_db()
        self.assertTrue(self.root.is_active)
        self.assertTrue(User.objects.filter(pk=self.root.pk).exists())

    def test_staff_cannot_manage_other_admins(self):
        self.client.logout()
        self.client.login(username='staff', password='StaffPass#12345')
        self.client.post(f'/admin_panel/users/{self.root.pk}/block/')
        self.client.post(f'/admin_panel/users/{self.root.pk}/delete/')
        self.root.refresh_from_db()
        self.assertTrue(self.root.is_active)
        self.assertTrue(User.objects.filter(pk=self.root.pk).exists())
        self.assertRedirects(self.client.get(f'/admin_panel/users/{self.root.pk}/edit/'),
                             f'/admin_panel/users/{self.root.pk}/', fetch_redirect_response=False)

    def test_only_superuser_can_grant_staff(self):
        self.assertContains(self.client.get('/admin_panel/users/add/'), 'name="is_staff"')
        self.client.logout()
        self.client.login(username='staff', password='StaffPass#12345')
        self.assertNotContains(self.client.get('/admin_panel/users/add/'), 'name="is_staff"')
        self.client.post(f'/admin_panel/users/{self.bob.pk}/edit/', {
            'username': 'bob', 'is_active': 'on', 'is_staff': 'on'})
        self.bob.refresh_from_db()
        self.assertFalse(self.bob.is_staff)

    def test_delete_user_removes_data_and_files(self):
        self.upload(note=self.note)
        path = Attachment.objects.get().file.path
        self.assertTrue(os.path.exists(path))
        self.client.post(f'/admin_panel/users/{self.alice.pk}/delete/')
        self.assertFalse(User.objects.filter(pk=self.alice.pk).exists())
        self.assertEqual(Task.objects.count(), 0)
        self.assertEqual(Attachment.objects.count(), 0)
        self.assertFalse(os.path.exists(path))

    def test_get_does_not_trigger_destructive_actions(self):
        self.assertEqual(self.client.get(f'/admin_panel/users/{self.alice.pk}/delete/').status_code, 405)
        self.assertEqual(self.client.get(f'/admin_panel/users/{self.alice.pk}/block/').status_code, 405)
        self.assertEqual(self.client.get(f'/admin_panel/tasks/{self.task.pk}/delete/').status_code, 405)

    # ------------------------------------------------------------ tasks
    def test_task_crud_and_actions(self):
        r = self.client.post('/admin_panel/tasks/add/', {
            'owner': self.bob.pk, 'title': 'Admin made', 'priority': 'high', 'recurrence': 'none',
            'category': 'General', 'due_date': '2026-12-01', 'due_time': '09:30'})
        t = Task.objects.get(title='Admin made')
        self.assertRedirects(r, f'/admin_panel/tasks/{t.pk}/', fetch_redirect_response=False)
        self.assertEqual(t.owner, self.bob)
        self.client.post(f'/admin_panel/tasks/{t.pk}/', {
            'owner': self.bob.pk, 'title': 'Renamed', 'priority': 'low', 'recurrence': 'daily',
            'category': 'Work', 'completed': 'on'})
        t.refresh_from_db()
        self.assertEqual((t.title, t.priority, t.completed), ('Renamed', 'low', True))
        for action, field, expect in [('archive', 'archived', True), ('unarchive', 'archived', False),
                                      ('reopen', 'completed', False), ('complete', 'completed', True)]:
            self.client.post(f'/admin_panel/tasks/{t.pk}/do/{action}/')
            t.refresh_from_db()
            self.assertEqual(getattr(t, field), expect, action)
        self.client.post(f'/admin_panel/tasks/{t.pk}/do/trash/')
        t.refresh_from_db()
        self.assertIsNotNone(t.trashed_at)
        self.client.post(f'/admin_panel/tasks/{t.pk}/do/restore/')
        t.refresh_from_db()
        self.assertIsNone(t.trashed_at)
        self.assertEqual(self.client.post(f'/admin_panel/tasks/{t.pk}/do/explode/').status_code, 404)
        self.client.post(f'/admin_panel/tasks/{t.pk}/delete/')
        self.assertFalse(Task.objects.filter(pk=t.pk).exists())

    def test_task_list_filters(self):
        Task.objects.create(owner=self.bob, title='Done one', completed=True, priority='high')
        r = self.client.get('/admin_panel/tasks/?status=completed')
        self.assertContains(r, 'Done one')
        self.assertNotContains(r, 'Write report')
        r = self.client.get(f'/admin_panel/tasks/?owner={self.alice.pk}')
        self.assertContains(r, 'Write report')
        self.assertNotContains(r, 'Done one')

    # ------------------------------------------------------------ notes
    def test_note_add_edit_delete(self):
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/notes/add/', {'title': 'N2', 'content': 'body'})
        n2 = TaskNote.objects.get(title='N2')
        self.client.post(f'/admin_panel/notes/{n2.pk}/edit/', {'title': 'N2b', 'content': 'new'})
        n2.refresh_from_db()
        self.assertEqual((n2.title, n2.content), ('N2b', 'new'))
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/notes/add/', {'title': '', 'content': ''})
        self.assertEqual(TaskNote.objects.filter(task=self.task).count(), 2)
        self.client.post(f'/admin_panel/notes/{n2.pk}/delete/')
        self.assertFalse(TaskNote.objects.filter(pk=n2.pk).exists())

    def test_deleting_note_removes_its_files(self):
        self.upload(note=self.note)
        path = Attachment.objects.get().file.path
        self.client.post(f'/admin_panel/notes/{self.note.pk}/delete/')
        self.assertEqual(Attachment.objects.count(), 0)
        self.assertFalse(os.path.exists(path))

    # ------------------------------------------------------------ attachments
    def test_upload_to_task_and_note(self):
        self.upload()
        self.upload('n.pdf', note=self.note)
        files = {a.original_name: a for a in Attachment.objects.all()}
        self.assertIsNone(files['a.pdf'].note)
        self.assertEqual(files['n.pdf'].note, self.note)
        self.assertEqual(files['a.pdf'].uploaded_by, self.root)

    def test_upload_rejects_disallowed_type(self):
        f = SimpleUploadedFile('evil.html', b'<script>alert(1)</script>', content_type='text/html')
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/attachments/add/', {'file': f})
        self.assertEqual(Attachment.objects.count(), 0)

    def test_note_from_other_task_rejected(self):
        other = Task.objects.create(owner=self.bob, title='Other')
        foreign = TaskNote.objects.create(task=other, title='x', content='y')
        self.upload(note=foreign)
        self.assertEqual(Attachment.objects.count(), 0)

    def test_rename_and_replace_attachment(self):
        self.upload()
        att = Attachment.objects.get()
        old_path = att.file.path
        self.client.post(f'/admin_panel/attachments/{att.pk}/edit/', {'original_name': 'renamed.pdf'})
        att.refresh_from_db()
        self.assertEqual(att.original_name, 'renamed.pdf')
        self.assertTrue(os.path.exists(old_path))
        new = SimpleUploadedFile('fresh.png', b'\x89PNG data', content_type='image/png')
        self.client.post(f'/admin_panel/attachments/{att.pk}/edit/', {'original_name': 'renamed.pdf', 'file': new})
        att.refresh_from_db()
        self.assertTrue(att.file.name.endswith('.png'))
        self.assertFalse(os.path.exists(old_path))
        self.assertTrue(os.path.exists(att.file.path))

    def test_delete_attachment_removes_file(self):
        self.upload()
        att = Attachment.objects.get()
        path = att.file.path
        self.client.post(f'/admin_panel/attachments/{att.pk}/delete/')
        self.assertEqual(Attachment.objects.count(), 0)
        self.assertFalse(os.path.exists(path))

    def test_download_is_safe(self):
        self.upload()
        att = Attachment.objects.get()
        r = self.client.get(f'/admin_panel/attachments/{att.pk}/download/')
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r['Content-Disposition'].startswith('inline'))
        self.assertEqual(r['Content-Type'], 'application/pdf')
        r = self.client.get(f'/admin_panel/attachments/{att.pk}/download/?download=1')
        self.assertTrue(r['Content-Disposition'].startswith('attachment'))
        # A script-capable file that slipped in through the public API is always forced to download.
        att2 = Attachment.objects.create(task=self.task, uploaded_by=self.bob, original_name='x.html',
                                         file=SimpleUploadedFile('x.html', b'<script>1</script>'))
        r = self.client.get(f'/admin_panel/attachments/{att2.pk}/download/')
        self.assertTrue(r['Content-Disposition'].startswith('attachment'))
        self.assertEqual(r['Content-Type'], 'application/octet-stream')

    def test_missing_file_is_handled(self):
        self.upload()
        att = Attachment.objects.get()
        os.remove(att.file.path)
        self.assertEqual(self.client.get(f'/admin_panel/attachments/{att.pk}/download/').status_code, 404)
        self.assertContains(self.client.get('/admin_panel/attachments/'), 'missing')
        self.assertEqual(self.client.get('/admin_panel/').status_code, 200)

    # ------------------------------------------------------------ checklist / members / comments
    def test_checklist_members_comments(self):
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/checklist/add/', {'title': 'step'})
        item = ChecklistItem.objects.get()
        self.client.post(f'/admin_panel/checklist/{item.pk}/toggle/')
        item.refresh_from_db()
        self.assertTrue(item.completed)
        self.client.post(f'/admin_panel/checklist/{item.pk}/delete/')
        self.assertEqual(ChecklistItem.objects.count(), 0)

        self.client.post(f'/admin_panel/tasks/{self.task.pk}/members/add/', {'username': 'bob'})
        m = TaskMember.objects.get()
        self.assertEqual(m.user, self.bob)
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/members/add/', {'username': 'alice'})  # owner
        self.client.post(f'/admin_panel/tasks/{self.task.pk}/members/add/', {'username': 'nobody'})
        self.assertEqual(TaskMember.objects.count(), 1)
        self.client.post(f'/admin_panel/members/{m.pk}/delete/')
        self.assertEqual(TaskMember.objects.count(), 0)

        c = TaskComment.objects.create(task=self.task, author=self.bob, body='hi')
        self.assertContains(self.client.get(f'/admin_panel/tasks/{self.task.pk}/'), 'hi')
        self.client.post(f'/admin_panel/comments/{c.pk}/delete/')
        self.assertEqual(TaskComment.objects.count(), 0)
