from datetime import timedelta
import json

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from core.models import Membership, Notification, Poll, PollOption, Review, ReviewResponse, ReviewReaction, Society


User = get_user_model()


class AdminRequirementTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.society = Society.objects.create(
            name='Design Society',
            description='A test society',
            category='Arts',
        )
        self.admin = User.objects.create_user(
            username='admin@example.com',
            email='admin@example.com',
            password='password123',
            up_number='A100001',
        )
        self.member = User.objects.create_user(
            username='member@example.com',
            email='member@example.com',
            password='password123',
            up_number='UP200001',
        )
        Membership.objects.create(user=self.admin, society=self.society, role='admin')
        Membership.objects.create(user=self.member, society=self.society, role='member')

    def _create_poll(self, title='Best event?', description='Choose one.', duration_hours=24):
        response = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': title,
                'description': description,
                'options': ['Option A', 'Option B'],
                'duration_hours': duration_hours,
            }),
            content_type='application/json',
        )
        return response

    def test_admin_can_create_poll(self):
        response = self._create_poll()
        self.assertEqual(response.status_code, 201)
        self.assertTrue(Poll.objects.filter(title='Best event?', society=self.society).exists())

    def test_poll_duration_must_be_between_24_and_168_hours(self):
        short = self._create_poll(title='Short poll', duration_hours=12)
        long = self._create_poll(title='Long poll', duration_hours=200)

        self.assertEqual(short.status_code, 400)
        self.assertEqual(short.json()['error'], 'duration_hours must be at least 24 hours.')
        self.assertEqual(long.status_code, 400)
        self.assertEqual(long.json()['error'], 'duration_hours must be 168 hours or less.')

    def test_poll_requires_two_to_ten_options(self):
        too_few = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'Too few',
                'description': 'Test',
                'options': ['Only one'],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )
        too_many = self.client.post(
            '/api/societies/polls/create/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'Too many',
                'description': 'Test',
                'options': [f'Option {i}' for i in range(11)],
                'duration_hours': 24,
            }),
            content_type='application/json',
        )

        self.assertEqual(too_few.status_code, 400)
        self.assertIn('2 unique poll options', too_few.json()['error'])
        self.assertEqual(too_many.status_code, 400)
        self.assertEqual(too_many.json()['error'], 'A poll can have at most 10 options.')

    def test_duplicate_poll_is_rejected(self):
        first = self._create_poll(title='Duplicate title')
        second = self._create_poll(title='Duplicate title')

        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 409)
        self.assertEqual(second.json()['error'], 'Duplicate poll.')

    def test_poll_description_over_500_chars_is_rejected(self):
        response = self._create_poll(description='a' * 501)
        self.assertEqual(response.status_code, 400)
        self.assertIn('500 characters or less', response.json()['error'])

    def test_admin_can_delete_review(self):
        review = Review.objects.create(
            user=self.member,
            society=self.society,
            rating=4,
            comment='Solid society.',
        )

        response = self.client.post(
            '/api/societies/reviews/delete/',
            data=json.dumps({'admin_email': self.admin.email, 'review_id': review.id}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(Review.objects.filter(id=review.id).exists())

    def test_non_admin_cannot_delete_review(self):
        review = Review.objects.create(
            user=self.member,
            society=self.society,
            rating=4,
            comment='Solid society.',
        )
        outsider = User.objects.create_user(
            username='outsider@example.com',
            email='outsider@example.com',
            password='password123',
            up_number='UP200002',
        )

        response = self.client.post(
            '/api/societies/reviews/delete/',
            data=json.dumps({'admin_email': outsider.email, 'review_id': review.id}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'Only society admins can delete reviews.')

    def test_admin_can_respond_to_review_and_notify_reviewer(self):
        review = Review.objects.create(
            user=self.member,
            society=self.society,
            rating=3,
            comment='Could be better.',
        )

        response = self.client.post(
            '/api/societies/reviews/respond/',
            data=json.dumps({
                'admin_email': self.admin.email,
                'review_id': review.id,
                'response_text': 'Thanks for the feedback.',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(ReviewResponse.objects.filter(review=review, admin=self.admin).exists())
        self.assertTrue(Notification.objects.filter(user=self.member, society=self.society, notif_type='review').exists())

    def test_review_analytics_returns_trends_and_stats(self):
        Review.objects.create(user=self.member, society=self.society, rating=5, comment='Great.')
        response = self.client.get('/api/societies/reviews/analytics/', {'society': self.society.name, 'viewer_email': self.admin.email})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['society_name'], self.society.name)
        self.assertIn('trends', payload)
        self.assertIn('stats', payload)
        self.assertEqual(payload['stats']['total_reviews'], 1)

    def test_admin_cannot_like_or_dislike_reviews(self):
        review = Review.objects.create(
            user=self.member,
            society=self.society,
            rating=4,
            comment='Good club.',
        )
        response = self.client.post(
            '/api/societies/reviews/react/',
            data=json.dumps({
                'email': self.admin.email,
                'review_id': review.id,
                'reaction_type': 'like',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'Admins cannot like or dislike reviews.')

    def test_admin_cannot_see_voter_names_in_poll_detail(self):
        poll_response = self._create_poll(title='Anonymous vote test')
        poll = Poll.objects.get(title='Anonymous vote test')
        option = PollOption.objects.filter(poll=poll).first()
        self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({'email': self.member.email, 'poll_id': poll.id, 'option_id': option.id}),
            content_type='application/json',
        )

        detail = self.client.get('/api/societies/polls/detail/', {'poll_id': poll.id, 'viewer_email': self.admin.email})
        self.assertEqual(detail.status_code, 200)
        self.assertNotIn('username', json.dumps(detail.json()).lower())
        self.assertEqual(detail.json()['poll']['total_votes'], 1)

    def test_poll_cannot_be_deleted_before_30_minutes(self):
        poll_response = self._create_poll(title='Too early delete')
        poll = Poll.objects.get(title='Too early delete')

        response = self.client.post(
            '/api/societies/polls/delete/',
            data=json.dumps({'admin_email': self.admin.email, 'poll_id': poll.id}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'Polls can only be deleted after 30 minutes.')

    def test_poll_can_be_deleted_after_30_minutes(self):
        self._create_poll(title='Delete later')
        poll = Poll.objects.get(title='Delete later')
        Poll.objects.filter(id=poll.id).update(created_at=timezone.now() - timedelta(minutes=31))

        response = self.client.post(
            '/api/societies/polls/delete/',
            data=json.dumps({'admin_email': self.admin.email, 'poll_id': poll.id}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertFalse(Poll.objects.filter(id=poll.id).exists())

    def test_society_list_includes_metrics_needed_for_filtering(self):
        Review.objects.create(user=self.member, society=self.society, rating=4, comment='Nice.')
        response = self.client.get('/api/societies/')

        self.assertEqual(response.status_code, 200)
        item = next(s for s in response.json()['societies'] if s['name'] == self.society.name)
        self.assertEqual(item['member_count'], 2)
        self.assertEqual(item['average_rating'], 4.0)
