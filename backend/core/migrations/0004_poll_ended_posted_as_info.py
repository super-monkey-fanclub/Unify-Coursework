from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0003_alter_societyinfo_title'),
    ]

    operations = [
        migrations.AddField(
            model_name='poll',
            name='ended_posted_as_info',
            field=models.BooleanField(default=False),
        ),
    ]
