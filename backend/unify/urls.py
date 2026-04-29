"""
URL configuration for unify project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path

from core.views import (
    register_view,
    login_view,
    ensure_dev_account_view,
    update_user_role_view,
    join_society_view,
    my_societies_view,
    list_polls_view,
    create_poll_view,
    update_poll_view,
    delete_poll_view,
    vote_poll_view,
    society_reviews_view,
    add_review_view,
    react_review_view,
    admin_delete_review_view,
    admin_respond_review_view,
)
urlpatterns = [
    path("admin/", admin.site.urls),
    # Simple JSON API for sign up and login
    path("api/auth/register/", register_view, name="api-register"),
    path("api/auth/login/", login_view, name="api-login"),
    path("api/auth/dev/ensure/", ensure_dev_account_view, name="api-ensure-dev"),
    path("api/auth/roles/update/", update_user_role_view, name="api-update-user-role"),
    # Societies/memberships
    path("api/societies/join/", join_society_view, name="api-join-society"),
    path("api/societies/my/", my_societies_view, name="api-my-societies"),
    # Polls
    path("api/societies/polls/", list_polls_view, name="api-list-polls"),
    path("api/societies/polls/create/", create_poll_view, name="api-create-poll"),
    path("api/societies/polls/update/", update_poll_view, name="api-update-poll"),
    path("api/societies/polls/delete/", delete_poll_view, name="api-delete-poll"),
    path("api/societies/polls/vote/", vote_poll_view, name="api-vote-poll"),
    # Reviews
    path("api/societies/reviews/", society_reviews_view, name="api-society-reviews"),
    path("api/societies/reviews/add/", add_review_view, name="api-add-review"),
    path("api/societies/reviews/react/", react_review_view, name="api-react-review"),
    path("api/societies/reviews/delete/", admin_delete_review_view, name="api-delete-review"),
    path("api/societies/reviews/respond/", admin_respond_review_view, name="api-respond-review"),
]
