from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0002_societyinfo'),
    ]

    operations = [
        migrations.AlterField(
            model_name='societyinfo',
            name='title',
            field=models.CharField(blank=True, default='', max_length=200),
        ),
    ]
