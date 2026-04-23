from django.contrib import admin
from django.utils import timezone
from .models import (
    User,
    Society,
    Membership,
    Poll,
    PollOption,
    PollVote,
    SocietyInfo,
    Review,
    ReviewResponse,
    ReviewReaction
)


def _duration_label(created_at):
    if not created_at:
        return "-"

    total_days = max((timezone.now() - created_at).days, 0)
    weeks, days = divmod(total_days, 7)

    if weeks == 0:
        return f"{days} day{'s' if days != 1 else ''}"
    if days == 0:
        return f"{weeks} week{'s' if weeks != 1 else ''}"
    return f"{weeks} week{'s' if weeks != 1 else ''}, {days} day{'s' if days != 1 else ''}"

class MembershipInline(admin.TabularInline):
    model = Membership
    extra = 0
    readonly_fields = ("user_email", "user_up_number", "role", "duration")
    fields = ("user_email", "user_up_number", "role", "duration")

    def user_email(self, obj):
        return obj.user.email

    user_email.short_description = "Email"

    def user_up_number(self, obj):
        return obj.user.up_number

    user_up_number.short_description = "UP number"

    def duration(self, obj):
        return _duration_label(obj.created_at)

    duration.short_description = "Duration"


class SocietyAdmin(admin.ModelAdmin):
    list_display = ("name", "members_summary")
    inlines = [MembershipInline]

    def members_summary(self, obj):
        memberships = Membership.objects.filter(society=obj).select_related("user")
        if not memberships:
            return "No members"
        return ", ".join(
            f"{m.user.email} ({m.user.up_number})" for m in memberships
        )

    members_summary.short_description = "Members"


class MembershipAdmin(admin.ModelAdmin):
    list_display = ("user", "society", "role", "created_at", "duration")
    list_select_related = ("user", "society")

    def duration(self, obj):
        return _duration_label(obj.created_at)

    duration.short_description = "Duration"


class ReviewReactionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "review",
        "user_email",
        "user_up_number",
        "reaction_type",
        "created_at",
    )
    readonly_fields = ("user_email", "user_up_number")

    def user_email(self, obj):
        return obj.user.email

    user_email.short_description = "Email"

    def user_up_number(self, obj):
        return obj.user.up_number

    user_up_number.short_description = "UP number"


admin.site.register(User)
admin.site.register(Society, SocietyAdmin)
admin.site.register(Membership, MembershipAdmin)
admin.site.register(Poll)
admin.site.register(PollOption)
admin.site.register(PollVote)
admin.site.register(SocietyInfo)
admin.site.register(Review)
admin.site.register(ReviewResponse)
admin.site.register(ReviewReaction, ReviewReactionAdmin)