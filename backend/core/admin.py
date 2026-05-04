from django.contrib import admin
from django.utils import timezone
from django.utils.safestring import mark_safe
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
            f"{m.user.email}" for m in memberships
        )

    members_summary.short_description = "Members"


class MembershipAdmin(admin.ModelAdmin):
    list_display = ("user_email", "user_up_number", "society", "role", "created_at", "duration")
    list_select_related = ("user", "society")

    def user_email(self, obj):
        return obj.user.email

    user_email.short_description = "Email"

    def user_up_number(self, obj):
        return obj.user.up_number

    user_up_number.short_description = "UP number"

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


class UserAdmin(admin.ModelAdmin):
    list_display = ("email", "up_number", "first_name", "admin_status", "is_active")
    search_fields = ("email", "up_number", "first_name")
    list_filter = ("is_staff", "is_superuser", "is_active")
    ordering = ("email",)

    def admin_status(self, obj):
        # Consider a user an 'Admin' if they are an admin of any society
        return Membership.objects.filter(user=obj, role='admin').exists()

    admin_status.short_description = "Admin status"
    admin_status.boolean = True


admin.site.register(User, UserAdmin)
admin.site.register(Society, SocietyAdmin)
admin.site.register(Membership, MembershipAdmin)
admin.site.register(Poll)
admin.site.register(PollOption)
admin.site.register(PollVote)
admin.site.register(SocietyInfo)
admin.site.register(Review)
admin.site.register(ReviewResponse)
admin.site.register(ReviewReaction, ReviewReactionAdmin)


class PollOptionInline(admin.TabularInline):
    model = PollOption
    extra = 0
    readonly_fields = ("votes_count",)
    fields = ("option_text", "votes_count")

    def votes_count(self, obj):
        from .models import PollVote

        return PollVote.objects.filter(option=obj).count()

    votes_count.short_description = "Votes"


class PollAdmin(admin.ModelAdmin):
    list_display = ("title", "society", "opens_at", "closes_at", "total_votes")
    inlines = [PollOptionInline]
    readonly_fields = ("options_and_votes",)
    fieldsets = (
        (None, {"fields": ("title", "society", "opens_at", "closes_at")} ),
        ("Options & Votes", {"fields": ("options_and_votes",)}),
    )

    def options_and_votes(self, obj):
        from .models import PollOption, PollVote

        options = PollOption.objects.filter(poll=obj)
        if not options:
            return "<em>No options</em>"

        parts = ["<div style='font-family: monospace;'>"]
        for opt in options:
            votes = PollVote.objects.filter(option=opt).select_related('user')
            parts.append(f"<strong>Option:</strong> {opt.option_text} &ndash; <em>{votes.count()} votes</em><br/>")
            if votes.exists():
                parts.append("<ul>")
                for v in votes:
                    parts.append(f"<li>{v.user.email} ({v.user.up_number})</li>")
                parts.append("</ul>")
            else:
                parts.append("<div style='color:#666;margin-bottom:8px;'>No votes yet</div>")
        parts.append("</div>")
        return mark_safe('\n'.join(parts))

    options_and_votes.short_description = "Options and votes"

    def total_votes(self, obj):
        from .models import PollVote

        return PollVote.objects.filter(poll=obj).count()

    total_votes.short_description = "Total votes"


class PollOptionAdmin(admin.ModelAdmin):
    list_display = ("option_text", "poll", "votes_count")

    def votes_count(self, obj):
        from .models import PollVote

        return PollVote.objects.filter(option=obj).count()

    votes_count.short_description = "Votes"


class PollVoteAdmin(admin.ModelAdmin):
    list_display = ("id", "poll", "option", "user_email", "user_up_number", "created_at")
    list_select_related = ("user", "poll", "option")
    readonly_fields = ("user_email", "user_up_number")

    def user_email(self, obj):
        return obj.user.email

    user_email.short_description = "Email"

    def user_up_number(self, obj):
        return obj.user.up_number

    user_up_number.short_description = "UP number"


admin.site.unregister(Poll)
admin.site.unregister(PollOption)
admin.site.unregister(PollVote)
admin.site.register(Poll, PollAdmin)
admin.site.register(PollOption, PollOptionAdmin)
admin.site.register(PollVote, PollVoteAdmin)