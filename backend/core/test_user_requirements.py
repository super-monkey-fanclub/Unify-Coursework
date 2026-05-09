from datetime import timedelta
import json

from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone

from core.models import Membership, Notification, Poll, PollOption, Review, ReviewReaction, Society


User = get_user_model()


class UserRequirementTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.society = Society.objects.create(
            name='Chess Club',
            description='A test society',
            category='Games',
        )
        self.member = User.objects.create_user(
            username='member@example.com',
            email='member@example.com',
            password='password123',
            up_number='UP100001',
        )
        self.other_member = User.objects.create_user(
            username='other@example.com',
            email='other@example.com',
            password='password123',
            up_number='UP100002',
        )
        Membership.objects.create(user=self.member, society=self.society, role='member')
        Membership.objects.create(user=self.other_member, society=self.society, role='member')

        self.poll = Poll.objects.create(
            society=self.society,
            title='Best opening?',
            description='Choose one option.',
            opens_at=timezone.now() - timedelta(hours=1),
            closes_at=timezone.now() + timedelta(hours=1),
        )
        self.option_a = PollOption.objects.create(poll=self.poll, option_text='e4')
        self.option_b = PollOption.objects.create(poll=self.poll, option_text='d4')

    def _register(self, email='new@example.com', password='Pass123!'):
        return self.client.post(
            '/api/auth/register/',
            data=json.dumps({
                'name': 'New User',
                'email': email,
                'password': password,
                'opt_in_email': True,
            }),
            content_type='application/json',
        )

    def test_register_creates_user_and_hashes_password(self):
        response = self._register()

        self.assertEqual(response.status_code, 201)
        user = User.objects.get(email='new@example.com')
        self.assertTrue(user.check_password('Pass123!'))
        self.assertEqual(user.account_type, 'regular')
        self.assertTrue(user.opt_in_email)

    def test_login_accepts_correct_credentials(self):
        response = self.client.post(
            '/api/auth/login/',
            data=json.dumps({'email': self.member.email, 'password': 'password123'}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('auth_token', response.json())

    def test_login_rejects_wrong_password(self):
        response = self.client.post(
            '/api/auth/login/',
            data=json.dumps({'email': self.member.email, 'password': 'wrong-password'}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()['error'], 'Invalid email or password.')

    def test_join_society_creates_membership_and_notifications(self):
        before = Notification.objects.filter(user=self.other_member, society=self.society).count()

        joiner = User.objects.create_user(
            username='joiner@example.com',
            email='joiner@example.com',
            password='password123',
            up_number='UP100003',
        )

        response = self.client.post(
            '/api/societies/join/',
            data=json.dumps({'email': joiner.email, 'society_name': self.society.name}),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(Membership.objects.filter(user=joiner, society=self.society).exists())
        self.assertEqual(Notification.objects.filter(user=self.other_member, society=self.society).count(), before + 1)

    def test_member_can_create_review_after_two_weeks(self):
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )

        response = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 5,
                'comment': 'Great society.',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(Review.objects.filter(user=self.member, society=self.society).exists())

    def test_member_cannot_review_before_two_weeks(self):
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=10)
        )

        response = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 4,
                'comment': 'Too early.',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertIn('2 weeks', response.json()['error'])

    def test_review_comment_max_500_chars(self):
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        response = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 4,
                'comment': 'a' * 501,
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('500 characters or less', response.json()['error'])

    def test_offensive_review_is_blocked(self):
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        response = self.client.post(
            '/api/societies/reviews/add/',
            data=json.dumps({
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 2,
                'comment': 'This is stupid.',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.json()['error'], 'Offensive language detected. Please edit your review.')

    def test_user_can_like_and_dislike_review(self):
        Membership.objects.filter(user=self.other_member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        review = Review.objects.create(
            user=self.other_member,
            society=self.society,
            rating=4,
            comment='Good club.',
        )

        like = self.client.post(
            '/api/societies/reviews/react/',
            data=json.dumps({
                'email': self.member.email,
                'review_id': review.id,
                'reaction_type': 'like',
            }),
            content_type='application/json',
        )
        dislike = self.client.post(
            '/api/societies/reviews/react/',
            data=json.dumps({
                'email': self.member.email,
                'review_id': review.id,
                'reaction_type': 'dislike',
            }),
            content_type='application/json',
        )

        self.assertEqual(like.status_code, 201)
        self.assertEqual(dislike.status_code, 200)
        self.assertEqual(ReviewReaction.objects.filter(user=self.member, review=review).count(), 1)
        self.assertEqual(ReviewReaction.objects.get(user=self.member, review=review).reaction_type, 'dislike')

    def test_admin_cannot_like_or_dislike_reviews(self):
        admin = User.objects.create_user(
            username='admin@example.com',
            email='admin@example.com',
            password='password123',
            up_number='A100001',
        )
        Membership.objects.create(user=admin, society=self.society, role='admin')
        review = Review.objects.create(
            user=self.other_member,
            society=self.society,
            rating=4,
            comment='Nice club.',
        )

        response = self.client.post(
            '/api/societies/reviews/react/',
            data=json.dumps({
                'email': admin.email,
                'review_id': review.id,
                'reaction_type': 'like',
            }),
            content_type='application/json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.json()['error'], 'Admins cannot like or dislike reviews.')

    def test_member_can_vote_once_and_results_hide_voter_names(self):
        vote = self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({
                'email': self.member.email,
                'poll_id': self.poll.id,
                'option_id': self.option_a.id,
            }),
            content_type='application/json',
        )
        repeat_vote = self.client.post(
            '/api/societies/polls/vote/',
            data=json.dumps({
                'email': self.member.email,
                'poll_id': self.poll.id,
                'option_id': self.option_b.id,
            }),
            content_type='application/json',
        )
        detail = self.client.get(
            '/api/societies/polls/detail/',
            {'poll_id': self.poll.id, 'viewer_email': self.member.email},
        )

        self.assertEqual(vote.status_code, 201)
        self.assertEqual(repeat_vote.status_code, 409)
        payload = detail.json()
        self.assertEqual(payload['poll']['total_votes'], 1)
        self.assertNotIn('voter', json.dumps(payload).lower())
        self.assertIn('viewer_vote_option_id', payload['poll'])

    def test_review_list_supports_rating_and_popularity_sorting(self):
        Membership.objects.filter(user=self.other_member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=15)
        )
        high = Review.objects.create(
            user=self.other_member,
            society=self.society,
            rating=5,
            comment='Excellent.',
        )
        ReviewReaction.objects.create(user=self.member, review=high, reaction_type='like')

        low_user = User.objects.create_user(
            username='low@example.com',
            email='low@example.com',
            password='password123',
            up_number='UP100003',
        )
        Membership.objects.create(user=low_user, society=self.society, role='member')
        low = Review.objects.create(
            user=low_user,
            society=self.society,
            rating=2,
            comment='Okay.',
        )

        rating_response = self.client.get('/api/societies/reviews/', {'society': self.society.name, 'sort': 'rating'})
        popularity_response = self.client.get('/api/societies/reviews/', {'society': self.society.name, 'sort': 'popularity'})

        self.assertEqual(rating_response.status_code, 200)
        self.assertEqual(popularity_response.status_code, 200)
        self.assertEqual(rating_response.json()['reviews'][0]['rating'], 5)
        self.assertEqual(popularity_response.json()['reviews'][0]['likes'], 1)

    def test_notifications_can_be_fetched_and_marked_read(self):
        Notification.objects.create(
            user=self.member,
            society=self.society,
            notif_type='poll',
            message='New poll available.',
        )
        fetch = self.client.get('/api/notifications/', {'society': self.society.name, 'viewer_email': self.member.email})
        self.assertEqual(fetch.status_code, 200)
        notif_id = fetch.json()['notifications'][0]['id']

        token = self.client.post(
            '/api/auth/login/',
            data=json.dumps({'email': self.member.email, 'password': 'password123'}),
            content_type='application/json',
        ).json()['auth_token']

        mark = self.client.post(
            '/api/notifications/mark_read/',
            data=json.dumps({'notification_id': notif_id, 'auth_token': token}),
            content_type='application/json',
        )
        self.assertEqual(mark.status_code, 200)
        self.assertTrue(Notification.objects.get(id=notif_id).read)

    def test_society_list_exposes_average_rating_and_member_count(self):
        Review.objects.create(user=self.member, society=self.society, rating=4, comment='Nice.')
        response = self.client.get('/api/societies/')
        self.assertEqual(response.status_code, 200)
        item = next(s for s in response.json()['societies'] if s['name'] == self.society.name)
        self.assertEqual(item['member_count'], 2)
        self.assertEqual(item['average_rating'], 4.0)
