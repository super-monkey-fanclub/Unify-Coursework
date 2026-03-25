from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
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
				"up_number": "up9999999",
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

	def test_outsider_cannot_vote(self):
		self.client.force_authenticate(user=self.outsider_user)
		response = self.client.post(
			reverse("pollvote-list"),
			{"poll": self.poll.id, "option": self.option_a.id},
			format="json",
		)
		self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


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


class ThrottlingTests(APITestCase):
	def setUp(self):
		cache.clear()

	def test_register_endpoint_is_throttled(self):
		self.assertIn(RegisterRateThrottle, register.cls.throttle_classes)
		self.assertIn("register", settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
