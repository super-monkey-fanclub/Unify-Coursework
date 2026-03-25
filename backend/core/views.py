from rest_framework import viewsets, status
from rest_framework.decorators import api_view, action, throttle_classes
from rest_framework.response import Response
from rest_framework.reverse import reverse
from rest_framework.permissions import IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.filters import SearchFilter, OrderingFilter
from rest_framework.exceptions import PermissionDenied
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from django.db.models import Count, Avg
from .serializers import RegisterSerializer
from .permissions import IsOwnerOrReadOnly, IsSocietyAdminForObject
from .throttles import RegisterRateThrottle, LoginRateThrottle, WriteActionRateThrottle
from .models import (
    Society,
    Membership,
    Poll,
    PollOption,
    PollVote,
    Review,
    ReviewResponse,
    ReviewReaction,
    Notification,
    Event,
    EventRSVP,
)

from .serializers import (
    SocietySerializer,
    MembershipSerializer,
    PollSerializer,
    PollOptionSerializer,
    PollVoteSerializer,
    ReviewSerializer,
    ReviewResponseSerializer,
    ReviewReactionSerializer,
    NotificationSerializer,
    EventSerializer,
    EventRSVPSerializer,
)


class SocietyViewSet(viewsets.ModelViewSet):
    queryset = Society.objects.all()
    serializer_class = SocietySerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ["name", "category", "description"]
    ordering_fields = ["created_at", "name"]
    ordering = ["-created_at"]

    def get_queryset(self):
        queryset = Society.objects.all().annotate(avg_rating=Avg("review__rating"))

        category = self.request.query_params.get("category")
        min_rating = self.request.query_params.get("min_rating")
        joined_only = self.request.query_params.get("joined")

        if category:
            queryset = queryset.filter(category__iexact=category)

        if min_rating:
            try:
                queryset = queryset.filter(avg_rating__gte=float(min_rating))
            except ValueError:
                pass

        if joined_only == "true" and self.request.user.is_authenticated:
            queryset = queryset.filter(membership__user=self.request.user)

        return queryset

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def join(self, request, pk=None):
        """Join a society"""
        society = self.get_object()
        user = request.user
        
        if Membership.objects.filter(user=user, society=society).exists():
            return Response(
                {"detail": "You are already a member of this society"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        membership = Membership.objects.create(
            user=user,
            society=society,
            role='member'
        )

        admins = Membership.objects.filter(society=society, role='admin').select_related('user')
        Notification.objects.bulk_create([
            Notification(
                user=admin.user,
                title="New member joined",
                message=f"{user.username} joined {society.name}.",
            )
            for admin in admins
            if admin.user_id != user.id
        ])

        return Response(
            {"detail": "Successfully joined society", "membership_id": membership.id},
            status=status.HTTP_201_CREATED
        )

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def leave(self, request, pk=None):
        """Leave a society"""
        society = self.get_object()
        user = request.user
        
        try:
            membership = Membership.objects.get(user=user, society=society)
            membership.delete()
            return Response({"detail": "Successfully left society"})
        except Membership.DoesNotExist:
            return Response(
                {"detail": "You are not a member of this society"},
                status=status.HTTP_400_BAD_REQUEST
            )

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def my_societies(self, request):
        """Get the current user's societies"""
        memberships = Membership.objects.filter(user=request.user).select_related('society')
        societies = [m.society for m in memberships]
        serializer = self.get_serializer(societies, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """Get all members of a society"""
        society = self.get_object()
        memberships = Membership.objects.filter(society=society).select_related('user')
        data = [
            {
                "id": m.user.id,
                "username": m.user.username,
                "role": m.role,
                "joined_at": m.created_at
            }
            for m in memberships
        ]
        return Response(data)


class MembershipViewSet(viewsets.ModelViewSet):
    queryset = Membership.objects.all()
    serializer_class = MembershipSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.is_staff:
            return Membership.objects.all()
        return Membership.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        society = serializer.validated_data["society"]

        if Membership.objects.filter(user=self.request.user, society=society).exists():
            raise PermissionDenied("You are already a member of this society.")

        serializer.save(user=self.request.user, role="member")


class PollViewSet(viewsets.ModelViewSet):
    queryset = Poll.objects.all()
    serializer_class = PollSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ["title", "description"]
    ordering_fields = ["created_at", "opens_at", "closes_at"]
    ordering = ["-created_at"]

    def get_permissions(self):
        if self.action == "create":
            return [IsAuthenticated()]
        if self.action in ["update", "partial_update", "destroy"]:
            return [IsAuthenticated(), IsSocietyAdminForObject()]
        return super().get_permissions()

    def perform_create(self, serializer):
        society = serializer.validated_data["society"]
        is_admin = Membership.objects.filter(
            user=self.request.user,
            society=society,
            role="admin",
        ).exists()

        if not is_admin:
            raise PermissionDenied("You must be a society admin to create polls.")

        poll = serializer.save()
        members = Membership.objects.filter(society=society).select_related("user")
        Notification.objects.bulk_create([
            Notification(
                user=member.user,
                title="New poll created",
                message=f"{poll.title} was posted in {society.name}.",
            )
            for member in members
            if member.user_id != self.request.user.id
        ])

    @action(detail=True, methods=['get'])
    def results(self, request, pk=None):
        """Get poll results with vote counts per option"""
        poll = self.get_object()
        options = PollOption.objects.filter(poll=poll).annotate(
            vote_count=Count('pollvote')
        )
        total_votes = PollVote.objects.filter(poll=poll).count()
        
        results = [
            {
                "id": option.id,
                "option_text": option.option_text,
                "votes": option.vote_count,
                "percentage": (option.vote_count / total_votes * 100) if total_votes > 0 else 0
            }
            for option in options
        ]
        
        return Response({
            "poll_id": poll.id,
            "title": poll.title,
            "total_votes": total_votes,
            "options": results
        })

    @action(detail=True, methods=['get'], permission_classes=[IsAuthenticated])
    def my_vote(self, request, pk=None):
        """Get current user's vote on this poll"""
        poll = self.get_object()
        try:
            vote = PollVote.objects.get(user=request.user, poll=poll)
            return Response({
                "voted": True,
                "option_id": vote.option.id,
                "option_text": vote.option.option_text
            })
        except PollVote.DoesNotExist:
            return Response({"voted": False})


class PollOptionViewSet(viewsets.ModelViewSet):
    queryset = PollOption.objects.all()
    serializer_class = PollOptionSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_permissions(self):
        if self.action == "create":
            return [IsAuthenticated()]
        if self.action in ["update", "partial_update", "destroy"]:
            return [IsAuthenticated(), IsSocietyAdminForObject()]
        return super().get_permissions()

    def perform_create(self, serializer):
        poll = serializer.validated_data["poll"]
        is_admin = Membership.objects.filter(
            user=self.request.user,
            society=poll.society,
            role="admin",
        ).exists()

        if not is_admin:
            raise PermissionDenied("You must be a society admin to add poll options.")

        serializer.save()


class PollVoteViewSet(viewsets.ModelViewSet):
    queryset = PollVote.objects.all()
    serializer_class = PollVoteSerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [WriteActionRateThrottle]

    def perform_create(self, serializer):
        """Automatically set the user when creating a vote"""
        serializer.save(user=self.request.user)


class ReviewViewSet(viewsets.ModelViewSet):
    queryset = Review.objects.all()
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ["comment", "society__name", "user__username"]
    ordering_fields = ["created_at", "rating"]
    ordering = ["-created_at"]

    def get_permissions(self):
        if self.action in ["update", "partial_update", "destroy"]:
            return [IsAuthenticated(), IsOwnerOrReadOnly()]
        return super().get_permissions()

    def get_queryset(self):
        queryset = Review.objects.all()

        society_id = self.request.query_params.get("society")
        rating = self.request.query_params.get("rating")

        if society_id:
            queryset = queryset.filter(society_id=society_id)

        if rating:
            try:
                queryset = queryset.filter(rating=int(rating))
            except ValueError:
                pass

        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def my_reviews(self, request):
        """Get reviews written by the current user"""
        reviews = Review.objects.filter(user=request.user)
        serializer = self.get_serializer(reviews, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def society_reviews(self, request, pk=None):
        """Get all reviews for a specific society"""
        review = self.get_object()
        reviews = Review.objects.filter(society=review.society).order_by('-created_at')
        serializer = self.get_serializer(reviews, many=True)
        return Response(serializer.data)


class ReviewResponseViewSet(viewsets.ModelViewSet):
    queryset = ReviewResponse.objects.all()
    serializer_class = ReviewResponseSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        review = serializer.validated_data["review"]
        is_admin = Membership.objects.filter(
            user=self.request.user,
            society=review.society,
            role="admin",
        ).exists()

        if not is_admin:
            raise PermissionDenied("Only society admins can respond to reviews.")

        response = serializer.save(admin=self.request.user)
        Notification.objects.create(
            user=review.user,
            title="Review response",
            message=f"An admin responded to your review in {review.society.name}.",
        )
        return response


class ReviewReactionViewSet(viewsets.ModelViewSet):
    queryset = ReviewReaction.objects.all()
    serializer_class = ReviewReactionSerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [WriteActionRateThrottle]

    def get_queryset(self):
        if self.request.user.is_staff:
            return ReviewReaction.objects.all()
        return ReviewReaction.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        """Automatically set the user when creating a reaction"""
        serializer.save(user=self.request.user)


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=["post"])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=["is_read"])
        return Response({"detail": "Notification marked as read."})

    @action(detail=False, methods=["post"])
    def mark_all_read(self, request):
        updated = Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({"detail": f"Marked {updated} notifications as read."})


class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.all()
    serializer_class = EventSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    filter_backends = [SearchFilter, OrderingFilter]
    search_fields = ["title", "description", "location", "society__name"]
    ordering_fields = ["starts_at", "created_at"]
    ordering = ["starts_at"]

    def get_permissions(self):
        if self.action == "create":
            return [IsAuthenticated()]
        if self.action in ["update", "partial_update", "destroy"]:
            return [IsAuthenticated(), IsSocietyAdminForObject()]
        return super().get_permissions()

    def perform_create(self, serializer):
        society = serializer.validated_data["society"]
        is_admin = Membership.objects.filter(
            user=self.request.user,
            society=society,
            role="admin",
        ).exists()

        if not is_admin:
            raise PermissionDenied("You must be a society admin to create events.")

        event = serializer.save(created_by=self.request.user)
        members = Membership.objects.filter(society=society).select_related("user")
        Notification.objects.bulk_create([
            Notification(
                user=member.user,
                title="New event added",
                message=f"{event.title} is scheduled for {society.name}.",
            )
            for member in members
            if member.user_id != self.request.user.id
        ])


class EventRSVPViewSet(viewsets.ModelViewSet):
    queryset = EventRSVP.objects.all()
    serializer_class = EventRSVPSerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [WriteActionRateThrottle]

    def get_queryset(self):
        if self.request.user.is_staff:
            return EventRSVP.objects.all()
        return EventRSVP.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        serializer.save(user=self.request.user)

@api_view(['POST'])
@throttle_classes([RegisterRateThrottle])
def register(request):

    serializer = RegisterSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.save()

        refresh = RefreshToken.for_user(user)

        return Response({
            "user": serializer.data,
            "access": str(refresh.access_token),
            "refresh": str(refresh)
        })

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@throttle_classes([LoginRateThrottle])
def login(request):

    username = request.data.get("username")
    password = request.data.get("password")

    user = authenticate(username=username, password=password)

    if user is None:
        return Response({"error": "Invalid credentials"}, status=401)

    refresh = RefreshToken.for_user(user)

    return Response({
        "access": str(refresh.access_token),
        "refresh": str(refresh)
    })


@api_view(['GET'])
def me(request):

    if request.user.is_authenticated:
        return Response({
            "id": request.user.id,
            "username": request.user.username,
            "email": request.user.email
        })

    return Response({"error": "Not authenticated"}, status=401)


@api_view(['GET'])
def home(request):
    return Response({
        "message": "Welcome to Unify API",
        "version": "1.0.0",
        "endpoints": {
            "admin": "/admin/",
            "api": "/api/",
            "register": "/api/register/",
            "login": "/api/login/",
            "me": "/api/me/",
            "societies": "/api/societies/",
            "polls": "/api/polls/",
            "reviews": "/api/reviews/"
        }
    })


@api_view(['GET'])
def api_root(request):
    """API root showing all available endpoints"""
    return Response({
        'societies': reverse('society-list', request=request),
        'memberships': reverse('membership-list', request=request),
        'polls': reverse('poll-list', request=request),
        'poll_options': reverse('polloption-list', request=request),
        'poll_votes': reverse('pollvote-list', request=request),
        'reviews': reverse('review-list', request=request),
        'review_responses': reverse('reviewresponse-list', request=request),
        'review_reactions': reverse('reviewreaction-list', request=request),
        'notifications': reverse('notification-list', request=request),
        'events': reverse('event-list', request=request),
        'event_rsvps': reverse('eventrsvp-list', request=request),
        'register': reverse('register', request=request),
        'login': reverse('login', request=request),
        'me': reverse('me', request=request),
    })