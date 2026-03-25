from rest_framework.permissions import BasePermission, SAFE_METHODS

from .models import Membership


class IsOwnerOrReadOnly(BasePermission):
    """Allow edits only for object owners; read-only for others."""

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        return getattr(obj, "user_id", None) == getattr(request.user, "id", None)


class IsSocietyAdminForObject(BasePermission):
    """Require society admin role for objects linked to a society."""

    message = "You must be a society admin to perform this action."

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True

        if hasattr(obj, "society_id"):
            society_id = obj.society_id
        elif hasattr(obj, "poll") and hasattr(obj.poll, "society_id"):
            society_id = obj.poll.society_id
        elif hasattr(obj, "review") and hasattr(obj.review, "society_id"):
            society_id = obj.review.society_id
        else:
            return False

        return Membership.objects.filter(
            user=request.user,
            society_id=society_id,
            role="admin",
        ).exists()
