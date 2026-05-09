from datetime import timedelta
import json

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from core.models import Membership, Notification, Poll, PollOption, Review, Society


User = get_user_model()


class SystemRequirementTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.society = Society.objects.create(
            name='Coding Society',
            description='A test society',
            category='Technology',
        )
        self.user = User.objects.create_user(
            username='user@example.com',
            email='user@example.com',
            password='password123',
            up_number='UP300001',
        )
        self.admin = User.objects.create_user(
            username='admin@example.com',
            email='admin@example.com',
            password='password123',
            up_number='A300001',
        )
        Membership.objects.create(user=self.user, society=self.society, role='member')
        Membership.objects.create(user=self.admin, society=self.society, role='admin')
        self.poll = Poll.objects.create(
            society=self.society,
            title='Preferred day?',
            description='Vote for a day.',
            opens_at=timezone.now() - timedelta(hours=1),
            closes_at=timezone.now() + timedelta(hours=1),
        )
        self.option = PollOption.objects.create(poll=self.poll, option_text='Friday')

    def test_account_creation_and_login(self):
        register = self.client.post(
            '/api/auth/register/',
            data=json.dumps({
                'name': 'New User',
                'email': 'newuser@example.com',
                'password': 'Pass123!',
                'opt_in_email': True,
            }),
            content_type='application/json',
        )
        login = self.client.post(
            '/api/auth/login/',
            data=json.dumps({'email': 'newuser@example.com', 'password': 'Pass123!'}),
            content_type='application/json',
        )

        self.assertEqual(register.status_code, 201)
        self.assertEqual(login.status_code, 200)
        user = User.objects.get(email='newuser@example.com')
        self.assertTrue(user.check_password('Pass123!'))

    def test_register_rejects_weak_password(self):
        response = self.client.post(
            '/api/auth/register/',
            data=json.dumps({
                'name': 'Weak',
                'email': 'weak@example.com',
                'password': 'Password123',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'Password must include at least one symbol.')

    def test_non_member_cannot_vote_or_review(self):
        outsider = User.objects.create_user(
            username='outsider@example.com',
            email='outsider@example.com',
            password='password123',
            up_number='UP300002',
        )
        vote = self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({
                'email': outsider.email,
                'poll_id': self.poll.id,
                'option_id': self.option.id,
            }),
            content_type='application/json',
        )
        review = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': outsider.email,
                'society_name': self.society.name,
                'rating': 4,
                'comment': 'I should not be allowed yet.',
            }),
            content_type='application/json',
        )

        self.assertEqual(vote.status_code, 403)
        self.assertEqual(review.status_code, 403)

    def test_member_can_vote_once_only(self):
        first = self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({
                'email': self.user.email,
                'poll_id': self.poll.id,
                'option_id': self.option.id,
            }),
            content_type='application/json',
        )
        second = self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({
                'email': self.user.email,
                'poll_id': self.poll.id,
                'option_id': self.option.id,
            }),
            content_type='application/json',
        )

        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 409)

    def test_member_can_create_review_after_two_weeks_only_once(self):
        Membership.objects.filter(user=self.user, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        first = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.user.email,
                'society_name': self.society.name,
                'rating': 4,
                'comment': 'First review.',
            }),
            content_type='application/json',
        )
        second = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.user.email,
                'society_name': self.society.name,
                'rating': 5,
                'comment': 'Second review.',
            }),
            content_type='application/json',
        )

        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 403)
        self.assertIn('active review', second.json()['error'])

    def test_offensive_review_is_rejected(self):
        Membership.objects.filter(user=self.user, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        response = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.user.email,
                'society_name': self.society.name,
                'rating': 2,
                'comment': 'This club is stupid.',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'Offensive language detected. Please edit your review.')

    def test_settings_update_email_password_and_opt_in(self):
        token = self.client.post(
            '/api/auth/login/',
            data=json.dumps({'email': self.user.email, 'password': 'password123'}),
            content_type='application/json',
        ).json()['auth_token']

        response = self.client.post(
            '/api/auth/settings/',
            data=json.dumps({
                'auth_token': token,
                'new_email': 'updated@example.com',
                'new_password': 'NewPass123!',
                'opt_in_email': False,
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 200)
        updated = User.objects.get(id=self.user.id)
        self.assertEqual(updated.email, 'updated@example.com')
        self.assertTrue(updated.check_password('NewPass123!'))
        self.assertFalse(updated.opt_in_email)

    def test_society_list_is_ordered_and_includes_metrics(self):
        Society.objects.create(name='Art Society', description='Art', category='Arts')
        response = self.client.get('/api/societies/')

        self.assertEqual(response.status_code, 200)
        names = [item['name'] for item in response.json()['societies']]
        self.assertEqual(names, sorted(names))
        item = next(s for s in response.json()['societies'] if s['name'] == self.society.name)
        self.assertIn('member_count', item)
        self.assertIn('average_rating', item)

    def test_poll_creation_enforces_duration_and_duplicate_rules(self):
        create = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'New poll',
                'description': 'Vote now.',
                'options': ['A', 'B'],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )
        duplicate = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'New poll',
                'description': 'Vote now.',
                'options': ['A', 'B'],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )

        self.assertEqual(create.status_code, 201)
        self.assertEqual(duplicate.status_code, 409)

    def test_poll_description_limit_and_delete_window(self):
        too_long = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'Too long',
                'description': 'a' * 501,
                'options': ['A', 'B'],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )
        self.assertEqual(too_long.status_code, 400)

        create = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'Delete me',
                'description': 'Short',
                'options': ['A', 'B'],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )
        poll = Poll.objects.get(title='Delete me')
        early = self.client.post(
            '/api/societies/polls/delete/',
            data=json.dumps({'admin_email': self.admin.email, 'poll_id': poll.id}),
            content_type='application/json',
        )
        Poll.objects.filter(id=poll.id).update(created_at=timezone.now() - timedelta(minutes=31))
        late = self.client.post(
            '/api/societies/polls/delete/',
            data=json.dumps({'admin_email': self.admin.email, 'poll_id': poll.id}),
            content_type='application/json',
        )

        self.assertEqual(create.status_code, 201)
        self.assertEqual(early.status_code, 403)
        self.assertEqual(late.status_code, 200)

    def test_average_rating_updates_and_notifications_persist(self):
        Membership.objects.filter(user=self.user, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        review = Review.objects.create(
            user=self.user,
            society=self.society,
            rating=5,
            comment='Great society.',
        )
        Notification.objects.create(
            user=self.user,
            society=self.society,
            notif_type='poll',
            message='Reminder to vote.',
        )

        reloaded_review = Review.objects.get(id=review.id)
        reloaded_notification = Notification.objects.get(user=self.user, society=self.society)
        self.assertEqual(reloaded_review.rating, 5)
        self.assertFalse(reloaded_notification.read)
