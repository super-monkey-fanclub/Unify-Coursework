from django.db import models


class UnifyUser(models.Model):
    """
    Matches the 'users' table defined in Database/unify.sql.
    up_number is auto-generated as UP + zero-padded primary key (e.g. UP000001).
    """
    up_number = models.CharField(max_length=20, unique=True, editable=False)
    admin_id = models.IntegerField(null=True, blank=True)
    name = models.CharField(max_length=100)
    email = models.EmailField(max_length=100, unique=True)
    opt_in_email = models.BooleanField(default=False)
    password_hash = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'users'

    def save(self, *args, **kwargs):
        # Generate up_number after first save so we have a pk
        super().save(*args, **kwargs)
        if not self.up_number:
            self.up_number = f'UP{self.pk:06d}'
            super().save(update_fields=['up_number'])

    def __str__(self):
        return f'{self.up_number} — {self.email}'
