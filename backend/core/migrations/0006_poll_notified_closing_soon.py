from django.db import migrations, models


def add_notified_closing_soon_column(apps, schema_editor):
    connection = schema_editor.connection
    table_name = 'core_poll'

    with connection.cursor() as cursor:
        existing_columns = {
            column.name
            for column in connection.introspection.get_table_description(cursor, table_name)
        }

        if 'notified_closing_soon' in existing_columns:
            return

        cursor.execute(
            'ALTER TABLE core_poll ADD COLUMN notified_closing_soon bool NOT NULL DEFAULT 0'
        )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0005_user_account_type'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunPython(add_notified_closing_soon_column, migrations.RunPython.noop),
            ],
            state_operations=[
                migrations.AddField(
                    model_name='poll',
                    name='notified_closing_soon',
                    field=models.BooleanField(default=False),
                ),
            ],
        ),
    ]