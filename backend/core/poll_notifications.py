from django.conf import settings
from django.core.mail import send_mail

from .models import Membership, Notification


def _notify_members(society, title, message, email_subject, email_message, exclude_user_id=None):
    memberships = Membership.objects.filter(society=society).select_related("user")
    target_users = [
        membership.user
        for membership in memberships
        if exclude_user_id is None or membership.user_id != exclude_user_id
    ]

    Notification.objects.bulk_create([
        Notification(user=user, title=title, message=message)
        for user in target_users
    ])

    for user in target_users:
        if not user.opt_in_email or not user.email:
            continue
        send_mail(
            subject=email_subject,
            message=email_message,
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", "no-reply@unify.local"),
            recipient_list=[user.email],
            fail_silently=True,
        )


def notify_poll_created(poll, actor_user_id):
    _notify_members(
        society=poll.society,
        title="New poll created",
        message=f"{poll.title} was posted in {poll.society.name}.",
        email_subject=f"New poll in {poll.society.name}",
        email_message=f"A new poll was posted: {poll.title}",
        exclude_user_id=actor_user_id,
    )


def notify_poll_removed(poll, actor_user_id):
    _notify_members(
        society=poll.society,
        title="Poll removed",
        message=f"{poll.title} was removed from {poll.society.name}.",
        email_subject=f"Poll removed in {poll.society.name}",
        email_message=f"The poll '{poll.title}' was removed.",
        exclude_user_id=actor_user_id,
    )


def notify_poll_ending_soon(poll):
    _notify_members(
        society=poll.society,
        title="Poll ending soon",
        message=f"{poll.title} closes within one hour.",
        email_subject=f"Poll ending soon in {poll.society.name}",
        email_message=f"The poll '{poll.title}' closes within one hour.",
    )


def notify_poll_closed(poll):
    _notify_members(
        society=poll.society,
        title="Poll closed",
        message=f"{poll.title} is now closed.",
        email_subject=f"Poll closed in {poll.society.name}",
        email_message=f"The poll '{poll.title}' is now closed.",
    )