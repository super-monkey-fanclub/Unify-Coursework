from datetime import timedelta

from django.conf import settings
from django.core.mail import send_mail
from django.core.management.base import BaseCommand
from django.db.models import Avg, Count
from django.utils import timezone

from core.models import Membership, Notification, Review, Society


class Command(BaseCommand):
    help = "Send monthly member rating reminders and admin trend-release notifications."

    def _send_email_if_opted_in(self, user, subject, message):
        if not user.opt_in_email or not user.email:
            return
        send_mail(
            subject=subject,
            message=message,
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", "no-reply@unify.local"),
            recipient_list=[user.email],
            fail_silently=True,
        )

    def handle(self, *args, **options):
        now = timezone.now()
        first_day_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        previous_month_end = first_day_of_month
        previous_month_start = (previous_month_end - timedelta(days=1)).replace(day=1)

        member_notifications_sent = 0
        admin_notifications_sent = 0

        for society in Society.objects.all():
            monthly_stats = Review.objects.filter(
                society=society,
                created_at__gte=previous_month_start,
                created_at__lt=previous_month_end,
            ).aggregate(avg_rating=Avg("rating"), review_count=Count("id"))

            avg_rating = monthly_stats["avg_rating"]
            review_count = monthly_stats["review_count"]
            avg_rating_text = f"{avg_rating:.1f}" if avg_rating is not None else "N/A"

            admin_memberships = Membership.objects.filter(society=society, role="admin").select_related("user")
            for membership in admin_memberships:
                title = "Monthly rating trend released"
                message = (
                    f"Monthly rating trend for {society.name}: average {avg_rating_text} from "
                    f"{review_count} review(s)."
                )
                Notification.objects.create(user=membership.user, title=title, message=message)
                self._send_email_if_opted_in(
                    membership.user,
                    subject=f"Monthly trend released for {society.name}",
                    message=message,
                )
                admin_notifications_sent += 1

            member_memberships = Membership.objects.filter(society=society, role="member").select_related("user")
            for membership in member_memberships:
                title = "Monthly rating reminder"
                message = f"Please remember to rate your experience in {society.name} this month."
                Notification.objects.create(user=membership.user, title=title, message=message)
                self._send_email_if_opted_in(
                    membership.user,
                    subject=f"Monthly rating reminder for {society.name}",
                    message=message,
                )
                member_notifications_sent += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Sent {member_notifications_sent} member reminder(s) and {admin_notifications_sent} admin trend notification(s)."
            )
        )