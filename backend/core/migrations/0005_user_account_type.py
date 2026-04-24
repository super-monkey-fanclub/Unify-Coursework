from django.db import migrations, models


def add_account_type_if_missing(apps, schema_editor):
    connection = schema_editor.connection
    table_name = 'core_user'

    with connection.cursor() as cursor:
        existing_columns = {
            row[1]
            for row in cursor.execute(f"PRAGMA table_info({table_name})").fetchall()
        }

        if 'account_type' not in existing_columns:
            cursor.execute(
                "ALTER TABLE core_user "
                "ADD COLUMN account_type varchar(20) NOT NULL DEFAULT 'regular'"
            )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_poll_ended_posted_as_info'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunPython(add_account_type_if_missing, migrations.RunPython.noop),
            ],
            state_operations=[
                migrations.AddField(
                    model_name='user',
                    name='account_type',
                    field=models.CharField(
                        choices=[
                            ('regular', 'Regular User'),
                            ('society_admin', 'Society Admin'),
                            ('dev', 'Developer'),
                        ],
                        default='regular',
                        max_length=20,
                    ),
                ),
            ],
        ),
    ]