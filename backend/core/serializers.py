from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Membership
from .models import (
    User,
    Society,
    Membership,
    Poll,
    PollOption,
    PollVote,
    Review,
    ReviewResponse,
    ReviewReaction
)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "up_number", "opt_in_email"]


class SocietySerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()
    is_member = serializers.SerializerMethodField()
    
    class Meta:
        model = Society
        fields = ["id", "name", "description", "category", "created_at", "member_count", "is_member"]
    
    def get_member_count(self, obj):
        return Membership.objects.filter(society=obj).count()
    
    def get_is_member(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Membership.objects.filter(society=obj, user=request.user).exists()
        return False


class MembershipSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    society_name = serializers.CharField(source='society.name', read_only=True)
    
    class Meta:
        model = Membership
        fields = ["id", "user", "user_username", "society", "society_name", "role", "created_at"]


class PollSerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()
    total_votes = serializers.SerializerMethodField()
    
    class Meta:
        model = Poll
        fields = ["id", "society", "title", "description", "opens_at", "closes_at", "created_at", "options", "total_votes"]
    
    def get_total_votes(self, obj):
        return PollVote.objects.filter(poll=obj).count()

    def get_options(self, obj):
        options = PollOption.objects.filter(poll=obj)
        return PollOptionSerializer(options, many=True).data


class PollOptionSerializer(serializers.ModelSerializer):
    vote_count = serializers.SerializerMethodField()
    
    class Meta:
        model = PollOption
        fields = ["id", "poll", "option_text", "vote_count"]
    
    def get_vote_count(self, obj):
        return PollVote.objects.filter(option=obj).count()


class PollVoteSerializer(serializers.ModelSerializer):

    class Meta:
        model = PollVote
        fields = "__all__"

    def validate(self, data):
        user = data["user"]
        poll = data["poll"]

        #check if user is a member of the society
        if not Membership.objects.filter(user=user, society=poll.society).exists():
            raise serializers.ValidationError(
                "Only members of this society can vote in its polls."
            )

        #prevent double voting
        if PollVote.objects.filter(user=user, poll=poll).exists():
            raise serializers.ValidationError(
                "You have already voted in this poll."
            )

        return data


class ReviewSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    response_count = serializers.SerializerMethodField()
    reaction_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Review
        fields = ["id", "user", "user_username", "society", "rating", "comment", "created_at", "response_count", "reaction_count"]
    
    def get_response_count(self, obj):
        return ReviewResponse.objects.filter(review=obj).count()
    
    def get_reaction_count(self, obj):
        return ReviewReaction.objects.filter(review=obj).count()


class ReviewResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewResponse
        fields = "__all__"


class ReviewReactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewReaction
        fields = "__all__"

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ("username", "email", "password", "up_number")

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            up_number=validated_data["up_number"]
        )
        return user