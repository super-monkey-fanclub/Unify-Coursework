from django.core.management.base import BaseCommand

from core.views import _check_and_notify_closing_polls


class Command(BaseCommand):
    help = 'Scan for polls closing within the next hour and notify society members.'

    def handle(self, *args, **options):
        _check_and_notify_closing_polls()
        self.stdout.write(self.style.SUCCESS('Closing poll notifications checked successfully.'))
