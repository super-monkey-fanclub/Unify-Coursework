from django.contrib import admin
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

admin.site.register(User)
admin.site.register(Society)
admin.site.register(Membership)
admin.site.register(Poll)
admin.site.register(PollOption)
admin.site.register(PollVote)
admin.site.register(Review)
admin.site.register(ReviewResponse)
admin.site.register(ReviewReaction)