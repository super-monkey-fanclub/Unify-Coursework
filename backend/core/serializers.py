from rest_framework import serializers
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
    class Meta:
        model = Society
        fields = "__all__"


class MembershipSerializer(serializers.ModelSerializer):
    class Meta:
        model = Membership
        fields = "__all__"


class PollSerializer(serializers.ModelSerializer):
    class Meta:
        model = Poll
        fields = "__all__"


class PollOptionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PollOption
        fields = "__all__"


class PollVoteSerializer(serializers.ModelSerializer):
    class Meta:
        model = PollVote
        fields = "__all__"


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = "__all__"


class ReviewResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewResponse
        fields = "__all__"


class ReviewReactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewReaction
        fields = "__all__"