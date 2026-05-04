# Generated migration for Notification model
from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):

    dependencies = [
        ('core', '0006_poll_notified_closing_soon'),
    ]

    operations = [
        migrations.CreateModel(
            name='Notification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('notif_type', models.CharField(choices=[('info', 'Info'), ('review', 'Review'), ('poll', 'Poll')], default='info', max_length=20)),
                ('message', models.CharField(max_length=500)),
                ('link', models.CharField(blank=True, default='', max_length=500)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('read', models.BooleanField(default=False)),
                ('society', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='core.society')),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to='core.user')),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
