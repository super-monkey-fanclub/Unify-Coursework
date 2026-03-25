from django.db import models
from django.db.models import F, Q
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator

class User(AbstractUser):
    up_number = models.CharField(max_length=20, unique=True)
    opt_in_email = models.BooleanField(default=False)

class Society(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class Membership(models.Model):
    ROLE_CHOICES = (
        ('member', 'Member'),
        ('admin', 'Admin'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'society')

class Poll(models.Model):
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    description = models.CharField(max_length=500)
    opens_at = models.DateTimeField()
    closes_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=Q(closes_at__gt=F('opens_at')),
                name='poll_closes_after_opens',
            )
        ]

class PollOption(models.Model):
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE)
    option_text = models.CharField(max_length=255)

class PollVote(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    poll = models.ForeignKey(Poll, on_delete=models.CASCADE)
    option = models.ForeignKey(PollOption, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'poll')

class Review(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    rating = models.IntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'society')

class ReviewResponse(models.Model):
    review = models.ForeignKey(Review, on_delete=models.CASCADE)
    admin = models.ForeignKey(User, on_delete=models.CASCADE)
    response_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

class ReviewReaction(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    review = models.ForeignKey(Review, on_delete=models.CASCADE)
    reaction_type = models.CharField(max_length=20, choices=[('like', 'Like'), ('dislike', 'Dislike')])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'review')


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=120)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Event(models.Model):
    society = models.ForeignKey(Society, on_delete=models.CASCADE, related_name='events')
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    location = models.CharField(max_length=200, blank=True)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    capacity = models.PositiveIntegerField(null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_events')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['starts_at']
        constraints = [
            models.CheckConstraint(
                condition=Q(ends_at__gt=F('starts_at')),
                name='event_ends_after_starts',
            )
        ]


class EventRSVP(models.Model):
    STATUS_CHOICES = (
        ('going', 'Going'),
        ('not_going', 'Not Going'),
    )

    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='rsvps')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='event_rsvps')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='going')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('event', 'user')