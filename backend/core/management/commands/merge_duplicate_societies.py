from django.core.management.base import BaseCommand
from django.db import transaction

from core.models import Society, Membership, Review, Poll, SocietyInfo, Notification


class Command(BaseCommand):
    help = "Merge societies that only differ by case (e.g., 'Coding Society' and 'coding society')."

    def handle(self, *args, **options):
        self.stdout.write('Scanning for case-insensitive duplicate society names...')
        groups = {}
        for s in Society.objects.all():
            key = s.name.strip().lower()
            groups.setdefault(key, []).append(s)

        merges = 0
        for key, items in groups.items():
            if len(items) < 2:
                continue
            # choose canonical: lowest id
            items.sort(key=lambda s: s.id)
            canonical = items[0]
            duplicates = items[1:]
            self.stdout.write(f"Merging {len(duplicates)} duplicates into '{canonical.name}' (id={canonical.id})")
            with transaction.atomic():
                for dup in duplicates:
                    # reassign memberships
                    moved_members = Membership.objects.filter(society=dup).update(society=canonical)
                    # reassign reviews
                    Review.objects.filter(society=dup).update(society=canonical)
                    # reassign polls
                    Poll.objects.filter(society=dup).update(society=canonical)
                    # reassign infos
                    SocietyInfo.objects.filter(society=dup).update(society=canonical)
                    # reassign notifications
                    Notification.objects.filter(society=dup).update(society=canonical)
                    # finally delete the duplicate society
                    dup.delete()
                    self.stdout.write(f'  merged and deleted duplicate id={dup.id} (moved_members={moved_members})')
                    merges += 1

        if merges == 0:
            self.stdout.write('No duplicates found.')
        else:
            self.stdout.write(f'Done. Merged {merges} duplicate societies.')
