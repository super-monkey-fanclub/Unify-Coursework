from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from core.models import Membership, Poll, PollOption, Review, ReviewReaction, Society


User = get_user_model()


class SocietyPollDetailViewTests(TestCase):
	def setUp(self):
		self.client = Client()
		self.society = Society.objects.create(name='Chess Club', description='Test society', category='Games')
		self.viewer = User.objects.create_user(
			username='viewer',
			email='viewer@example.com',
			password='password123',
			up_number='UP000001',
		)
		Membership.objects.create(user=self.viewer, society=self.society, role='member')
		self.poll = Poll.objects.create(
			society=self.society,
			title='Best opening',
			description='Pick the best opening move.',
			opens_at=timezone.now() - timedelta(hours=1),
			closes_at=timezone.now() + timedelta(hours=1),
		)
		PollOption.objects.create(poll=self.poll, option_text='e4')
		PollOption.objects.create(poll=self.poll, option_text='d4')

	def test_returns_poll_and_society_details(self):
		response = self.client.get(
			'/api/societies/polls/detail/',
			{'poll_id': self.poll.id, 'viewer_email': self.viewer.email},
		)

		self.assertEqual(response.status_code, 200)
		payload = response.json()

		self.assertEqual(payload['society']['name'], 'Chess Club')
		self.assertTrue(payload['viewer_is_member'])
		self.assertFalse(payload['viewer_is_admin'])
		self.assertEqual(payload['poll']['id'], self.poll.id)
		self.assertEqual(len(payload['poll']['options']), 2)

	def test_requires_poll_id(self):
		response = self.client.get('/api/societies/polls/detail/')

		self.assertEqual(response.status_code, 400)
		self.assertEqual(response.json()['error'], 'poll_id query parameter is required.')


class RegistrationTests(TestCase):
	def setUp(self):
		self.client = Client()

	def test_register_sets_default_account_type(self):
		response = self.client.post(
			'/api/auth/register/',
			data={
				'name': 'New User',
				'email': 'new-user@example.com',
				'password': 'strong-pass-123',
			},
			content_type='application/json',
		)

		self.assertEqual(response.status_code, 201)
		user = User.objects.get(email='new-user@example.com')
		self.assertEqual(user.account_type, 'regular')
		self.assertTrue(response.json().get('auth_token'))

	def test_register_rejects_password_without_symbol(self):
		response = self.client.post(
			'/api/auth/register/',
			data={
				'name': 'New User',
				'email': 'plain-password@example.com',
				'password': 'Password123',
			},
			content_type='application/json',
		)

		self.assertEqual(response.status_code, 400)
		self.assertEqual(
			response.json()['error'],
			'Password must include at least one symbol.',
		)


class ReviewPollTokenAuthTests(TestCase):
	def setUp(self):
		self.client = Client()
		self.society = Society.objects.create(
			name='Tech Society',
			description='Token auth tests',
			category='Technology',
		)
		self.user = User.objects.create_user(
			username='member@example.com',
			email='member@example.com',
			password='password123',
			up_number='UP000777',
		)
		Membership.objects.create(user=self.user, society=self.society, role='member')
		self.poll = Poll.objects.create(
			society=self.society,
			title='Preferred stack',
			description='Vote for a stack.',
			opens_at=timezone.now() - timedelta(hours=1),
			closes_at=timezone.now() + timedelta(hours=1),
		)
		self.option = PollOption.objects.create(poll=self.poll, option_text='Django + Flutter')

	def test_vote_poll_accepts_bearer_token_without_email_field(self):
		login_response = self.client.post(
			'/api/auth/login/',
			data={
				'email': self.user.email,
				'password': 'password123',
			},
			content_type='application/json',
		)
		self.assertEqual(login_response.status_code, 200)
		auth_token = login_response.json().get('auth_token')
		self.assertTrue(auth_token)

		vote_response = self.client.post(
			'/api/societies/polls/vote/',
			data={
				'poll_id': self.poll.id,
				'option_id': self.option.id,
			},
			content_type='application/json',
			headers={'Authorization': f'Bearer {auth_token}'},
		)

		self.assertEqual(vote_response.status_code, 201)
		self.assertEqual(vote_response.json().get('message'), 'Vote recorded.')


class PollCreationValidationTests(TestCase):
	def setUp(self):
		self.client = Client()
		self.society = Society.objects.create(
			name='Coding Society',
			description='Test society',
			category='Technology',
		)
		self.admin_user = User.objects.create_user(
			username='admin@example.com',
			email='admin@example.com',
			password='password123',
			up_number='A000001',
			account_type='dev',
		)
		Membership.objects.create(user=self.admin_user, society=self.society, role='admin')

	def test_create_poll_rejects_duplicate_option_text(self):
		response = self.client.post(
			'/api/societies/polls/create/',
			data={
				'admin_email': self.admin_user.email,
				'society_name': self.society.name,
				'title': 'Pick a language',
				'description': 'Vote now',
				'options': ['Python', 'Python', ''],
				'duration_hours': 4,
			},
			content_type='application/json',
		)

		self.assertEqual(response.status_code, 400)
		self.assertEqual(
			response.json()['error'],
			'At least 2 unique poll options are required.',
		)

	def test_create_poll_sets_default_closing_flag(self):
		response = self.client.post(
			'/api/societies/polls/create/',
			data={
				'admin_email': self.admin_user.email,
				'society_name': self.society.name,
				'title': 'Pick a workshop topic',
				'description': 'Choose one option.',
				'options': ['AI', 'Web', 'Mobile'],
				'duration_hours': 4,
			},
			content_type='application/json',
		)

		self.assertEqual(response.status_code, 201)
		poll = Poll.objects.get(title='Pick a workshop topic')
		self.assertFalse(poll.notified_closing_soon)
		self.assertEqual(PollOption.objects.filter(poll=poll).count(), 3)


class ReviewReactionAndAnalyticsTests(TestCase):
	def setUp(self):
		self.client = Client()
		self.society = Society.objects.create(
			name='Design Society',
			description='Design community',
			category='Arts',
		)
		self.member = User.objects.create_user(
			username='member2@example.com',
			email='member2@example.com',
			password='password123',
			up_number='UP009001',
		)
		self.author = User.objects.create_user(
			username='author@example.com',
			email='author@example.com',
			password='password123',
			up_number='UP009002',
		)
		self.admin = User.objects.create_user(
			username='admin2@example.com',
			email='admin2@example.com',
			password='password123',
			up_number='A009003',
		)

		Membership.objects.create(user=self.member, society=self.society, role='member')
		Membership.objects.create(user=self.author, society=self.society, role='member')

		self.review = Review.objects.create(
			user=self.author,
			society=self.society,
			rating=4,
			comment='Solid events and good atmosphere.',
		)

	def test_member_can_switch_reaction(self):
		first = self.client.post(
			'/api/societies/reviews/react/',
			data={
				'email': self.member.email,
				'review_id': self.review.id,
				'reaction_type': 'like',
			},
			content_type='application/json',
		)
		self.assertEqual(first.status_code, 201)

		second = self.client.post(
			'/api/societies/reviews/react/',
			data={
				'email': self.member.email,
				'review_id': self.review.id,
				'reaction_type': 'dislike',
			},
			content_type='application/json',
		)

		self.assertEqual(second.status_code, 200)
		self.assertEqual(second.json()['user_reaction'], 'dislike')
		self.assertEqual(second.json()['likes'], 0)
		self.assertEqual(second.json()['dislikes'], 1)
		self.assertEqual(ReviewReaction.objects.filter(user=self.member, review=self.review).count(), 1)

		reviews_response = self.client.get(
			'/api/societies/reviews/',
			{'society': self.society.name, 'viewer_email': self.member.email},
		)
		self.assertEqual(reviews_response.status_code, 200)
		review_payload = reviews_response.json()['reviews'][0]
		self.assertEqual(review_payload['user_reaction'], 'dislike')
		self.assertTrue(review_payload['can_react'])

	def test_admin_can_fetch_monthly_review_analytics(self):
		second_review = Review.objects.create(
			user=self.member,
			society=self.society,
			rating=5,
			comment='Great workshops.',
		)

		now = timezone.now()
		Review.objects.filter(id=self.review.id).update(created_at=now - timedelta(days=35))
		Review.objects.filter(id=second_review.id).update(created_at=now - timedelta(days=5))

		response = self.client.get(
			'/api/societies/reviews/analytics/',
			{'society': self.society.name, 'viewer_email': self.admin.email},
		)

		self.assertEqual(response.status_code, 200)
		payload = response.json()
		self.assertEqual(payload['society_name'], self.society.name)
		self.assertEqual(len(payload['trends']), 2)
		self.assertIn('avg_rating', payload['trends'][0])
		self.assertIn('review_count', payload['trends'][0])
		self.assertIn('member_count', payload['trends'][0])

	def test_non_admin_cannot_fetch_review_analytics(self):
		response = self.client.get(
			'/api/societies/reviews/analytics/',
			{'society': self.society.name, 'viewer_email': self.member.email},
		)

		self.assertEqual(response.status_code, 403)
