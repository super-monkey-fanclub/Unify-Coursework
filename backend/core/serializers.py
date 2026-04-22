from datetime import timedelta
import re

from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import check_password
from django.conf import settings
from django.utils import timezone
from .models import (
    User,
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

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "username", "email", "up_number", "opt_in_email"]


class SocietySerializer(serializers.ModelSerializer):
    member_count = serializers.SerializerMethodField()
    is_member = serializers.SerializerMethodField()
    avg_rating = serializers.SerializerMethodField()
    
    class Meta:
        model = Society
        fields = ["id", "name", "description", "category", "created_at", "member_count", "is_member", "avg_rating"]
    
    def get_member_count(self, obj):
        return getattr(obj, "member_count", Membership.objects.filter(society=obj).count())
    
    def get_is_member(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return Membership.objects.filter(society=obj, user=request.user).exists()
        return False

    def get_avg_rating(self, obj):
        avg_rating = getattr(obj, "avg_rating", None)
        return round(avg_rating, 1) if avg_rating is not None else None


class MembershipSerializer(serializers.ModelSerializer):
    user_username = serializers.CharField(source='user.username', read_only=True)
    society_name = serializers.CharField(source='society.name', read_only=True)
    
    class Meta:
        model = Membership
        fields = ["id", "user", "user_username", "society", "society_name", "role", "created_at"]
        read_only_fields = ["user", "role", "created_at"]


class PollSerializer(serializers.ModelSerializer):
    options = serializers.SerializerMethodField()
    total_votes = serializers.SerializerMethodField()
    
    class Meta:
        model = Poll
        fields = ["id", "society", "title", "description", "opens_at", "closes_at", "created_at", "options", "total_votes"]
        read_only_fields = ["created_at", "options", "total_votes"]

    def validate(self, data):
        opens_at = data.get("opens_at", getattr(self.instance, "opens_at", None))
        closes_at = data.get("closes_at", getattr(self.instance, "closes_at", None))
        society = data.get("society", getattr(self.instance, "society", None))
        title = data.get("title", getattr(self.instance, "title", None))
        description = data.get("description", getattr(self.instance, "description", None))

        if opens_at and closes_at and opens_at >= closes_at:
            raise serializers.ValidationError("opens_at must be earlier than closes_at.")

        if opens_at and closes_at:
            duration = closes_at - opens_at
            if duration < timedelta(hours=24):
                raise serializers.ValidationError("Polls must run for at least 24 hours.")
            if duration > timedelta(days=7):
                raise serializers.ValidationError("Polls must run for no more than 7 days.")

        if society and title and description:
            duplicate_query = Poll.objects.filter(
                society=society,
                title__iexact=title,
                description__iexact=description,
            )
            if self.instance is not None:
                duplicate_query = duplicate_query.exclude(pk=self.instance.pk)
            if duplicate_query.exists():
                raise serializers.ValidationError("An identical poll already exists for this society.")

        return data
    
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
        fields = ["id", "poll", "option", "created_at"]
        read_only_fields = ["created_at"]

    def validate(self, data):
        request = self.context.get("request")
        user = request.user if request and request.user.is_authenticated else data.get("user")
        poll = data.get("poll")
        option = data.get("option")

        if user is None:
            raise serializers.ValidationError("Authentication is required to vote.")

        if poll is None or option is None:
            raise serializers.ValidationError("Both poll and option are required.")

        if option.poll_id != poll.id:
            raise serializers.ValidationError("Selected option does not belong to this poll.")

        now = timezone.now()
        if now < poll.opens_at:
            raise serializers.ValidationError("This poll is not open yet.")
        if now > poll.closes_at:
            raise serializers.ValidationError("This poll is already closed.")

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
    like_count = serializers.SerializerMethodField()
    dislike_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Review
        fields = ["id", "user", "user_username", "society", "rating", "comment", "created_at", "response_count", "reaction_count", "like_count", "dislike_count"]
        read_only_fields = ["user", "created_at", "response_count", "reaction_count", "like_count", "dislike_count"]

    def validate_rating(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("Rating must be between 1 and 5.")
        return value

    def validate(self, data):
        request = self.context.get("request")
        user = request.user if request and request.user.is_authenticated else data.get("user")
        if self.instance is not None and user is None:
            user = self.instance.user

        society = data.get("society") or getattr(self.instance, "society", None)
        comment = data.get("comment", getattr(self.instance, "comment", ""))

        if user is None:
            raise serializers.ValidationError("Authentication is required to review.")

        if society is None:
            raise serializers.ValidationError("Society is required.")

        membership = Membership.objects.filter(user=user, society=society).first()
        if membership is None:
            raise serializers.ValidationError("Only members of this society can leave a review.")

        if timezone.now() - membership.created_at < timedelta(days=14):
            raise serializers.ValidationError("You must be a member for at least 2 weeks before leaving a review.")

        banned_words = getattr(settings, "BANNED_REVIEW_WORDS", [])
        if comment and banned_words:
            lowered_comment = comment.lower()
            for bad_word in banned_words:
                pattern = r"\\b" + re.escape(bad_word.lower()) + r"\\b"
                if re.search(pattern, lowered_comment):
                    raise serializers.ValidationError("Your review contains inappropriate language and cannot be submitted.")

        return data
    
    def get_response_count(self, obj):
        return ReviewResponse.objects.filter(review=obj).count()
    
    def get_reaction_count(self, obj):
        return ReviewReaction.objects.filter(review=obj).count()

    def get_like_count(self, obj):
        return ReviewReaction.objects.filter(review=obj, reaction_type="like").count()

    def get_dislike_count(self, obj):
        return ReviewReaction.objects.filter(review=obj, reaction_type="dislike").count()


class ReviewResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewResponse
        fields = ["id", "review", "admin", "response_text", "created_at"]
        read_only_fields = ["admin", "created_at"]


class ReviewReactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReviewReaction
        fields = ["id", "user", "review", "reaction_type", "created_at"]
        read_only_fields = ["user", "created_at"]

    def validate(self, data):
        request = self.context.get("request")
        user = request.user if request and request.user.is_authenticated else data.get("user")
        review = data.get("review")

        if user is None:
            raise serializers.ValidationError("Authentication is required to react.")

        if review is None:
            raise serializers.ValidationError("Review is required.")

        if Membership.objects.filter(user=user, role="admin").exists():
            raise serializers.ValidationError("Admins cannot like or dislike reviews.")

        if ReviewReaction.objects.filter(user=user, review=review).exists():
            raise serializers.ValidationError("You have already reacted to this review.")

        return data


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "title", "message", "is_read", "created_at"]
        read_only_fields = ["id", "title", "message", "created_at"]


class EventSerializer(serializers.ModelSerializer):
    attendee_count = serializers.SerializerMethodField()
    is_attending = serializers.SerializerMethodField()

    class Meta:
        model = Event
        fields = [
            "id",
            "society",
            "title",
            "description",
            "location",
            "starts_at",
            "ends_at",
            "capacity",
            "created_by",
            "created_at",
            "attendee_count",
            "is_attending",
        ]
        read_only_fields = ["created_by", "created_at", "attendee_count", "is_attending"]

    def validate(self, data):
        starts_at = data.get("starts_at")
        ends_at = data.get("ends_at")

        if starts_at and ends_at and starts_at >= ends_at:
            raise serializers.ValidationError("starts_at must be earlier than ends_at.")

        return data

    def get_attendee_count(self, obj):
        return obj.rsvps.filter(status="going").count()

    def get_is_attending(self, obj):
        request = self.context.get("request")
        if not request or not request.user.is_authenticated:
            return False
        return obj.rsvps.filter(user=request.user, status="going").exists()


class EventRSVPSerializer(serializers.ModelSerializer):
    class Meta:
        model = EventRSVP
        fields = ["id", "event", "user", "status", "created_at", "updated_at"]
        read_only_fields = ["user", "created_at", "updated_at"]

    def validate(self, data):
        request = self.context.get("request")
        user = request.user if request and request.user.is_authenticated else data.get("user")
        event = data.get("event")
        status_value = data.get("status", "going")

        if not user:
            raise serializers.ValidationError("Authentication is required to RSVP.")

        if not event:
            raise serializers.ValidationError("Event is required.")

        if not Membership.objects.filter(user=user, society=event.society).exists():
            raise serializers.ValidationError("Only society members can RSVP to this event.")

        if status_value == "going" and event.capacity is not None:
            current_attendees = EventRSVP.objects.filter(event=event, status="going").count()
            existing_rsvp = EventRSVP.objects.filter(event=event, user=user).first()
            if existing_rsvp and existing_rsvp.status == "going":
                return data
            if current_attendees >= event.capacity:
                raise serializers.ValidationError("This event is at full capacity.")

        return data

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    password_confirmation = serializers.CharField(write_only=True)
    opt_in_email = serializers.BooleanField(required=False, default=False)
    account_type = serializers.ChoiceField(choices=[("member", "Member"), ("admin", "Admin")], required=False, default="member")

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "password",
            "password_confirmation",
            "up_number",
            "opt_in_email",
            "account_type",
        )

    def validate(self, attrs):
        if attrs.get("password") != attrs.get("password_confirmation"):
            raise serializers.ValidationError({"password_confirmation": "Passwords do not match."})

        account_type = attrs.get("account_type", "member")
        up_number = attrs.get("up_number", "")
        if account_type == "member" and up_number.upper().startswith("A"):
            raise serializers.ValidationError({"up_number": "Member UP numbers cannot start with 'A'."})

        return attrs

    def create(self, validated_data):
        validated_data.pop("password_confirmation", None)
        account_type = validated_data.pop("account_type", "member")
        up_number = validated_data["up_number"]
        if account_type == "admin" and not up_number.upper().startswith("A"):
            validated_data["up_number"] = f"A{up_number}"

        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data["email"],
            password=validated_data["password"],
            up_number=validated_data["up_number"],
            opt_in_email=validated_data.get("opt_in_email", False),
        )
        return user


class AccountSettingsSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=False, allow_blank=False)
    password_confirmation = serializers.CharField(write_only=True, required=False, allow_blank=False)

    class Meta:
        model = User
        fields = (
            "username",
            "email",
            "up_number",
            "opt_in_email",
            "password",
            "password_confirmation",
        )

    def validate(self, attrs):
        password = attrs.get("password")
        password_confirmation = attrs.get("password_confirmation")
        current_user = self.instance

        if password is not None:
            if not password_confirmation:
                raise serializers.ValidationError({"password_confirmation": "Password confirmation is required."})
            if password != password_confirmation:
                raise serializers.ValidationError({"password_confirmation": "Passwords do not match."})

            for existing_user in User.objects.exclude(pk=current_user.pk).only("id", "password"):
                if check_password(password, existing_user.password):
                    raise serializers.ValidationError({"password": "This password is already used by another account."})

        up_number = attrs.get("up_number")
        if up_number is not None:
            is_admin_account = current_user.up_number.upper().startswith("A")
            if is_admin_account and not up_number.upper().startswith("A"):
                attrs["up_number"] = f"A{up_number}"
            if not is_admin_account and up_number.upper().startswith("A"):
                raise serializers.ValidationError({"up_number": "Member UP numbers cannot start with 'A'."})

        return attrs

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)
        validated_data.pop("password_confirmation", None)

        for field, value in validated_data.items():
            setattr(instance, field, value)

        if password is not None:
            instance.set_password(password)

        instance.save()
        return instance