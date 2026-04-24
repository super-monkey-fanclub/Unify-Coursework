from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from core.models import Membership, Poll, PollOption, Society


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
