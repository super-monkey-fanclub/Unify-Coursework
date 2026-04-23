from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_event_eventrsvp_notification_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='poll',
            name='closed_notified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='poll',
            name='ending_soon_notified_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
    ]