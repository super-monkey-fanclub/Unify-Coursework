from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
from django.core import mail
from django.core.management import call_command
from django.urls import reverse
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Event, EventRSVP, Membership, Notification, Poll, PollOption, PollVote, Review, Society, User
from .throttles import RegisterRateThrottle
from .views import register


class AuthEndpointsTests(APITestCase):
	def test_register_login_and_me(self):
		register_response = self.client.post(
			reverse("register"),
			{
				"username": "newuser",
				"email": "newuser@example.com",
				"password": "StrongPass123!",
				"password_confirmation": "StrongPass123!",
				"up_number": "up9999999",
				"opt_in_email": True,
			},
			format="json",
		)
		self.assertEqual(register_response.status_code, status.HTTP_200_OK)
		self.assertIn("access", register_response.data)

		login_response = self.client.post(
			reverse("login"),
			{"username": "newuser", "password": "StrongPass123!"},
			format="json",
		)
		self.assertEqual(login_response.status_code, status.HTTP_200_OK)

		access = login_response.data["access"]
		self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
		me_response = self.client.get(reverse("me"))

		self.assertEqual(me_response.status_code, status.HTTP_200_OK)
		self.assertEqual(me_response.data["username"], "newuser")

	def test_admin_registration_prefixes_up_number_with_a(self):
		response = self.client.post(
			reverse("register"),
			{
				"username": "leader",
				"email": "leader@example.com",
				"password": "StrongPass123!",
				"password_confirmation": "StrongPass123!",
				"up_number": "up1234567",
				"account_type": "admin",
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_200_OK)
		created_user = User.objects.get(username="leader")
		self.assertTrue(created_user.up_number.startswith("A"))

	def test_login_rejects_wrong_account_type(self):
		member_user = User.objects.create_user(
			username="plainmember",
			password="StrongPass123!",
			up_number="up6767676",
		)
		self.client.force_authenticate(user=None)

		admin_login_attempt = self.client.post(
			reverse("login"),
			{"username": member_user.username, "password": "StrongPass123!", "account_type": "admin"},
			format="json",
		)
		self.assertEqual(admin_login_attempt.status_code, status.HTTP_403_FORBIDDEN)


class PollPermissionsAndVotingTests(APITestCase):
	def setUp(self):
		self.admin_user = User.objects.create_user(
			username="soc_admin",
			password="StrongPass123!",
			up_number="up1111111",
		)
		self.member_user = User.objects.create_user(
			username="member",
			password="StrongPass123!",
			up_number="up2222222",
		)
		self.outsider_user = User.objects.create_user(
			username="outsider",
			password="StrongPass123!",
			up_number="up3333333",
		)

		self.society = Society.objects.create(
			name="Chess Society",
			description="A place for chess enthusiasts",
			category="Games",
		)
		Membership.objects.create(user=self.admin_user, society=self.society, role="admin")
		Membership.objects.create(user=self.member_user, society=self.society, role="member")

		self.poll = Poll.objects.create(
			society=self.society,
			title="Match Day",
			description="Choose a day",
			opens_at=timezone.now(),
			closes_at=timezone.now() + timedelta(days=1),
		)
		self.option_a = PollOption.objects.create(poll=self.poll, option_text="Monday")
		self.option_b = PollOption.objects.create(poll=self.poll, option_text="Tuesday")

	def test_non_admin_cannot_create_poll(self):
		self.client.force_authenticate(user=self.member_user)
		response = self.client.post(
			reverse("poll-list"),
			{
				"society": self.society.id,
				"title": "New Poll",
				"description": "Poll description",
				"opens_at": timezone.now().isoformat(),
				"closes_at": (timezone.now() + timedelta(days=1)).isoformat(),
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

	def test_member_can_vote_once(self):
		self.client.force_authenticate(user=self.member_user)
		first_vote = self.client.post(
			reverse("pollvote-list"),
			{"poll": self.poll.id, "option": self.option_a.id},
			format="json",
		)
		self.assertEqual(first_vote.status_code, status.HTTP_201_CREATED)

		second_vote = self.client.post(
			reverse("pollvote-list"),
			{"poll": self.poll.id, "option": self.option_b.id},
			format="json",
		)
		self.assertEqual(second_vote.status_code, status.HTTP_400_BAD_REQUEST)
		self.assertEqual(PollVote.objects.filter(user=self.member_user, poll=self.poll).count(), 1)
		self.assertNotIn("user", first_vote.data)

	def test_outsider_cannot_vote(self):
		self.client.force_authenticate(user=self.outsider_user)
		response = self.client.post(
			reverse("pollvote-list"),
			{"poll": self.poll.id, "option": self.option_a.id},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class PollNotificationFlowTests(APITestCase):
	def setUp(self):
		mail.outbox = []
		self.admin_user = User.objects.create_user(
			username="notify_admin",
			password="StrongPass123!",
			up_number="up1212121",
			email="notify_admin@example.com",
		)
		self.member_opt_in = User.objects.create_user(
			username="notify_member_opt_in",
			password="StrongPass123!",
			up_number="up1212122",
			email="optin@example.com",
			opt_in_email=True,
		)
		self.member_no_opt = User.objects.create_user(
			username="notify_member_no_opt",
			password="StrongPass123!",
			up_number="up1212123",
			email="noopt@example.com",
			opt_in_email=False,
		)
		self.society = Society.objects.create(
			name="Notification Society",
			description="Notification tests",
			category="General",
		)
		Membership.objects.create(user=self.admin_user, society=self.society, role="admin")
		Membership.objects.create(user=self.member_opt_in, society=self.society, role="member")
		Membership.objects.create(user=self.member_no_opt, society=self.society, role="member")

	def test_poll_create_sends_email_only_to_opted_in_users(self):
		self.client.force_authenticate(user=self.admin_user)
		response = self.client.post(
			reverse("poll-list"),
			{
				"society": self.society.id,
				"title": "Email Poll",
				"description": "Check email flow",
				"opens_at": timezone.now().isoformat(),
				"closes_at": (timezone.now() + timedelta(days=1)).isoformat(),
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_201_CREATED)
		self.assertEqual(len(mail.outbox), 1)
		self.assertEqual(mail.outbox[0].to, ["optin@example.com"])

	def test_scheduled_poll_notifications_send_ending_soon_and_closed(self):
		soon_poll = Poll.objects.create(
			society=self.society,
			title="Soon Poll",
			description="closing soon",
			opens_at=timezone.now() - timedelta(days=1),
			closes_at=timezone.now() + timedelta(minutes=30),
		)
		closed_poll = Poll.objects.create(
			society=self.society,
			title="Closed Poll",
			description="already closed",
			opens_at=timezone.now() - timedelta(days=2),
			closes_at=timezone.now() - timedelta(minutes=10),
		)

		call_command("send_poll_notifications")

		soon_poll.refresh_from_db()
		closed_poll.refresh_from_db()
		self.assertIsNotNone(soon_poll.ending_soon_notified_at)
		self.assertIsNotNone(closed_poll.closed_notified_at)
		self.assertTrue(Notification.objects.filter(title="Poll ending soon").exists())
		self.assertTrue(Notification.objects.filter(title="Poll closed").exists())
		self.assertGreaterEqual(len(mail.outbox), 2)


class ReviewOwnershipTests(APITestCase):
	def setUp(self):
		self.author = User.objects.create_user(
			username="author",
			password="StrongPass123!",
			up_number="up4444444",
		)
		self.other_user = User.objects.create_user(
			username="other",
			password="StrongPass123!",
			up_number="up5555555",
		)
		self.society = Society.objects.create(
			name="Music Society",
			description="For music lovers",
			category="Arts",
		)
		self.review = Review.objects.create(
			user=self.author,
			society=self.society,
			rating=4,
			comment="Great sessions",
		)

	def test_user_cannot_update_someone_else_review(self):
		self.client.force_authenticate(user=self.other_user)
		response = self.client.patch(
			reverse("review-detail", args=[self.review.id]),
			{"comment": "Trying to edit"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

	def test_review_rating_validation(self):
		self.client.force_authenticate(user=self.author)
		response = self.client.post(
			reverse("review-list"),
			{"society": self.society.id, "rating": 6, "comment": "Too high"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

	def test_society_admin_can_delete_review(self):
		admin_user = User.objects.create_user(
			username="review_admin",
			password="StrongPass123!",
			up_number="up6667777",
		)
		Membership.objects.create(user=admin_user, society=self.society, role="admin")

		self.client.force_authenticate(user=admin_user)
		response = self.client.delete(reverse("review-detail", args=[self.review.id]))
		self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
		self.assertFalse(Review.objects.filter(id=self.review.id).exists())

	def test_review_requires_two_week_membership(self):
		new_member = User.objects.create_user(
			username="new_member",
			password="StrongPass123!",
			up_number="up7778888",
		)
		Membership.objects.create(user=new_member, society=self.society, role="member")

		self.client.force_authenticate(user=new_member)
		response = self.client.post(
			reverse("review-list"),
			{"society": self.society.id, "rating": 4, "comment": "Too new"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class AccountSettingsTests(APITestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="settings_user",
			email="settings@example.com",
			password="StrongPass123!",
			up_number="up9191919",
		)
		self.other_user = User.objects.create_user(
			username="other_settings_user",
			email="other@example.com",
			password="AnotherPass123!",
			up_number="up9292929",
		)

	def test_account_settings_patch_updates_profile(self):
		self.client.force_authenticate(user=self.user)
		response = self.client.patch(
			reverse("account-settings"),
			{"username": "updated_user", "opt_in_email": True},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_200_OK)
		self.user.refresh_from_db()
		self.assertEqual(self.user.username, "updated_user")
		self.assertTrue(self.user.opt_in_email)

	def test_account_settings_password_requires_confirmation(self):
		self.client.force_authenticate(user=self.user)
		response = self.client.patch(
			reverse("account-settings"),
			{"password": "BrandNew123!"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

	def test_account_settings_rejects_reused_password(self):
		self.client.force_authenticate(user=self.user)
		response = self.client.patch(
			reverse("account-settings"),
			{
				"password": "AnotherPass123!",
				"password_confirmation": "AnotherPass123!",
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class NotificationsAndEventsTests(APITestCase):
	def setUp(self):
		self.admin_user = User.objects.create_user(
			username="event_admin",
			password="StrongPass123!",
			up_number="up6666666",
		)
		self.member_user = User.objects.create_user(
			username="event_member",
			password="StrongPass123!",
			up_number="up7777777",
		)
		self.outsider_user = User.objects.create_user(
			username="event_outsider",
			password="StrongPass123!",
			up_number="up8888888",
		)

		self.society = Society.objects.create(
			name="Coding Society",
			description="Build cool projects",
			category="Technology",
		)
		Membership.objects.create(user=self.admin_user, society=self.society, role="admin")
		Membership.objects.create(user=self.member_user, society=self.society, role="member")

	def test_admin_can_create_event_and_member_gets_notification(self):
		self.client.force_authenticate(user=self.admin_user)
		response = self.client.post(
			reverse("event-list"),
			{
				"society": self.society.id,
				"title": "Hack Night",
				"description": "Build together",
				"location": "Lab 2",
				"starts_at": timezone.now().isoformat(),
				"ends_at": (timezone.now() + timedelta(hours=2)).isoformat(),
				"capacity": 30,
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_201_CREATED)
		self.assertEqual(Notification.objects.filter(user=self.member_user, title="New event added").count(), 1)

	def test_non_admin_cannot_create_event(self):
		self.client.force_authenticate(user=self.member_user)
		response = self.client.post(
			reverse("event-list"),
			{
				"society": self.society.id,
				"title": "Unauthorized Event",
				"starts_at": timezone.now().isoformat(),
				"ends_at": (timezone.now() + timedelta(hours=1)).isoformat(),
			},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

	def test_member_can_rsvp_but_outsider_cannot(self):
		event = Event.objects.create(
			society=self.society,
			title="Weekly Meetup",
			description="Meet and network",
			location="Room A",
			starts_at=timezone.now() + timedelta(days=1),
			ends_at=timezone.now() + timedelta(days=1, hours=2),
			capacity=10,
			created_by=self.admin_user,
		)

		self.client.force_authenticate(user=self.member_user)
		member_response = self.client.post(
			reverse("eventrsvp-list"),
			{"event": event.id, "status": "going"},
			format="json",
		)
		self.assertEqual(member_response.status_code, status.HTTP_201_CREATED)
		self.assertEqual(EventRSVP.objects.filter(event=event, user=self.member_user, status="going").count(), 1)

		self.client.force_authenticate(user=self.outsider_user)
		outsider_response = self.client.post(
			reverse("eventrsvp-list"),
			{"event": event.id, "status": "going"},
			format="json",
		)
		self.assertEqual(outsider_response.status_code, status.HTTP_400_BAD_REQUEST)

	def test_mark_notification_as_read(self):
		notification = Notification.objects.create(
			user=self.member_user,
			title="Reminder",
			message="Please check updates",
		)
		self.client.force_authenticate(user=self.member_user)
		response = self.client.post(reverse("notification-mark-read", args=[notification.id]))
		self.assertEqual(response.status_code, status.HTTP_200_OK)
		notification.refresh_from_db()
		self.assertTrue(notification.is_read)


class ReviewReactionsTests(APITestCase):
	def setUp(self):
		self.author = User.objects.create_user(
			username="reaction_author",
			password="StrongPass123!",
			up_number="up9990001",
		)
		self.reactor = User.objects.create_user(
			username="reaction_user",
			password="StrongPass123!",
			up_number="up9990002",
		)
		self.admin_user = User.objects.create_user(
			username="reaction_admin",
			password="StrongPass123!",
			up_number="up9990003",
		)
		self.society = Society.objects.create(
			name="Drama Society",
			description="A place for drama",
			category="Arts",
		)
		Membership.objects.create(user=self.author, society=self.society, role="member")
		Membership.objects.create(user=self.reactor, society=self.society, role="member")
		Membership.objects.create(user=self.admin_user, society=self.society, role="admin")
		Membership.objects.filter(user=self.author, society=self.society).update(created_at=timezone.now() - timedelta(days=15))
		self.review = Review.objects.create(
			user=self.author,
			society=self.society,
			rating=5,
			comment="Great society",
		)

	def test_like_creates_notification_for_author(self):
		self.client.force_authenticate(user=self.reactor)
		response = self.client.post(
			reverse("reviewreaction-list"),
			{"review": self.review.id, "reaction_type": "like"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_201_CREATED)
		self.assertEqual(Notification.objects.filter(user=self.author, title="Review liked").count(), 1)

	def test_admin_cannot_react_to_review(self):
		self.client.force_authenticate(user=self.admin_user)
		response = self.client.post(
			reverse("reviewreaction-list"),
			{"review": self.review.id, "reaction_type": "like"},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class ThrottlingTests(APITestCase):
	def setUp(self):
		cache.clear()

	def test_register_endpoint_is_throttled(self):
		self.assertIn(RegisterRateThrottle, register.cls.throttle_classes)
		self.assertIn("register", settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
