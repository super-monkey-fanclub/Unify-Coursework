from django.contrib import admin
from django.urls import path

from core.views import (
    register_view,
    login_view,
    join_society_view,
    my_societies_view,
    society_reviews_view,
    add_review_view,
)
urlpatterns = [
    path("admin/", admin.site.urls),
    # Simple JSON API for sign up and login
    path("api/auth/register/", register_view, name="api-register"),
    path("api/auth/login/", login_view, name="api-login"),
    # Societies/memberships
    path("api/societies/join/", join_society_view, name="api-join-society"),
    path("api/societies/my/", my_societies_view, name="api-my-societies"),
    # Reviews
    path("api/societies/reviews/", society_reviews_view, name="api-society-reviews"),
    path("api/societies/reviews/add/", add_review_view, name="api-add-review"),
]
