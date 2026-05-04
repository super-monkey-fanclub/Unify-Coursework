import re
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'unify.settings')
import django
django.setup()
from django.contrib.auth import get_user_model

User = get_user_model()
pattern = re.compile(r'^up(\d{6})(?:\+\d+)?@gmail\.com$')
rows = []
for u in User.objects.all():
    email = (u.email or '').lower()
    if pattern.match(email):
        uname = (u.username or '')
        fname = (u.first_name or '')
        if uname.startswith('user') or fname.endswith('*'):
            continue
        rows.append((u.pk, uname, fname, getattr(u, 'up_number', ''), email, u.is_staff, u.is_superuser))

print('Found', len(rows), 'potential real accounts with up... emails')
for r in rows:
    print(r)
