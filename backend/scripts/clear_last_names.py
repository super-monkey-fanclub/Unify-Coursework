import sys,os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE','unify.settings')
import django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()

updated = []
for u in User.objects.all():
    if u.last_name:
        u.last_name = ''
        u.save(update_fields=['last_name'])
        updated.append(u.pk)

print('Cleared last_name for', len(updated), 'users')
if updated:
    print('User IDs updated:', updated)
