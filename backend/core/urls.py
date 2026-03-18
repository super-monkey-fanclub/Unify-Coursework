from rest_framework.routers import DefaultRouter
from .views import register, login, me, api_root
from django.urls import path
from .views import (
    SocietyViewSet,
    MembershipViewSet,
    PollViewSet,
    PollOptionViewSet,
    PollVoteViewSet,
    ReviewViewSet,
    ReviewResponseViewSet,
    ReviewReactionViewSet
)

router = DefaultRouter()

router.register(r'societies', SocietyViewSet)
router.register(r'memberships', MembershipViewSet)
router.register(r'polls', PollViewSet)
router.register(r'poll-options', PollOptionViewSet)
router.register(r'poll-votes', PollVoteViewSet)
router.register(r'reviews', ReviewViewSet)
router.register(r'review-responses', ReviewResponseViewSet)
router.register(r'review-reactions', ReviewReactionViewSet)

urlpatterns = [
    path('', api_root, name='api-root'),
] + router.urls + [
    path('register/', register, name='register'),
    path('login/', login, name='login'),
    path('me/', me, name='me'),
]