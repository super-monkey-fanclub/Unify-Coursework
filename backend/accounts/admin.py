from django.contrib import admin
from .models import UnifyUser


@admin.register(UnifyUser)
class UnifyUserAdmin(admin.ModelAdmin):
    list_display = ('up_number', 'name', 'email', 'created_at')
    search_fields = ('email', 'name', 'up_number')
    readonly_fields = ('up_number', 'created_at')
