# Generated manually because the local virtual environment points to an unavailable Python interpreter.
from django.conf import settings
from django.core.validators import MinValueValidator
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('tasks', '0002_alter_task_options_task_category_task_due_date_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='Tag',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=50)),
                ('color', models.CharField(default='#6366F1', max_length=7)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='tags', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['name']},
        ),
        migrations.AddConstraint(model_name='tag', constraint=models.UniqueConstraint(fields=('owner', 'name'), name='unique_tag_name_per_owner')),
        migrations.AddField(model_name='task', name='archived', field=models.BooleanField(default=False)),
        migrations.AddField(model_name='task', name='reminder_minutes', field=models.IntegerField(blank=True, null=True, validators=[MinValueValidator(0)])),
        migrations.AddField(model_name='task', name='recurrence', field=models.CharField(choices=[('none', 'None'), ('daily', 'Daily'), ('weekly', 'Weekly'), ('monthly', 'Monthly')], default='none', max_length=20)),
        migrations.AddField(model_name='task', name='sort_order', field=models.IntegerField(default=0)),
        migrations.AddField(model_name='task', name='trashed_at', field=models.DateTimeField(blank=True, null=True)),
        migrations.AddField(model_name='task', name='tags', field=models.ManyToManyField(blank=True, related_name='tasks', to='tasks.tag')),
        migrations.CreateModel(
            name='TaskMember',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('role', models.CharField(choices=[('owner', 'Owner'), ('member', 'Member')], default='member', max_length=10)),
                ('joined_at', models.DateTimeField(auto_now_add=True)),
                ('task', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='memberships', to='tasks.task')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='shared_task_memberships', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.AddConstraint(model_name='taskmember', constraint=models.UniqueConstraint(fields=('task', 'user'), name='unique_task_member')),
        migrations.CreateModel(
            name='Attachment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('file', models.FileField(upload_to='task_attachments/%Y/%m/')),
                ('original_name', models.CharField(max_length=255)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('task', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='attachments', to='tasks.task')),
                ('uploaded_by', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='task_attachments', to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='TaskComment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('body', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('author', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='task_comments', to=settings.AUTH_USER_MODEL)),
                ('task', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='comments', to='tasks.task')),
            ],
        ),
        migrations.CreateModel(
            name='TaskActivity',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('action', models.CharField(max_length=100)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('actor', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, to=settings.AUTH_USER_MODEL)),
                ('task', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='activities', to='tasks.task')),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.AlterModelOptions(name='task', options={'ordering': ['sort_order', '-created_at']}),
    ]
