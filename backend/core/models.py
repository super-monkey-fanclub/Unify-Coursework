from django.db import models
from django.contrib.auth.models import AbstractUser


class User(AbstractUser):
    ACCOUNT_TYPE_CHOICES = (
        ('regular', 'Regular'),
        ('society_admin', 'Society Admin'),
        ('dev', 'Developer'),
    )

    up_number = models.CharField(max_length=20, unique=True)
    opt_in_email = models.BooleanField(default=False)
    account_type = models.CharField(
        max_length=20,
        choices=ACCOUNT_TYPE_CHOICES,
        default='regular',
    )

    def save(self, *args, **kwargs):
        """Auto-generate a unique UP number on first save if missing.

        This avoids inserting an empty string for ``up_number`` which was
        triggering ``UNIQUE constraint failed: core_user.up_number`` errors
        when creating new users.
        
        Admin accounts use "A" prefix, regular accounts use "UP" prefix.
        """
        if not self.pk and not self.up_number:
            # Estimate the next primary key to derive a stable UP number.
            last_user = self.__class__.objects.order_by("-pk").first()
            next_id = (last_user.pk + 1) if last_user else 1
            
            # Use "A" prefix for admin accounts, "UP" for regular users
            if self.account_type == 'society_admin':
                self.up_number = f"A{next_id:06d}"
            else:
                self.up_number = f"UP{next_id:06d}"

        return super().save(*args, **kwargs)

class Society(models.Model):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=50)
    average_rating = models.FloatField(default=0.0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name
    
    def update_average_rating(self):
        """Recalculate and save the average rating based on all reviews."""
        reviews = Review.objects.filter(society=self)
        if reviews.exists():
            avg = sum(r.rating for r in reviews) / reviews.count()
            self.average_rating = round(avg, 2)
        else:
            self.average_rating = 0.0
        self.save()

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

    def __str__(self):
        return f"({self.user.username}, {self.society.name}, {self.role})"

class Poll(models.Model):
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    description = models.CharField(max_length=500)
    opens_at = models.DateTimeField()
    closes_at = models.DateTimeField()
    notified_closing_soon = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

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

class SocietyInfo(models.Model):
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    admin = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.CharField(max_length=200, blank=True, default='')
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.society.name}: {self.title}"

class Review(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    society = models.ForeignKey(Society, on_delete=models.CASCADE)
    rating = models.IntegerField()
    comment = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'society')

    def __str__(self):
        # Show reviewer email and UP number to make admin listings clearer.
        return f"{self.user.email} ({self.user.up_number})"

class ReviewResponse(models.Model):
    review = models.ForeignKey(Review, on_delete=models.CASCADE)
    admin = models.ForeignKey(User, on_delete=models.CASCADE)
    response_text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('review',)

class ReviewReaction(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    review = models.ForeignKey(Review, on_delete=models.CASCADE)
    reaction_type = models.CharField(max_length=20, choices=[('like', 'Like'), ('dislike', 'Dislike')])
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'review')


class Notification(models.Model):
    NOTIFICATION_TYPES = (
        ('poll_created', 'Poll Created'),
        ('poll_deleted', 'Poll Deleted'),
        ('poll_closing_soon', 'Poll Closing Soon'),
        ('review_liked', 'Review Liked'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    notification_type = models.CharField(max_length=50, choices=NOTIFICATION_TYPES)
    title = models.CharField(max_length=200)
    message = models.TextField()
    related_poll = models.ForeignKey(Poll, on_delete=models.CASCADE, null=True, blank=True)
    related_review = models.ForeignKey(Review, on_delete=models.CASCADE, null=True, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'is_read']),
        ]

    def __str__(self):
        return f"{self.user.email}: {self.title}"