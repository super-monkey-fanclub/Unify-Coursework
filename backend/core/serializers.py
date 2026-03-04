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