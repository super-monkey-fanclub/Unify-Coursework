from rest_framework.routers import DefaultRouter
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

urlpatterns = router.urls