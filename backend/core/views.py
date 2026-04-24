import json
import re
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db.models import Count, Q
from django.http import HttpRequest, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import (
    Membership,
    Poll,
    PollOption,
    PollVote,
    Review,
    ReviewReaction,
    ReviewResponse,
    Society,
    SocietyInfo,
)

User = get_user_model()

REVIEW_MAX_COMMENT_LENGTH = 500
MIN_MEMBERSHIP_DAYS_FOR_REVIEW = 14
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


def _is_admin_account(user: User) -> bool:
    return user.up_number.upper().startswith('A')


def _is_society_admin(user: User, society: Society) -> bool:
    if _is_admin_account(user):
        return True
    return Membership.objects.filter(
        user=user,
        society=society,
        role='admin',
    ).exists()


def _contains_offensive_language(comment: str) -> bool:
    lowered = comment.lower()
    return any(
        re.search(rf'\b{re.escape(term)}\b', lowered) for term in BANNED_REVIEW_TERMS
    )


def _membership_for_user(user: User, society: Society) -> Membership | None:
    try:
        return Membership.objects.get(user=user, society=society)
    except Membership.DoesNotExist:
        return None


def _review_block_reason(user: User, society: Society) -> str | None:
    if _is_admin_account(user):
        return 'Admins cannot create reviews.'

    membership = _membership_for_user(user, society)
    if membership is None:
        return 'Only members of this society can leave a review.'

    if membership.created_at > timezone.now() - timedelta(days=MIN_MEMBERSHIP_DAYS_FOR_REVIEW):
        return 'You need to be a member for at least 2 weeks before reviewing.'

    if Review.objects.filter(user=user, society=society).exists():
        return 'You already have an active review for this society.'

    return None


def _poll_is_open(poll: Poll) -> bool:
    now = timezone.now()
    return poll.opens_at <= now <= poll.closes_at


def _serialize_poll(poll: Poll, viewer) -> dict:
    options = list(PollOption.objects.filter(poll=poll).order_by('id'))
    option_ids = [option.id for option in options]

    vote_counts = {
        row['option_id']: row['count']
        for row in (
            PollVote.objects.filter(option_id__in=option_ids)
            .values('option_id')
            .annotate(count=Count('id'))
        )
    }

    total_votes = sum(vote_counts.values())
    viewer_vote_option_id = None
    if viewer is not None:
        viewer_vote = PollVote.objects.filter(user=viewer, poll=poll).first()
        viewer_vote_option_id = viewer_vote.option_id if viewer_vote else None

    return {
        'id': poll.id,
        'title': poll.title,
        'description': poll.description,
        'created_at': poll.created_at.isoformat(),
        'opens_at': poll.opens_at.isoformat(),
        'closes_at': poll.closes_at.isoformat(),
        'is_open': _poll_is_open(poll),
        'total_votes': total_votes,
        'viewer_vote_option_id': viewer_vote_option_id,
        'options': [
            {
                'id': option.id,
                'text': option.option_text,
                'votes': vote_counts.get(option.id, 0),
            }
            for option in options
        ],
    }


def _finalize_closed_polls(society: Society):
    now = timezone.now()
    closed_polls = Poll.objects.filter(
        society=society,
        closes_at__lt=now,
        ended_posted_as_info=False,
    ).order_by('closes_at')

    admin_membership = (
        Membership.objects.select_related('user')
        .filter(society=society, role='admin')
        .order_by('created_at')
        .first()
    )
    if admin_membership is None:
        return

    admin_user = admin_membership.user

    for poll in closed_polls:
        options = list(PollOption.objects.filter(poll=poll).order_by('id'))
        option_ids = [option.id for option in options]

        vote_counts = {
            row['option_id']: row['count']
            for row in (
                PollVote.objects.filter(option_id__in=option_ids)
                .values('option_id')
                .annotate(count=Count('id'))
            )
        }
        total_votes = sum(vote_counts.values())

        if options:
            sorted_options = sorted(
                options,
                key=lambda option: vote_counts.get(option.id, 0),
                reverse=True,
            )
            top_votes = vote_counts.get(sorted_options[0].id, 0)
            winners = [
                option.option_text
                for option in sorted_options
                if vote_counts.get(option.id, 0) == top_votes
            ]
            winner_text = ', '.join(winners) if winners else 'No winner'
            result_parts = [
                f"{option.option_text} ({vote_counts.get(option.id, 0)})"
                for option in options
            ]
            results_summary = '; '.join(result_parts)
        else:
            winner_text = 'No options'
            results_summary = 'No options were available.'

        SocietyInfo.objects.create(
            society=society,
            admin=admin_user,
            title=f"Poll ended: {poll.title}",
            content=(
                f"Winner: {winner_text}. Total votes: {total_votes}. "
                f"Results: {results_summary}"
            ),
        )

        poll.ended_posted_as_info = True
        poll.save(update_fields=['ended_posted_as_info'])


def _serialize_info(info: SocietyInfo) -> dict:
    return {
        'id': info.id,
        'title': info.title,
        'content': info.content,
        'created_at': info.created_at.isoformat(),
        'admin_display_name': _author_display_name(info.admin),
    }


@csrf_exempt
@require_http_methods(['POST'])
def register_view(request: HttpRequest):
    data = _json_body(request)

    name = _safe_text(data.get('name'))
    email = _safe_text(data.get('email')).lower()
    password = data.get('password') or ''

    if not name or not email or not password:
        return JsonResponse({'error': 'All fields are required.'}, status=400)

    if '@' not in email or '.' not in email:
        return JsonResponse({'error': 'Enter a valid email address.'}, status=400)

    if User.objects.filter(email=email).exists():
        return JsonResponse({'error': 'An account with that email already exists.'}, status=409)

    user = User.objects.create_user(username=email, email=email, password=password)
    user.first_name = name
    user.save()

    return JsonResponse(
        {
            'message': 'Registration successful.',
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
            },
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
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
            },
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

    membership, created = Membership.objects.get_or_create(
        user=user,
        society=society,
        defaults={'role': 'member'},
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
        }
        for membership in memberships
    ]

    return JsonResponse({'societies': societies}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def society_members_view(request: HttpRequest):
    data = _json_body(request)
    society_name = _safe_text(data.get('society_name'))

    viewer_email = _safe_text(data.get('viewer_email')).lower()

    if not society_name:
        return JsonResponse({'error': 'society_name is required.'}, status=400)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    memberships = (
        Membership.objects.select_related('user')
        .filter(society=society)
        .order_by('user__up_number')
    )

    # Determine whether the requesting viewer is an admin of this society
    viewer = None
    viewer_is_admin = False
    if viewer_email:
        try:
            viewer = User.objects.get(email=viewer_email)
            viewer_is_admin = _is_society_admin(viewer, society)
        except User.DoesNotExist:
            viewer = None

    members = [
        {
            'id': m.user.id,
            'up_number': m.user.up_number,
            'email': m.user.email,
            'display_name': _author_display_name(m.user),
            'role': m.role,
        }
        for m in memberships
    ]

    return JsonResponse({'members': members, 'viewer_is_admin': viewer_is_admin}, status=200)


@csrf_exempt
@require_http_methods(['POST'])
def promote_member_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    society_name = _safe_text(data.get('society_name'))
    member_id = data.get('member_id')

    if not admin_email or not society_name or not member_id:
        return JsonResponse({'error': 'admin_email, society_name and member_id are required.'}, status=400)

    try:
        admin_user = User.objects.get(email=admin_email)
    except User.DoesNotExist:
        return JsonResponse({'error': 'Admin user not found.'}, status=404)

    try:
        society = Society.objects.get(name=society_name)
    except Society.DoesNotExist:
        return JsonResponse({'error': 'Society not found.'}, status=404)

    if not _is_society_admin(admin_user, society):
        return JsonResponse({'error': 'You are not a society admin.'}, status=403)

    try:
        membership = Membership.objects.get(user_id=int(member_id), society=society)
    except (Membership.DoesNotExist, ValueError):
        return JsonResponse({'error': 'Membership not found for that user.'}, status=404)

    if membership.role == 'admin':
        return JsonResponse({'message': 'Member is already an admin.'}, status=200)

    membership.role = 'admin'
    membership.save(update_fields=['role'])

    return JsonResponse({'message': 'Member promoted to admin.'}, status=200)


@csrf_exempt
@require_http_methods(['GET'])
def society_reviews_view(request: HttpRequest):
    society_name = _safe_text(request.GET.get('society'))
    sort_by = _safe_text(request.GET.get('sort')).lower() or 'latest'
    viewer_email = _safe_text(request.GET.get('viewer_email')).lower()
    min_rating_raw = _safe_text(request.GET.get('min_rating'))

    if not society_name:
        return JsonResponse({'error': 'society query parameter is required.'}, status=400)

    society, _ = Society.objects.get_or_create(
        name=society_name,
        defaults={'description': '', 'category': 'General'},
    )

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
        likes_count=Count(
            'reviewreaction',
            filter=Q(reviewreaction__reaction_type='like'),
        ),
        dislikes_count=Count(
            'reviewreaction',
            filter=Q(reviewreaction__reaction_type='dislike'),
        ),
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
        user_reaction_map = {
            reaction.review_id: reaction.reaction_type
            for reaction in reactions
        }

    viewer_is_admin = False
    viewer_can_react = False
    can_create_review = False
    review_block_reason = None
    has_active_review = False

    if viewer is not None:
        viewer_is_admin = _is_society_admin(viewer, society)
        viewer_can_react = (
            not _is_admin_account(viewer)
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

    review = Review.objects.create(
        user=user,
        society=society,
        rating=rating,
        comment=comment,
    )

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

    if _is_admin_account(user):
        return JsonResponse({'error': 'Admins cannot like or dislike reviews.'}, status=403)

    if not Membership.objects.filter(user=user, society=review.society).exists():
        return JsonResponse({'error': 'Only members of this society can react.'}, status=403)

    if ReviewReaction.objects.filter(user=user, review=review).exists():
        return JsonResponse({'error': 'You can only react to a review once.'}, status=409)

    ReviewReaction.objects.create(
        user=user,
        review=review,
        reaction_type=reaction_type,
    )

    likes = ReviewReaction.objects.filter(review=review, reaction_type='like').count()
    dislikes = ReviewReaction.objects.filter(review=review, reaction_type='dislike').count()

    return JsonResponse(
        {
            'message': 'Reaction recorded.',
            'likes': likes,
            'dislikes': dislikes,
            'user_reaction': reaction_type,
            'reactor_up_number': user.up_number,
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
        return JsonResponse({'error': 'Only society admins can delete reviews.'}, status=403)

    review.delete()
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
        return JsonResponse({'error': 'Only society admins can respond to reviews.'}, status=403)

    response, created = ReviewResponse.objects.update_or_create(
        review=review,
        defaults={
            'admin': admin_user,
            'response_text': response_text,
        },
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

    viewer = None
    if viewer_email:
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


@csrf_exempt
@require_http_methods(['POST'])
def create_society_info_view(request: HttpRequest):
    data = _json_body(request)
    admin_email = _safe_text(data.get('admin_email')).lower()
    society_name = _safe_text(data.get('society_name'))
    title = _safe_text(data.get('title'))
    content = _safe_text(data.get('content'))

    if not admin_email or not society_name or not content:
        return JsonResponse(
            {'error': 'admin_email, society_name and content are required.'},
            status=400,
        )

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
    duration_minutes_raw = data.get('duration_minutes')

    if not admin_email or not society_name or not title or duration_minutes_raw is None:
        return JsonResponse(
            {'error': 'admin_email, society_name, title and duration_minutes are required.'},
            status=400,
        )

    try:
        duration_minutes = int(duration_minutes_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'duration_minutes must be an integer.'}, status=400)

    if duration_minutes < 1:
        return JsonResponse({'error': 'duration_minutes must be at least 1.'}, status=400)

    if not isinstance(options_raw, list):
        return JsonResponse({'error': 'options must be a list.'}, status=400)

    options = [
        _safe_text(option)
        for option in options_raw
        if isinstance(option, str) and _safe_text(option)
    ]

    if len(options) < 2:
        return JsonResponse({'error': 'At least 2 poll options are required.'}, status=400)

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
    closes_at = opens_at + timedelta(minutes=duration_minutes)

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

    if not admin_email or poll_id_raw is None or not action:
        return JsonResponse({'error': 'admin_email, poll_id and action are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

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

    if not admin_email or poll_id_raw is None:
        return JsonResponse({'error': 'admin_email and poll_id are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id must be an integer.'}, status=400)

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

    if not admin_email or info_id_raw is None:
        return JsonResponse({'error': 'admin_email and info_id are required.'}, status=400)

    try:
        info_id = int(info_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'info_id must be an integer.'}, status=400)

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

    if not email or poll_id_raw is None or option_id_raw is None:
        return JsonResponse({'error': 'email, poll_id and option_id are required.'}, status=400)

    try:
        poll_id = int(poll_id_raw)
        option_id = int(option_id_raw)
    except (TypeError, ValueError):
        return JsonResponse({'error': 'poll_id and option_id must be integers.'}, status=400)

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