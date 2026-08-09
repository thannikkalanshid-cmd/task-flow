from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('tasks', '0003_task_productivity_and_collaboration'),
    ]

    operations = [
        migrations.CreateModel(
            name='TaskNote',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=200)),
                ('content', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('task', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='task_notes', to='tasks.task')),
            ],
            options={'ordering': ['-updated_at', '-created_at']},
        ),
    ]
