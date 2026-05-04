#!/usr/bin/env python
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'unify.settings')
django.setup()

from core.models import Society, Membership, User

# Find the user
user = User.objects.get(email='ew@gmail.com')
print(f'User: {user.email} (ID: {user.id})')

# Find all memberships for this user
memberships = Membership.objects.filter(user=user)
print(f'\nMemberships for this user:')
for m in memberships:
    print(f'  - {m.society.name}: {m.role}')

# Check Chess Club specifically
chess_club = Society.objects.get(name='Chess Club')
chess_members = Membership.objects.filter(society=chess_club)
print(f'\nChess Club all memberships:')
for m in chess_members:
    print(f'  - {m.user.email}: {m.role}')

print(f'\nChess Club stats:')
print(f'  Total members: {chess_members.count()}')
print(f'  Admins: {chess_members.filter(role="admin").count()}')
