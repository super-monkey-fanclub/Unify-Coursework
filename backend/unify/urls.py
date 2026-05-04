from django.contrib import admin
from django.urls import path

from core.views import (
    register_view,
    login_view,
    update_account_view,
    society_members_view,
    promote_member_view,
    join_society_view,
    my_societies_view,
    society_reviews_view,
    add_review_view,
    react_review_view,
    society_review_analytics_view,
    admin_delete_review_view,
    admin_respond_review_view,
    society_polls_view,
    society_poll_detail_view,
    create_society_poll_view,
    create_society_info_view,
    edit_society_poll_view,
    delete_society_poll_view,
    delete_society_info_view,
    vote_society_poll_view,
)


urlpatterns = [
    path("admin/", admin.site.urls),
    # Simple JSON API for sign up and login
    path("api/auth/register/", register_view, name="api-register"),
    path("api/auth/login/", login_view, name="api-login"),
    path("api/auth/account/", update_account_view, name="api-update-account"),
    # Societies/memberships
    path("api/societies/join/", join_society_view, name="api-join-society"),
    path("api/societies/my/", my_societies_view, name="api-my-societies"),
    path("api/societies/members/", society_members_view, name="api-society-members"),
    path("api/societies/members/promote/", promote_member_view, name="api-promote-member"),
    # Reviews
    path("api/societies/reviews/", society_reviews_view, name="api-society-reviews"),
    path("api/societies/reviews/add/", add_review_view, name="api-add-review"),
    path("api/societies/reviews/react/", react_review_view, name="api-react-review"),
    path("api/societies/reviews/analytics/", society_review_analytics_view, name="api-society-review-analytics"),
    path("api/societies/reviews/delete/", admin_delete_review_view, name="api-delete-review"),
    path("api/societies/reviews/respond/", admin_respond_review_view, name="api-respond-review"),
    # Polls
    path("api/societies/polls/", society_polls_view, name="api-society-polls"),
    path("api/societies/polls/detail/", society_poll_detail_view, name="api-society-poll-detail"),
    path("api/societies/polls/create/", create_society_poll_view, name="api-create-society-poll"),
    path("api/societies/polls/edit/", edit_society_poll_view, name="api-edit-society-poll"),
    path("api/societies/polls/delete/", delete_society_poll_view, name="api-delete-society-poll"),
    path("api/societies/polls/info/create/", create_society_info_view, name="api-create-society-info"),
    path("api/societies/polls/info/delete/", delete_society_info_view, name="api-delete-society-info"),
    path("api/societies/polls/vote/", vote_society_poll_view, name="api-vote-society-poll"),
]
