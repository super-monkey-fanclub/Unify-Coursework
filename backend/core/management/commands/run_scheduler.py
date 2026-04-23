import os

from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger
from django.core.management import BaseCommand, call_command
from django.utils import timezone


class Command(BaseCommand):
    help = "Run periodic background jobs for poll and monthly notifications."

    def handle(self, *args, **options):
        scheduler = BlockingScheduler(timezone=str(timezone.get_current_timezone()))

        poll_interval_minutes = int(os.getenv("POLL_NOTIFICATIONS_INTERVAL_MINUTES", "5"))

        scheduler.add_job(
            lambda: call_command("send_poll_notifications"),
            trigger="interval",
            minutes=poll_interval_minutes,
            id="poll_notifications",
            max_instances=1,
            replace_existing=True,
            coalesce=True,
        )

        scheduler.add_job(
            lambda: call_command("send_monthly_society_notifications"),
            trigger=CronTrigger(day=1, hour=9, minute=0),
            id="monthly_society_notifications",
            max_instances=1,
            replace_existing=True,
            coalesce=True,
        )

        self.stdout.write(
            self.style.SUCCESS(
                "Scheduler started: poll notifications every "
                f"{poll_interval_minutes} minute(s), monthly notifications on day 1 at 09:00."
            )
        )

        try:
            scheduler.start()
        except (KeyboardInterrupt, SystemExit):
            scheduler.shutdown(wait=False)
            self.stdout.write(self.style.WARNING("Scheduler stopped."))