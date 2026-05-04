import re
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'unify.settings')
import django
django.setup()
from django.contrib.auth import get_user_model

User = get_user_model()

updated = []

for u in User.objects.all():
    # Skip real/admin users
    if getattr(u, 'is_staff', False) or getattr(u, 'is_superuser', False):
        continue

    # Only normalize users that look like seeded/fake accounts.
    # Criteria: first_name marked with '*', username starting with 'user', or example.com email.
    fname = (getattr(u, 'first_name', '') or '')
    uname = (getattr(u, 'username', '') or '')
    email = (getattr(u, 'email', '') or '')
    if not (fname.endswith('*') or uname.startswith('user') or email.endswith('@example.com')):
        continue

    up = getattr(u, 'up_number', '') or ''
    m = re.search(r"(\d+)", up)
    if not m:
        continue
    num = m.group(1).zfill(6)
    new_up = f'UP{num}'
    new_email = f'up{num}@gmail.com'
    if User.objects.filter(up_number=new_up).exclude(pk=u.pk).exists():
        new_up = f'UP{num}+{u.pk}'
    if User.objects.filter(email=new_email).exclude(pk=u.pk).exists():
        new_email = f'up{num}+{u.pk}@gmail.com'
    changed = False
    if (u.up_number or '') != new_up:
        u.up_number = new_up
        changed = True
    if (u.email or '') != new_email:
        u.email = new_email
        changed = True
    if changed:
        u.save()
        updated.append((u.pk, new_up, new_email))

print('Updated', len(updated))
for pk, upn, email in updated:
    print(pk, upn, email)
