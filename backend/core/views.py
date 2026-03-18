from rest_framework import viewsets, status
from rest_framework.decorators import api_view, action
from rest_framework.response import Response
from rest_framework.reverse import reverse
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse
from django.db.models import Count, Q
from .serializers import RegisterSerializer
from .models import (
    Society,
    Membership,
    Poll,
    PollOption,
    PollVote,
    Review,
    ReviewResponse,
    ReviewReaction
)

from .serializers import (
    SocietySerializer,
    MembershipSerializer,
    PollSerializer,
    PollOptionSerializer,
    PollVoteSerializer,
    ReviewSerializer,
    ReviewResponseSerializer,
    ReviewReactionSerializer
)


class SocietyViewSet(viewsets.ModelViewSet):
    queryset = Society.objects.all()
    serializer_class = SocietySerializer
    permission_classes = [AllowAny]

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


class PollViewSet(viewsets.ModelViewSet):
    queryset = Poll.objects.all()
    serializer_class = PollSerializer
    permission_classes = [AllowAny]

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
    permission_classes = [AllowAny]


class PollVoteViewSet(viewsets.ModelViewSet):
    queryset = PollVote.objects.all()
    serializer_class = PollVoteSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        """Automatically set the user when creating a vote"""
        serializer.save(user=self.request.user)


class ReviewViewSet(viewsets.ModelViewSet):
    queryset = Review.objects.all()
    serializer_class = ReviewSerializer
    permission_classes = [AllowAny]

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


class ReviewReactionViewSet(viewsets.ModelViewSet):
    queryset = ReviewReaction.objects.all()
    serializer_class = ReviewReactionSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        """Automatically set the user when creating a reaction"""
        serializer.save(user=self.request.user)

@api_view(['POST'])
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
        'register': reverse('register', request=request),
        'login': reverse('login', request=request),
        'me': reverse('me', request=request),
    })