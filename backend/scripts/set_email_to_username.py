import os,sys
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE','unify.settings')
import django
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
ids = [2,3,4,5]
changed = []
for i in ids:
    try:
        u = User.objects.get(pk=i)
        u.email = (u.username or u.email)
        u.save()
        changed.append((u.pk, u.username, u.email))
    except Exception as e:
        print('err', i, e)
print('updated', changed)
