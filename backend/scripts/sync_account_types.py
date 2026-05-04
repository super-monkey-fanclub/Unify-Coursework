import os,sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE','unify.settings')
import django
django.setup()
from django.contrib.auth import get_user_model
from core.models import Membership
User = get_user_model()

updated = []
for u in User.objects.all():
    # skip staff/superuser/dev
    if getattr(u,'is_staff',False) or getattr(u,'is_superuser',False) or u.account_type=='dev':
        continue
    has_admin = Membership.objects.filter(user=u, role='admin').exists()
    new = 'society_admin' if has_admin else 'regular'
    if u.account_type != new:
        u.account_type = new
        u.save(update_fields=['account_type'])
        updated.append((u.pk, new))

print('Updated account_type for', len(updated), 'users')
for pk,at in updated:
    print(pk, at)
