"""
Custom middleware for development-only admin access without authentication.
"""
from django.shortcuts import redirect
from django.contrib.auth.models import User
from django.contrib.auth import login


class DevAdminAuthMiddleware:
    """
    Middleware to provide unauthenticated admin access in development.
    Creates/uses a default 'admin' user to auto-login to admin panel.
    
    This is for development/testing ONLY and should never be used in production.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Only apply to admin paths
        if request.path.startswith('/admin/'):
            # Ensure a default admin user exists
            admin_user, created = User.objects.get_or_create(
                username='admin',
                defaults={
                    'is_staff': True,
                    'is_superuser': True,
                }
            )
            if created:
                admin_user.set_password('admin')
                admin_user.save()
            
            # Auto-login the admin user for admin pages
            if not request.user.is_authenticated or not request.user.is_staff:
                login(request, admin_user, backend='django.contrib.auth.backends.ModelBackend')

        response = self.get_response(request)
        return response
