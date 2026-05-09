from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Count

from core.models import Membership, User, Society


class Command(BaseCommand):
    help = "Clean and deduplicate Membership records and report per-society counts."

    def handle(self, *args, **options):
        self.stdout.write('Starting membership sync...')

        total_before = Membership.objects.count()
        self.stdout.write(f'Total Membership rows before: {total_before}')

        # 1) Remove memberships referencing missing users or societies
        removed_orphans = 0
        with transaction.atomic():
            for m in Membership.objects.all():
                try:
                    User.objects.get(pk=m.user_id)
                except User.DoesNotExist:
                    self.stdout.write(f'Removing membership id={m.id}: user {m.user_id} missing')
                    m.delete()
                    removed_orphans += 1
                    continue
                try:
                    Society.objects.get(pk=m.society_id)
                except Society.DoesNotExist:
                    self.stdout.write(f'Removing membership id={m.id}: society {m.society_id} missing')
                    m.delete()
                    removed_orphans += 1

        self.stdout.write(f'Removed orphan memberships: {removed_orphans}')

        # 2) Deduplicate any (user, society) duplicates: keep earliest created_at
        dup_groups = (
            Membership.objects.values('user_id', 'society_id')
            .annotate(cnt=Count('id'))
            .filter(cnt__gt=1)
        )

        duplicates_removed = 0
        for grp in dup_groups:
            user_id = grp['user_id']
            society_id = grp['society_id']
            rows = list(
                Membership.objects.filter(user_id=user_id, society_id=society_id).order_by('created_at')
            )
            # keep the first, delete rest
            for extra in rows[1:]:
                self.stdout.write(f'Deleting duplicate membership id={extra.id} for user={user_id} society={society_id}')
                extra.delete()
                duplicates_removed += 1

        self.stdout.write(f'Duplicates removed: {duplicates_removed}')

        # 3) Report per-society membership counts and ensure uniqueness constraint satisfied
        summary = []
        for s in Society.objects.order_by('id'):
            cnt = Membership.objects.filter(society=s).count()
            summary.append((s.id, s.name, cnt))

        self.stdout.write('Per-society membership counts:')
        for sid, name, cnt in summary:
            self.stdout.write(f'  [{sid}] {name}: {cnt}')

        total_after = Membership.objects.count()
        self.stdout.write(f'Total Membership rows after: {total_after}')
        self.stdout.write('Membership sync complete.')
