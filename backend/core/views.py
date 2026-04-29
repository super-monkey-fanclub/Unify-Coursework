import json
import re
from datetime import datetime, timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError
from django.db.models import Count, Q
from django.http import HttpRequest, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import (
    Membership,
    Notification,
    Poll,
    PollOption,
    PollVote,
    Review,
    ReviewReaction,
    ReviewResponse,
    Society,
)

User = get_user_model()

REVIEW_MAX_COMMENT_LENGTH = 500
POLL_MAX_DESCRIPTION_LENGTH = 500
MIN_MEMBERSHIP_DAYS_FOR_REVIEW = 14
POLL_MIN_DURATION = timedelta(hours=24)
POLL_MAX_DURATION = timedelta(days=7)
POLL_DELETE_LOCK_WINDOW = timedelta(minutes=30)
BANNED_REVIEW_TERMS = {
    'idiot',
    'stupid',
    'dumb',
    'hate',
    'trash',
    'moron',
    'bitch',
    'bastard',
}


def _json_body(request: HttpRequest) -> dict:
    try:
        return json.loads(request.body.decode('utf-8'))
    except Exception:
        return {}


def _safe_text(value: object) -> str:
    return (value or '').strip() if isinstance(value, str) else ''


def _author_display_name(user: User) -> str:
    if user.first_name:
        return user.first_name
    if user.username:
        return user.username
    return user.email.split('@')[0]


def _user_payload(user: User) -> dict:
    return {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'name': user.first_name,
        'account_type': user.account_type,
        'can_create_polls': user.account_type in {'dev', 'society_admin'},
    }


def _is_dev(user: User) -> bool:
    return user.account_type == 'dev'


def _is_society_admin(user: User, society: Society) -> bool:
    if user.account_type == 'dev':
        return True
    if user.account_type != 'society_admin':
        return False
    return Membership.objects.filter(user=user, society=society, role='admin').exists()


def _membership_for_user(user: User, society: Society) -> Membership | None:
    try:
        return Membership.objects.get(user=user, society=society)
    except Membership.DoesNotExist:
        return None


def _contains_offensive_language(comment: str) -> bool:
    lowered = comment.lower()
    return any(
        re.search(rf'\b{re.escape(term)}\b', lowered) for term in BANNED_REVIEW_TERMS
    )


def _create_notification(user: User, notification_type: str, title: str, message: str, 
                        poll: Poll | None = None, review: Review | None = None) -> Notification:
    """Create a notification for a user."""
    return Notification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message=message,
        related_poll=poll,
        related_review=review,
    )


def _notify_society_members(society: Society, notification_type: str, title: str, message: str,
                           exclude_user: User | None = None, poll: Poll | None = None):
    """Create notifications for all members of a society."""
    members = Membership.objects.filter(society=society).select_related('user')
    for membership in members:
        if exclude_user and membership.user.id == exclude_user.id:
            continue
        _create_notification(
            user=membership.user,
            notification_type=notification_type,
            title=title,
            message=message,
            poll=poll,
        )


def _check_and_notify_closing_polls():
    """Check for polls closing in the next hour and notify members."""
    now = timezone.now()
    one_hour_later = now + timedelta(hours=1)
    
    # Find polls that close within the next hour but haven't been notified yet
    closing_polls = Poll.objects.filter(
        closes_at__lte=one_hour_later,
        closes_at__gt=now,
        notified_closing_soon=False,
    ).select_related('society')
    
    for poll in closing_polls:
        _notify_society_members(
            society=poll.society,
            notification_type='poll_closing_soon',
            title=f"Poll Closing Soon: {poll.title}",
            message=f"The poll '{poll.title}' will close in less than 1 hour. Vote now!",
            poll=poll,
        )
        poll.notified_closing_soon = True
        poll.save()


def _parse_datetime(value: str) -> datetime | None:
    value = value.strip()
    if not value:
        return None
    normalized = value.replace('Z', '+00:00')
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None

    if timezone.is_naive(parsed):
        parsed = timezone.make_aware(parsed, timezone.utc)
    return parsed.astimezone(timezone.utc)


def _ensure_dev_user(account_email: str | None = None) -> User:
    email = account_email or getattr(settings, 'DEFAULT_DEV_EMAIL', 'dev@unify.local')
    password = getattr(settings, 'DEFAULT_DEV_PASSWORD', 'DevPass123!')
    name = getattr(settings, 'DEFAULT_DEV_NAME', 'Unify Dev')

    user, created = User.objects.get_or_create(
        email=email,
        defaults={
            'username': email,
            'first_name': name,
            'account_type': 'dev',
            'is_staff': True,
            'is_superuser': True,
        },
    )

    changed = False
    if created:
        user.set_password(password)
        changed = True

    if user.account_type != 'dev':
        user.account_type = 'dev'
        changed = True

    if not user.is_staff:
        user.is_staff = True
        changed = True

    if not user.is_superuser:
        user.is_superuser = True
        changed = True

    if changed:
        user.save()

    return user


def _review_block_reason(user: User, society: Society) -> str | None:
    if user.account_type in {'dev', 'society_admin'}:
        return 'Admin/dev accounts cannot create society reviews.'

    membership = _membership_for_user(user, society)
    if membership is None:
        return 'Only members of this society can leave a review.'

    if membership.created_at > timezone.now() - timedelta(days=MIN_MEMBERSHIP_DAYS_FOR_REVIEW):
        return 'You need to be a member for at least 2 weeks before reviewing.'

    if Review.objects.filter(user=user, society=society).exists():
        return 'You already have an active review for this society.'

    return None


def _serialize_poll(poll: Poll, viewer: User | None = None) -> dict:
    now = timezone.now()
    options = list(poll.polloption_set.all().order_by('id'))
    votes = list(PollVote.objects.filter(poll=poll))
    total_votes = len(votes)

    count_by_option_id: dict[int, int] = {}
    for vote in votes:
        count_by_option_id[vote.option_id] = count_by_option_id.get(vote.option_id, 0) + 1

    is_open = poll.opens_at <= now <= poll.closes_at
    is_closed = now > poll.closes_at

    viewer_has_voted = False
    can_vote = False
    vote_block_reason = None
    user_vote_option_id = None
    can_delete = False
    delete_block_reason = None
    can_manage = False

    if viewer is not None:
        viewer_has_voted = PollVote.objects.filter(user=viewer, poll=poll).exists()
        if viewer_has_voted:
            user_vote_option_id = (
                PollVote.objects.filter(user=viewer, poll=poll)
                .values_list('option_id', flat=True)
                .first()
            )

        is_member = Membership.objects.filter(user=viewer, society=poll.society).exists()
        can_manage = _is_society_admin(viewer, poll.society)

        if not is_member:
            vote_block_reason = 'Only members of this society can vote.'
        elif not is_open:
            vote_block_reason = 'Voting is closed for this poll.' if is_closed else 'Voting has not opened yet.'
        elif viewer_has_voted:
            vote_block_reason = 'You have already voted in this poll.'
        else:
            can_vote = True

        if can_manage:
            if now < poll.created_at + POLL_DELETE_LOCK_WINDOW:
                delete_block_reason = 'Poll deletion is unavailable during the first 30 minutes.'
            else:
                can_delete = True

    serialized_options = []
    for option in options:
        count = count_by_option_id.get(option.id, 0)
        percentage = (count / total_votes * 100) if total_votes > 0 else 0
        serialized_options.append(
            {
                'id': option.id,
                'text': option.option_text,
                'vote_count': count,
                'percentage': round(percentage, 1),
            }
        )

    return {
        'id': poll.id,
        'society_name': poll.society.name,
        'title': poll.title,
        'description': poll.description,
        'opens_at': poll.opens_at.isoformat(),
        'closes_at': poll.closes_at.isoformat(),
        'created_at': poll.created_at.isoformat(),
        'is_open': is_open,
        'is_closed': is_closed,
        'options': serialized_options,
        'total_votes': total_votes,
        'viewer_has_voted': viewer_has_voted,
        'user_vote_option_id': user_vote_option_id,
        'can_vote': can_vote,
        'vote_block_reason': vote_block_reason,
        'can_manage': can_manage,
        'can_delete': can_delete,
        'delete_block_reason': delete_block_reason,
    }


@csrf_exempt
@require_http_methods(['POST'])
def register_view(request: HttpRequest):
    data = _json_body(request)

    name = _safe_text(data.get('name'))
    email = _safe_text(data.get('email')).lower()
    password = data.get('password') or ''
    bootstrap_key = _safe_text(data.get('bootstrap_key'))
    opt_in_email = data.get('opt_in_email', False)

    if not name or not email or not password:
        return JsonResponse({'error': 'All fields are required.'}, status=400)

    if '@' not in email or '.' not in email:
        return JsonResponse({'error': 'Enter a valid email address.'}, status=400)

    if User.objects.filter(email=email).exists():
        return JsonResponse({'error': 'An account with that email already exists.'}, status=409)

    account_type = 'regular'
    is_staff = False
    is_superuser = False
    if (
        bootstrap_key
        and bootstrap_key == getattr(settings, 'DEV_BOOTSTRAP_KEY', '')
    ):
        account_type = 'dev'
        is_staff = True
        is_superuser = True

    user = User.objects.create_user(
        username=email,
        email=email,
        password=password,
    )
    user.first_name = name
    user.account_type = account_type
    user.is_staff = is_staff
    user.is_superuser = is_superuser
    user.opt_in_email = bool(opt_in_email)
    user.save()

    return JsonResponse(
        {
            'message': 'Registration successful.',
            'user': _user_payload(user),
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def login_view(request: HttpRequest):
    data = _json_body(request)

    email = _safe_text(data.get('email')).lower()
    password = data.get('password') or ''

    if not email or not password:
        return JsonResponse({'error': 'Email and password are required.'}, status=400)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Invalid email or password.'}, status=401)

    if not user.check_password(password):
        return JsonResponse({'error': 'Invalid email or password.'}, status=401)

    return JsonResponse(
        {
            'message': 'Login successful.',
            'user': _user_payload(user),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def ensure_dev_account_view(request: HttpRequest):
    data = _json_body(request)
    bootstrap_key = _safe_text(data.get('bootstrap_key'))
    email = _safe_text(data.get('email')).lower() or None

    if bootstrap_key != getattr(settings, 'DEV_BOOTSTRAP_KEY', ''):
        return JsonResponse({'error': 'Invalid bootstrap key.'}, status=403)

    dev_user = _ensure_dev_user(email)
    return JsonResponse(
        {
            'message': 'Developer account is ready.',
            'user': _user_payload(dev_user),
            'default_password': getattr(settings, 'DEFAULT_DEV_PASSWORD', 'DevPass123!'),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def update_user_role_view(request: HttpRequest):
    data = _json_body(request)

    dev_email = _safe_text(data.get('dev_email')).lower()
    target_email = _safe_text(data.get('target_email')).lower()
    target_account_type = _safe_text(data.get('target_account_type'))
    society_name = _safe_text(data.get('society_name'))

    if not dev_email or not target_email or not target_account_type:
        return JsonResponse(
            {'error': 'dev_email, target_email and target_account_type are required.'},
            status=400,
        )

    if target_account_type not in {'regular', 'society_admin', 'dev'}:
        return JsonResponse({'error': 'Invalid target_account_type.'}, status=400)

    try:
        actor = User.objects.get(email=dev_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Acting user not found.'}, status=404)

    if not _is_dev(actor):
        return JsonResponse({'error': 'Only dev users can update account roles.'}, status=403)

    try:
        target_user = User.objects.get(email=target_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Target user not found.'}, status=404)

    target_user.account_type = target_account_type
    if target_account_type == 'dev':
        target_user.is_staff = True
        target_user.is_superuser = True
    elif target_user.is_superuser:
        target_user.is_superuser = False
        target_user.is_staff = target_user.is_staff or False
    target_user.save()

    if society_name:
        society, _ = Society.objects.get_or_create(
            name=society_name,
            defaults={'description': '', 'category': 'General'},
        )
        membership, _ = Membership.objects.get_or_create(
            user=target_user,
            society=society,
            defaults={'role': 'member'},
        )
        membership.role = 'admin' if target_account_type == 'society_admin' else 'member'
        membership.save()

    return JsonResponse(
        {
            'message': 'User role updated.',
            'user': _user_payload(target_user),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def join_society_view(request: HttpRequest):
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    society_name = _safe_text(data.get('society_name'))

    if not email or not society_name:
        return JsonResponse({'error': 'Email and society_name are required.'}, status=400)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found for that email.'}, status=404)

    society, _ = Society.objects.get_or_create(
        name=society_name,
        defaults={'description': '', 'category': 'General'},
    )

    role = 'admin' if user.account_type in {'dev', 'society_admin'} else 'member'
    membership, created = Membership.objects.get_or_create(
        user=user,
        society=society,
        defaults={'role': role},
    )

    return JsonResponse(
        {
            'message': 'Joined society' if created else 'Already a member',
            'membership': {
                'id': membership.id,
                'user_id': membership.user_id,
                'society_id': membership.society_id,
                'role': membership.role,
            },
        },
        status=201 if created else 200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def my_societies_view(request: HttpRequest):
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()

    if not email:
        return JsonResponse({'error': 'Email is required.'}, status=400)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found for that email.'}, status=404)

    memberships = (
        Membership.objects.select_related('society')
        .filter(user=user)
        .order_by('society__name')
    )

    societies = [
        {
            'id': membership.society.id,
            'name': membership.society.name,
            'description': membership.society.description,
            'category': membership.society.category,
            'role': membership.role,
        }
        for membership in memberships
    ]

    return JsonResponse({'societies': societies}, status=200)


@csrf_exempt
@require_http_methods(['GET'])
def list_polls_view(request: HttpRequest):
    society_name = _safe_text(request.GET.get('society'))
    viewer_email = _safe_text(request.GET.get('viewer_email')).lower()

    if not society_name:
        return JsonResponse({'error': 'society query parameter is required.'}, status=400)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    viewer = None
    if viewer_email:
        try:
            viewer = User.objects.get(email=viewer_email)
        except User.DoesNotExist:
            viewer = None

    polls = Poll.objects.filter(society=society).order_by('-created_at')
    data = [_serialize_poll(poll, viewer=viewer) for poll in polls]

    can_create = False
    if viewer is not None:
        can_create = _is_society_admin(viewer, society)

    return JsonResponse({'polls': data, 'can_create_polls': can_create}, status=200)


def _validate_poll_payload(
    *,
    title: str,
    description: str,
    opens_at: datetime | None,
    closes_at: datetime | None,
    options: list[str],
) -> str | None:
    if not title:
        return 'Poll title is required.'
    if not description:
        return 'Poll description is required.'
    if len(description) > POLL_MAX_DESCRIPTION_LENGTH:
        return f'Poll description must be {POLL_MAX_DESCRIPTION_LENGTH} characters or less.'
    if opens_at is None or closes_at is None:
        return 'opens_at and closes_at are required and must be valid ISO datetimes.'
    if closes_at <= opens_at:
        return 'Poll close time must be after open time.'

    duration = closes_at - opens_at
    if duration < POLL_MIN_DURATION:
        return 'Poll duration must be at least 24 hours.'
    if duration > POLL_MAX_DURATION:
        return 'Poll duration must not exceed 7 days.'

    filtered_options = [option for option in options if option]
    if len(filtered_options) < 2:
        return 'At least 2 poll options are required.'

    if len(set(filtered_options)) != len(filtered_options):
        return 'Poll options must be unique.'

    return None


@csrf_exempt
@require_http_methods(['POST'])
def create_poll_view(request: HttpRequest):
    data = _json_body(request)

    creator_email = _safe_text(data.get('creator_email')).lower()
    society_name = _safe_text(data.get('society_name'))
    title = _safe_text(data.get('title'))
    description = _safe_text(data.get('description'))
    opens_at = _parse_datetime(_safe_text(data.get('opens_at')))
    closes_at = _parse_datetime(_safe_text(data.get('closes_at')))
    options = [
        _safe_text(item)
        for item in (data.get('options') if isinstance(data.get('options'), list) else [])
    ]

    if not creator_email or not society_name:
        return JsonResponse({'error': 'creator_email and society_name are required.'}, status=400)

    try:
        creator = User.objects.get(email=creator_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Creator user not found.'}, status=404)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    if not _is_society_admin(creator, society):
        return JsonResponse(
            {'error': 'Only dev users or society admins can create polls.'},
            status=403,
        )

    error = _validate_poll_payload(
        title=title,
        description=description,
        opens_at=opens_at,
        closes_at=closes_at,
        options=options,
    )
    if error:
        return JsonResponse({'error': error}, status=400)

    if Poll.objects.filter(society=society, title=title, description=description).exists():
        return JsonResponse(
            {'error': 'A duplicate poll with the same title and description already exists.'},
            status=409,
        )

    poll = Poll.objects.create(
        society=society,
        title=title,
        description=description,
        opens_at=opens_at,
        closes_at=closes_at,
    )
    PollOption.objects.bulk_create(
        [PollOption(poll=poll, option_text=option) for option in options if option]
    )


    # Notify society members about the new poll
    _notify_society_members(
        society=society,
        notification_type='poll_created',
        title=f"New Poll: {title}",
        message=f"A new poll '{title}' has been created. Vote now!",
        exclude_user=creator,
        poll=poll,
    )

    return JsonResponse(
        {
            'message': 'Poll created.',
            'poll': _serialize_poll(poll, viewer=creator),
        },
        status=201,
    )

@csrf_exempt
@require_http_methods(['POST'])
def update_poll_view(request: HttpRequest):
    data = _json_body(request)

    editor_email = _safe_text(data.get('editor_email')).lower()
    poll_id_raw = data.get('poll_id')
    title = _safe_text(data.get('title'))
    description = _safe_text(data.get('description'))
    opens_at = _parse_datetime(_safe_text(data.get('opens_at')))
    closes_at = _parse_datetime(_safe_text(data.get('closes_at')))
    options = [
        _safe_text(item)
        for item in (data.get('options') if isinstance(data.get('options'), list) else [])
    ]

    if not editor_email or poll_id_raw is None:
        return JsonResponse({'error': 'editor_email and poll_id are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

    try:
        editor = User.objects.get(email=editor_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Editor user not found.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    if not _is_society_admin(editor, poll.society):
        return JsonResponse({'error': 'Only dev users or society admins can edit polls.'}, status=403)

    if timezone.now() >= poll.opens_at:
        return JsonResponse({'error': 'Poll cannot be edited after it has opened.'}, status=409)

    if PollVote.objects.filter(poll=poll).exists():
        return JsonResponse({'error': 'Poll with votes cannot be edited.'}, status=409)

    error = _validate_poll_payload(
        title=title,
        description=description,
        opens_at=opens_at,
        closes_at=closes_at,
        options=options,
    )
    if error:
        return JsonResponse({'error': error}, status=400)

    if (
        Poll.objects.filter(society=poll.society, title=title, description=description)
        .exclude(id=poll.id)
        .exists()
    ):
        return JsonResponse(
            {'error': 'A duplicate poll with the same title and description already exists.'},
            status=409,
        )

    poll.title = title
    poll.description = description
    poll.opens_at = opens_at
    poll.closes_at = closes_at
    poll.save()

    poll.polloption_set.all().delete()
    PollOption.objects.bulk_create(
        [PollOption(poll=poll, option_text=option) for option in options if option]
    )

    return JsonResponse(
        {
            'message': 'Poll updated.',
            'poll': _serialize_poll(poll, viewer=editor),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def delete_poll_view(request: HttpRequest):
    data = _json_body(request)

    actor_email = _safe_text(data.get('actor_email')).lower()
    poll_id_raw = data.get('poll_id')

    if not actor_email or poll_id_raw is None:
        return JsonResponse({'error': 'actor_email and poll_id are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

    try:
        actor = User.objects.get(email=actor_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Acting user not found.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    if not _is_society_admin(actor, poll.society):
        return JsonResponse({'error': 'Only dev users or society admins can delete polls.'}, status=403)

    if timezone.now() < poll.created_at + POLL_DELETE_LOCK_WINDOW:
        return JsonResponse(
            {'error': 'Poll deletion is unavailable during the first 30 minutes.'},
            status=409,
        )


    # Notify society members about poll deletion
    society = poll.society
    poll_title = poll.title
    _notify_society_members(
        society=society,
        notification_type='poll_deleted',
        title=f"Poll Deleted: {poll_title}",
        message=f"The poll '{poll_title}' has been deleted.",
        exclude_user=actor,
    )
    
    poll.delete()
    return JsonResponse({'message': 'Poll deleted.'}, status=200)

@csrf_exempt
@require_http_methods(['POST'])
def vote_poll_view(request: HttpRequest):
    data = _json_body(request)
    user_email = _safe_text(data.get('user_email')).lower()
    poll_id_raw = data.get('poll_id')
    option_id_raw = data.get('option_id')

    if not user_email or poll_id_raw is None or option_id_raw is None:
        return JsonResponse({'error': 'user_email, poll_id and option_id are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
        option_id = int(option_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id and option_id must be integers.'}, status=400)

    try:
        user = User.objects.get(email=user_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found for that email.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    try:
        option = PollOption.objects.get(id=option_id, poll=poll)
    except PollOption.DoesNotExist:
        return JsonResponse({'error': 'Poll option not found.'}, status=404)

    if not Membership.objects.filter(user=user, society=poll.society).exists():
        return JsonResponse({'error': 'Only society members can vote in this poll.'}, status=403)

    now = timezone.now()
    if now < poll.opens_at:
        return JsonResponse({'error': 'Voting has not opened yet.'}, status=409)
    if now > poll.closes_at:
        return JsonResponse({'error': 'Voting has closed for this poll.'}, status=409)

    if PollVote.objects.filter(user=user, poll=poll).exists():
        return JsonResponse({'error': 'You can vote only once in this poll.'}, status=409)

    try:
        PollVote.objects.create(user=user, poll=poll, option=option)
    except IntegrityError:
        return JsonResponse({'error': 'You can vote only once in this poll.'}, status=409)

    return JsonResponse({'message': 'Vote recorded.'}, status=201)


@csrf_exempt
@require_http_methods(['GET'])
def society_reviews_view(request: HttpRequest):
    society_name = _safe_text(request.GET.get('society'))
    sort_by = _safe_text(request.GET.get('sort')).lower() or 'latest'
    viewer_email = _safe_text(request.GET.get('viewer_email')).lower()
    min_rating_raw = _safe_text(request.GET.get('min_rating'))

    if not society_name:
        return JsonResponse({'error': 'society query parameter is required.'}, status=400)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    min_rating = None
    if min_rating_raw:
        try:
            min_rating = int(min_rating_raw)
        except ValueError:
            return JsonResponse({'error': 'min_rating must be an integer.'}, status=400)
        if min_rating < 1 or min_rating > 5:
            return JsonResponse({'error': 'min_rating must be between 1 and 5.'}, status=400)

    viewer = None
    if viewer_email:
        try:
            viewer = User.objects.get(email=viewer_email)
        except User.DoesNotExist:
            viewer = None

    reviews = Review.objects.filter(society=society).select_related('user').annotate(
        likes_count=Count('reviewreaction', filter=Q(reviewreaction__reaction_type='like')),
        dislikes_count=Count('reviewreaction', filter=Q(reviewreaction__reaction_type='dislike')),
    )

    if min_rating is not None:
        reviews = reviews.filter(rating__gte=min_rating)

    if sort_by == 'rating':
        reviews = reviews.order_by('-rating', '-created_at')
    elif sort_by == 'popularity':
        reviews = reviews.order_by('-likes_count', '-created_at')
    else:
        reviews = reviews.order_by('-created_at')

    review_ids = [review.id for review in reviews]
    response_map = {
        response.review_id: response
        for response in ReviewResponse.objects.filter(review_id__in=review_ids).select_related('admin')
    }

    user_reaction_map = {}
    if viewer is not None:
        reactions = ReviewReaction.objects.filter(user=viewer, review_id__in=review_ids)
        user_reaction_map = {reaction.review_id: reaction.reaction_type for reaction in reactions}

    viewer_is_admin = False
    viewer_can_react = False
    can_create_review = False
    review_block_reason = None
    has_active_review = False

    if viewer is not None:
        viewer_is_admin = _is_society_admin(viewer, society)
        viewer_can_react = (
            viewer.account_type == 'regular'
            and Membership.objects.filter(user=viewer, society=society).exists()
        )

        has_active_review = Review.objects.filter(user=viewer, society=society).exists()
        review_block_reason = _review_block_reason(viewer, society)
        can_create_review = review_block_reason is None

    data = []
    for review in reviews:
        response = response_map.get(review.id)
        current_user_reaction = user_reaction_map.get(review.id)
        data.append(
            {
                'id': review.id,
                'author': review.user.email,
                'author_display_name': _author_display_name(review.user),
                'rating': review.rating,
                'comment': review.comment,
                'created_at': review.created_at.isoformat(),
                'likes': review.likes_count,
                'dislikes': review.dislikes_count,
                'user_reaction': current_user_reaction,
                'can_react': viewer_can_react and current_user_reaction is None,
                'admin_response': {
                    'text': response.response_text,
                    'admin_display_name': _author_display_name(response.admin),
                    'created_at': response.created_at.isoformat(),
                }
                if response
                else None,
            }
        )

    return JsonResponse(
        {
            'reviews': data,
            'viewer_is_admin': viewer_is_admin,
            'can_create_review': can_create_review,
            'review_block_reason': review_block_reason,
            'has_active_review': has_active_review,
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def add_review_view(request: HttpRequest):
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    society_name = _safe_text(data.get('society_name'))
    comment = _safe_text(data.get('comment'))
    rating_raw = data.get('rating')

    if not email or not society_name or rating_raw is None:
        return JsonResponse({'error': 'email, society_name and rating are required.'}, status=400)

    try:
        rating = int(rating_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'rating must be an integer.'}, status=400)

    if rating < 1 or rating > 5:
        return JsonResponse({'error': 'rating must be between 1 and 5.'}, status=400)

    if len(comment) > REVIEW_MAX_COMMENT_LENGTH:
        return JsonResponse(
            {
                'error': f'Review comment must be {REVIEW_MAX_COMMENT_LENGTH} characters or less.'
            },
            status=400,
        )

    if _contains_offensive_language(comment):
        return JsonResponse(
            {'error': 'Offensive language detected. Please edit your review.'},
            status=400,
        )

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found for that email.'}, status=404)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    block_reason = _review_block_reason(user, society)
    if block_reason is not None:
        return JsonResponse({'error': block_reason}, status=403)

    review = Review.objects.create(user=user, society=society, rating=rating, comment=comment)
    
    # Update society average rating
    society.update_average_rating()

    return JsonResponse(
        {
            'message': 'Review created',
            'review': {
                'id': review.id,
                'author': review.user.email,
                'author_display_name': _author_display_name(review.user),
                'rating': review.rating,
                'comment': review.comment,
                'likes': 0,
                'dislikes': 0,
            },
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def react_review_view(request: HttpRequest):
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    reaction_type = _safe_text(data.get('reaction_type')).lower()
    review_id_raw = data.get('review_id')

    if not email or not reaction_type or review_id_raw is None:
        return JsonResponse({'error': 'email, review_id and reaction_type are required.'}, status=400)

    if reaction_type not in {'like', 'dislike'}:
        return JsonResponse({'error': 'reaction_type must be like or dislike.'}, status=400)

    try:
        review_id = int(review_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'review_id must be an integer.'}, status=400)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found for that email.'}, status=404)

    try:
        review = Review.objects.select_related('society').get(id=review_id)
    except Review.DoesNotExist:
        return JsonResponse({'error': 'Review not found.'}, status=404)

    if user.account_type in {'dev', 'society_admin'}:
        return JsonResponse({'error': 'Admins/dev users cannot like or dislike reviews.'}, status=403)

    if not Membership.objects.filter(user=user, society=review.society).exists():
        return JsonResponse({'error': 'Only members of this society can react.'}, status=403)

    if ReviewReaction.objects.filter(user=user, review=review).exists():
        return JsonResponse({'error': 'You can only react to a review once.'}, status=409)

    try:
        ReviewReaction.objects.create(user=user, review=review, reaction_type=reaction_type)
    except IntegrityError:
        return JsonResponse({'error': 'You can only react to a review once.'}, status=409)

    likes = ReviewReaction.objects.filter(review=review, reaction_type='like').count()
    dislikes = ReviewReaction.objects.filter(review=review, reaction_type='dislike').count()

    # Notify review author if reaction is a like
    if reaction_type == 'like':
        _create_notification(
            user=review.user,
            notification_type='review_liked',
            title=f"Your Review Was Liked",
            message=f"{_author_display_name(user)} liked your review on {review.society.name}.",
            review=review,
        )

    return JsonResponse(
        {
            'message': 'Reaction recorded.',
            'likes': likes,
            'dislikes': dislikes,
            'user_reaction': reaction_type,
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def admin_delete_review_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    review_id_raw = data.get('review_id')

    if not admin_email or review_id_raw is None:
        return JsonResponse({'error': 'admin_email and review_id are required.'}, status=400)

    try:
        review_id = int(review_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'review_id must be an integer.'}, status=400)

    try:
        admin_user = User.objects.get(email=admin_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    try:
        review = Review.objects.select_related('society').get(id=review_id)
    except Review.DoesNotExist:
        return JsonResponse({'error': 'Review not found.'}, status=404)

    if not _is_society_admin(admin_user, review.society):
        return JsonResponse({'error': 'Only society admins/dev users can delete reviews.'}, status=403)

    society = review.society
    review.delete()
    
    # Update society average rating
    society.update_average_rating()
    
    return JsonResponse({'message': 'Review deleted.'}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def admin_respond_review_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    response_text = _safe_text(data.get('response_text'))
    review_id_raw = data.get('review_id')

    if not admin_email or not response_text or review_id_raw is None:
        return JsonResponse(
            {'error': 'admin_email, review_id and response_text are required.'},
            status=400,
        )

    if len(response_text) > REVIEW_MAX_COMMENT_LENGTH:
        return JsonResponse(
            {
                'error': f'Admin response must be {REVIEW_MAX_COMMENT_LENGTH} characters or less.'
            },
            status=400,
        )

    try:
        review_id = int(review_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'review_id must be an integer.'}, status=400)

    try:
        admin_user = User.objects.get(email=admin_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    try:
        review = Review.objects.select_related('society').get(id=review_id)
    except Review.DoesNotExist:
        return JsonResponse({'error': 'Review not found.'}, status=404)

    if not _is_society_admin(admin_user, review.society):
        return JsonResponse({'error': 'Only society admins/dev users can respond to reviews.'}, status=403)

    response, created = ReviewResponse.objects.update_or_create(
        review=review,
        defaults={'admin': admin_user, 'response_text': response_text},
    )

    return JsonResponse(
        {
            'message': 'Response created.' if created else 'Response updated.',
            'response': {
                'text': response.response_text,
                'admin_display_name': _author_display_name(response.admin),
                'created_at': response.created_at.isoformat(),
            },
        },
        status=201 if created else 200,
    )


@csrf_exempt
@require_http_methods(['GET'])
def society_polls_view(request: HttpRequest):
    society_name = _safe_text(request.GET.get('society'))
    viewer_email = _safe_text(request.GET.get('viewer_email')).lower()

    if not society_name:
        return JsonResponse({'error': 'society query parameter is required.'}, status=400)

    society, _ = Society.objects.get_or_create(
        name=society_name,
        defaults={'description': '', 'category': 'General'},
    )

    viewer = _authenticated_user_from_request(request)
    if viewer is None and viewer_email:
        try:
            viewer = User.objects.get(email=viewer_email)
        except User.DoesNotExist:
            viewer = None

    viewer_is_member = False
    viewer_is_admin = False
    if viewer is not None:
        viewer_is_member = Membership.objects.filter(user=viewer, society=society).exists()
        viewer_is_admin = _is_society_admin(viewer, society)

    _finalize_closed_polls(society)

    polls = Poll.objects.filter(
        society=society,
        ended_posted_as_info=False,
    ).order_by('created_at')
    poll_data = [_serialize_poll(poll, viewer) for poll in polls]
    info_entries = (
        SocietyInfo.objects.select_related('admin')
        .filter(society=society)
        .order_by('created_at')
    )
    info_data = [_serialize_info(entry) for entry in info_entries]

    return JsonResponse(
        {
            'polls': poll_data,
            'info_items': info_data,
            'viewer_is_member': viewer_is_member,
            'viewer_is_admin': viewer_is_admin,
            'can_create_poll': viewer_is_admin,
            'can_create_info': viewer_is_admin,
        },
        status=200,
    )


def society_poll_detail_view(request: HttpRequest):
    poll_id_raw = request.GET.get('poll_id')
    viewer_email = _safe_text(request.GET.get('viewer_email')).lower()

    if poll_id_raw is None:
        return JsonResponse({'error': 'poll_id query parameter is required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    viewer = _authenticated_user_from_request(request)
    viewer_is_member = False
    viewer_is_admin = False
    if viewer is None and viewer_email:
        try:
            viewer = User.objects.get(email=viewer_email)
        except User.DoesNotExist:
            viewer = None

    if viewer is not None:
        viewer_is_member = Membership.objects.filter(user=viewer, society=poll.society).exists()
        viewer_is_admin = _is_society_admin(viewer, poll.society)

    return JsonResponse(
        {
            'poll': _serialize_poll(poll, viewer),
            'society': {
                'id': poll.society.id,
                'name': poll.society.name,
                'category': poll.society.category,
            },
            'viewer_is_member': viewer_is_member,
            'viewer_is_admin': viewer_is_admin,
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def create_society_info_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    society_name = _safe_text(data.get('society_name'))
    title = _safe_text(data.get('title'))
    content = _safe_text(data.get('content'))

    admin_user = _authenticated_user_from_request(request, data=data)

    if not society_name or not content:
        return JsonResponse(
            {'error': 'society_name and content are required.'},
            status=400,
        )

    if admin_user is None and not admin_email:
        return JsonResponse({'error': 'Authentication token or admin_email is required.'}, status=400)

    if admin_user is None:
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    society, _ = Society.objects.get_or_create(
        name=society_name,
        defaults={'description': '', 'category': 'General'},
    )

    if not _is_society_admin(admin_user, society):
        return JsonResponse({'error': 'Only society admins can add information.'}, status=403)

    info = SocietyInfo.objects.create(
        society=society,
        admin=admin_user,
        title=title,
        content=content,
    )

    return JsonResponse(
        {
            'message': 'Information posted.',
            'info': _serialize_info(info),
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def create_society_poll_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    society_name = _safe_text(data.get('society_name'))
    title = _safe_text(data.get('title'))
    description = _safe_text(data.get('description'))
    options_raw = data.get('options')
    duration_hours_raw = data.get('duration_hours')

    admin_user = _authenticated_user_from_request(request, data=data)

    if not society_name or not title or duration_hours_raw is None:
        return JsonResponse(
            {'error': 'society_name, title and duration_hours are required.'},
            status=400,
        )

    if admin_user is None and not admin_email:
        return JsonResponse({'error': 'Authentication token or admin_email is required.'}, status=400)

    try:
        duration_hours = int(duration_hours_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'duration_hours must be an integer.'}, status=400)

    if duration_hours < 1:
        return JsonResponse({'error': 'duration_hours must be at least 1.'}, status=400)

    if not isinstance(options_raw, list):
        return JsonResponse({'error': 'options must be a list.'}, status=400)

    options = [
        _safe_text(option)
        for option in options_raw
        if isinstance(option, str) and _safe_text(option)
    ]

    # The DB enforces unique option text per poll, so validate duplicates before insert.
    options = list(dict.fromkeys(options))

    if len(options) < 2:
        return JsonResponse({'error': 'At least 2 unique poll options are required.'}, status=400)

    if admin_user is None:
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    society, _ = Society.objects.get_or_create(
        name=society_name,
        defaults={'description': '', 'category': 'General'},
    )

    if not _is_society_admin(admin_user, society):
        return JsonResponse({'error': 'Only society admins can create polls.'}, status=403)

    opens_at = timezone.now()
    closes_at = opens_at + timedelta(hours=duration_hours)

    poll = Poll.objects.create(
        society=society,
        title=title,
        description=description,
        opens_at=opens_at,
        closes_at=closes_at,
    )

    PollOption.objects.bulk_create(
        [PollOption(poll=poll, option_text=option) for option in options]
    )

    return JsonResponse(
        {
            'message': 'Poll created.',
            'poll': _serialize_poll(poll, admin_user),
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def edit_society_poll_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    poll_id_raw = data.get('poll_id')
    action = _safe_text(data.get('action')).lower()

    admin_user = _authenticated_user_from_request(request, data=data)

    if poll_id_raw is None or not action:
        return JsonResponse({'error': 'poll_id and action are required.'}, status=400)

    if admin_user is None and not admin_email:
        return JsonResponse({'error': 'Authentication token or admin_email is required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

    if admin_user is None:
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    if not _is_society_admin(admin_user, poll.society):
        return JsonResponse({'error': 'Only society admins can edit polls.'}, status=403)

    if action == 'add_option':
        option_text = _safe_text(data.get('option_text'))
        if not option_text:
            return JsonResponse({'error': 'option_text is required.'}, status=400)
        PollOption.objects.create(poll=poll, option_text=option_text)

    elif action == 'delete_option':
        option_id_raw = data.get('option_id')
        if option_id_raw is None:
            return JsonResponse({'error': 'option_id is required.'}, status=400)
        try:
            option_id = int(option_id_raw)
        except (TypeError, ValueError):
            return JsonResponse({'error': 'option_id must be an integer.'}, status=400)

        try:
            option = PollOption.objects.get(id=option_id, poll=poll)
        except PollOption.DoesNotExist:
            return JsonResponse({'error': 'Poll option not found.'}, status=404)

        total_options = PollOption.objects.filter(poll=poll).count()
        if total_options <= 2:
            return JsonResponse(
                {'error': 'A poll must keep at least 2 options.'},
                status=400,
            )

        if PollVote.objects.filter(option=option).exists():
            return JsonResponse(
                {'error': 'Cannot delete an option that already has votes.'},
                status=409,
            )

        option.delete()

    else:
        return JsonResponse({'error': 'Unsupported action.'}, status=400)

    return JsonResponse(
        {
            'message': 'Poll updated.',
            'poll': _serialize_poll(poll, admin_user),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def delete_society_poll_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    poll_id_raw = data.get('poll_id')

    admin_user = _authenticated_user_from_request(request, data=data)

    if poll_id_raw is None:
        return JsonResponse({'error': 'poll_id is required.'}, status=400)

    if admin_user is None and not admin_email:
        return JsonResponse({'error': 'Authentication token or admin_email is required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

    if admin_user is None:
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    if not _is_society_admin(admin_user, poll.society):
        return JsonResponse({'error': 'Only society admins can delete polls.'}, status=403)

    poll.delete()
    return JsonResponse({'message': 'Poll deleted.'}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def delete_society_info_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    info_id_raw = data.get('info_id')

    admin_user = _authenticated_user_from_request(request, data=data)

    if info_id_raw is None:
        return JsonResponse({'error': 'info_id is required.'}, status=400)

    if admin_user is None and not admin_email:
        return JsonResponse({'error': 'Authentication token or admin_email is required.'}, status=400)

    try:
        info_id = int(info_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'info_id must be an integer.'}, status=400)

    if admin_user is None:
        try:
            admin_user = User.objects.get(email=admin_email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'Admin user not found for that email.'}, status=404)

    try:
        info = SocietyInfo.objects.select_related('society').get(id=info_id)
    except SocietyInfo.DoesNotExist:
        return JsonResponse({'error': 'Message not found.'}, status=404)

    if not _is_society_admin(admin_user, info.society):
        return JsonResponse({'error': 'Only society admins can delete messages.'}, status=403)

    info.delete()
    return JsonResponse({'message': 'Message deleted.'}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def vote_society_poll_view(request: HttpRequest):
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    poll_id_raw = data.get('poll_id')
    option_id_raw = data.get('option_id')

    user = _authenticated_user_from_request(request, data=data)

    if poll_id_raw is None or option_id_raw is None:
        return JsonResponse({'error': 'poll_id and option_id are required.'}, status=400)

    if user is None and not email:
        return JsonResponse({'error': 'Authentication token or email is required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
        option_id = int(option_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id and option_id must be integers.'}, status=400)

    if user is None:
        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return JsonResponse({'error': 'User not found for that email.'}, status=404)

    try:
        poll = Poll.objects.select_related('society').get(id=poll_id)
    except Poll.DoesNotExist:
        return JsonResponse({'error': 'Poll not found.'}, status=404)

    try:
        option = PollOption.objects.get(id=option_id, poll=poll)
    except PollOption.DoesNotExist:
        return JsonResponse({'error': 'Poll option not found.'}, status=404)

    if not Membership.objects.filter(user=user, society=poll.society).exists():
        return JsonResponse({'error': 'Only members of this society can vote.'}, status=403)

    if not _poll_is_open(poll):
        return JsonResponse({'error': 'This poll is not open for voting.'}, status=400)

    if PollVote.objects.filter(user=user, poll=poll).exists():
        return JsonResponse({'error': 'You can only vote once per poll.'}, status=409)

    PollVote.objects.create(user=user, poll=poll, option=option)

    return JsonResponse(
        {
            'message': 'Vote recorded.',
            'poll': _serialize_poll(poll, user),
        },
        status=201,
    )


@csrf_exempt
@require_http_methods(['POST'])
def update_account_view(request: HttpRequest):
    """Update user account settings (email, password, opt_in_email)."""
    data = _json_body(request)
    
    email = _safe_text(data.get('email')).lower()
    current_password = data.get('current_password') or ''
    new_password = data.get('new_password') or ''
    new_email = _safe_text(data.get('new_email')).lower() if data.get('new_email') else None
    opt_in_email = data.get('opt_in_email')
    
    if not email or not current_password:
        return JsonResponse({'error': 'email and current_password are required.'}, status=400)
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found.'}, status=404)
    
    # Verify current password
    if not user.check_password(current_password):
        return JsonResponse({'error': 'Current password is incorrect.'}, status=401)
    
    # Update email if provided and different
    if new_email and new_email != email:
        if User.objects.filter(email=new_email).exists():
            return JsonResponse({'error': 'An account with that email already exists.'}, status=409)
        user.email = new_email
        user.username = new_email
    
    # Update password if provided
    if new_password:
        user.set_password(new_password)
    
    # Update opt_in_email if provided
    if opt_in_email is not None:
        user.opt_in_email = bool(opt_in_email)
    
    user.save()
    
    return JsonResponse(
        {
            'message': 'Account updated successfully.',
            'user': _user_payload(user),
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['GET'])
def society_review_analytics_view(request: HttpRequest):
    """Get analytics for a society's reviews (monthly trends)."""
    from django.db.models import Count, Avg
    
    society_name = _safe_text(request.GET.get('society'))
    if not society_name:
        return JsonResponse({'error': 'society query parameter is required.'}, status=400)
    
    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)
    
    # Get reviews grouped by month
    reviews = Review.objects.filter(society=society).order_by('created_at')
    
    if not reviews.exists():
        return JsonResponse(
            {
                'society': society.name,
                'total_reviews': 0,
                'average_rating': 0.0,
                'monthly_trends': [],
            },
            status=200,
        )
    
    # Build monthly trends
    trends = {}
    for review in reviews:
        month_key = review.created_at.strftime('%Y-%m')
        if month_key not in trends:
            trends[month_key] = {'count': 0, 'total_rating': 0}
        trends[month_key]['count'] += 1
        trends[month_key]['total_rating'] += review.rating
    
    monthly_trends = [
        {
            'month': month,
            'review_count': data['count'],
            'avg_rating': round(data['total_rating'] / data['count'], 2),
        }
        for month, data in sorted(trends.items())
    ]
    
    total_reviews = reviews.count()
    average_rating = round(sum(r.rating for r in reviews) / total_reviews, 2) if total_reviews > 0 else 0.0
    
    return JsonResponse(
        {
            'society': society.name,
            'total_reviews': total_reviews,
            'average_rating': average_rating,
            'monthly_trends': monthly_trends,
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['GET'])
def get_notifications_view(request: HttpRequest):
    """Get notifications for the authenticated user."""
    email = _safe_text(request.GET.get('email')).lower()
    
    if not email:
        return JsonResponse({'error': 'email query parameter is required.'}, status=400)
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found.'}, status=404)
    
    # Get all notifications for the user, ordered by newest first
    notifications = Notification.objects.filter(user=user).order_by('-created_at')[:50]
    
    notification_data = []
    for notif in notifications:
        data = {
            'id': notif.id,
            'type': notif.notification_type,
            'title': notif.title,
            'message': notif.message,
            'is_read': notif.is_read,
            'created_at': notif.created_at.isoformat(),
        }
        if notif.related_poll:
            data['poll_id'] = notif.related_poll.id
        if notif.related_review:
            data['review_id'] = notif.related_review.id
        notification_data.append(data)
    
    unread_count = Notification.objects.filter(user=user, is_read=False).count()
    
    return JsonResponse(
        {
            'notifications': notification_data,
            'unread_count': unread_count,
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def mark_notification_read_view(request: HttpRequest):
    """Mark a notification as read."""
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    notification_id_raw = data.get('notification_id')
    
    if not email or notification_id_raw is None:
        return JsonResponse({'error': 'email and notification_id are required.'}, status=400)
    
    try:
        notification_id = int(notification_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'notification_id must be an integer.'}, status=400)
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found.'}, status=404)
    
    try:
        notification = Notification.objects.get(id=notification_id, user=user)
    except Notification.DoesNotExist:
        return JsonResponse({'error': 'Notification not found.'}, status=404)
    
    notification.is_read = True
    notification.read_at = timezone.now()
    notification.save()
    
    return JsonResponse({'message': 'Notification marked as read.'}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def mark_all_notifications_read_view(request: HttpRequest):
    """Mark all notifications for a user as read."""
    data = _json_body(request)
    email = _safe_text(data.get('email')).lower()
    
    if not email:
        return JsonResponse({'error': 'email is required.'}, status=400)
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'User not found.'}, status=404)
    
    unread_notifications = Notification.objects.filter(user=user, is_read=False)
    count = unread_notifications.update(is_read=True, read_at=timezone.now())
    
    return JsonResponse(
        {
            'message': f'{count} notification(s) marked as read.',
            'count': count,
        },
        status=200,
    )


@csrf_exempt
@require_http_methods(['POST'])
def check_closing_polls_view(request: HttpRequest):
    """Check for polls closing soon and create notifications."""
    _check_and_notify_closing_polls()
    return JsonResponse(
        {'message': 'Closing poll check completed.'},
        status=200,
    )
