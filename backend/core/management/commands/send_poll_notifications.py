from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from core.models import Poll
from core.poll_notifications import notify_poll_ending_soon, notify_poll_closed


class Command(BaseCommand):
    help = "Send scheduled poll notifications (ending soon and closed)."

    def handle(self, *args, **options):
        now = timezone.now()
        one_hour_from_now = now + timedelta(hours=1)

        ending_soon_polls = Poll.objects.filter(
            closes_at__gt=now,
            closes_at__lte=one_hour_from_now,
            ending_soon_notified_at__isnull=True,
        )

        for poll in ending_soon_polls:
            notify_poll_ending_soon(poll)
            poll.ending_soon_notified_at = now
            poll.save(update_fields=["ending_soon_notified_at"])

        closed_polls = Poll.objects.filter(
            closes_at__lte=now,
            closed_notified_at__isnull=True,
        )

        for poll in closed_polls:
            notify_poll_closed(poll)
            poll.closed_notified_at = now
            poll.save(update_fields=["closed_notified_at"])

        self.stdout.write(
            self.style.SUCCESS(
                f"Processed {ending_soon_polls.count()} ending-soon poll(s) and {closed_polls.count()} closed poll(s)."
            )
        )