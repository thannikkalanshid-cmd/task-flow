from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0002_customuser_profile_image'),
    ]

    operations = [
        migrations.AddField(
            model_name='customuser',
            name='email_otp_attempts',
            field=models.PositiveSmallIntegerField(default=0),
        ),
        migrations.AddField(
            model_name='customuser',
            name='email_otp_expires_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='customuser',
            name='email_otp_hash',
            field=models.CharField(blank=True, max_length=128),
        ),
        migrations.AddField(
            model_name='customuser',
            name='email_verified',
            field=models.BooleanField(default=False),
        ),
    ]
