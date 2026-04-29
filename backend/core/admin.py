from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
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

class MembershipInline(admin.TabularInline):
    model = Membership
    extra = 0
    readonly_fields = ("user_email", "user_up_number", "role")
    fields = ("user_email", "user_up_number", "role")

    def user_email(self, obj):
        return obj.user.email

    user_email.short_description = "Email"

    def user_up_number(self, obj):
        return obj.user.up_number

    user_up_number.short_description = "UP number"


class SocietyAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "members_summary")
    inlines = [MembershipInline]

    def members_summary(self, obj):
        memberships = Membership.objects.filter(society=obj).select_related("user")
        if not memberships:
            return "No members"
        return ", ".join(
            f"{m.user.email} ({m.user.up_number})" for m in memberships
        )

    members_summary.short_description = "Members"


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    list_display = (
        'email',
        'username',
        'account_type',
        'up_number',
        'is_active',
        'is_staff',
    )
    fieldsets = DjangoUserAdmin.fieldsets + (
        (
            'Unify Access',
            {
                'fields': ('account_type', 'up_number', 'opt_in_email'),
            },
        ),
    )

admin.site.register(Society, SocietyAdmin)
admin.site.register(Membership)
admin.site.register(Poll)
admin.site.register(PollOption)
admin.site.register(PollVote)
admin.site.register(Review)
admin.site.register(ReviewResponse)
admin.site.register(ReviewReaction)