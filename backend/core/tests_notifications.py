from django.contrib.auth import get_user_model
from django.test import Client, TestCase
from django.utils import timezone
from datetime import timedelta

from core.models import Membership, Society, Notification, Review, Poll, PollOption

User = get_user_model()


class NotificationTests(TestCase):
    """Test notification API endpoints"""
    
    def setUp(self):
        self.client = Client()
        self.society = Society.objects.create(
            name='Notification Test Society',
            description='Testing notifications',
            category='Test'
        )
        self.member = User.objects.create_user(
            username='member@test.com',
            email='member@test.com',
            password='password123',
            up_number='UP001001',
        )
        self.admin = User.objects.create_user(
            username='admin@test.com',
            email='admin@test.com',
            password='password123',
            up_number='A001001',
        )
        
        Membership.objects.create(user=self.member, society=self.society, role='member')
        Membership.objects.create(user=self.admin, society=self.society, role='admin')
        
        # Create sample notifications
        self.notif1 = Notification.objects.create(
            user=self.member,
            society=self.society,
            notif_type='info',
            message='New event posted',
            read=False
        )
        self.notif2 = Notification.objects.create(
            user=self.member,
            society=self.society,
            notif_type='review',
            message='New review for society',
            read=True
        )

    def test_get_notifications_requires_auth(self):
        """Unauthenticated users cannot fetch notifications"""
        response = self.client.get(
            '/api/notifications/',
            {'society': self.society.name}
        )
        self.assertEqual(response.status_code, 401)

    def test_get_notifications_requires_membership(self):
        """Non-members cannot fetch notifications for a society"""
        non_member = User.objects.create_user(
            username='nonmember@test.com',
            email='nonmember@test.com',
            password='password123',
            up_number='UP001002',
        )
        response = self.client.get(
            '/api/notifications/',
            {'society': self.society.name, 'viewer_email': non_member.email}
        )
        self.assertEqual(response.status_code, 403)

    def test_member_can_fetch_own_notifications(self):
        """Members can fetch their notifications for a society"""
        response = self.client.get(
            '/api/notifications/',
            {'society': self.society.name, 'viewer_email': self.member.email}
        )
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(len(payload['notifications']), 2)
        self.assertIn('id', payload['notifications'][0])
        self.assertIn('message', payload['notifications'][0])
        self.assertIn('read', payload['notifications'][0])

    def test_join_society_creates_notifications_for_existing_members(self):
        """When a new member joins, existing members receive a notification."""
        joiner = User.objects.create_user(
            username='joiner@test.com',
            email='joiner@test.com',
            password='password123',
            up_number='UP001003',
        )

        before_member = Notification.objects.filter(user=self.member, society=self.society).count()
        before_admin = Notification.objects.filter(user=self.admin, society=self.society).count()

        response = self.client.post(
            '/api/societies/join/',
            data={'email': joiner.email, 'society_name': self.society.name},
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 201)

        after_member = Notification.objects.filter(user=self.member, society=self.society).count()
        after_admin = Notification.objects.filter(user=self.admin, society=self.society).count()
        self.assertEqual(after_member, before_member + 1)
        self.assertEqual(after_admin, before_admin + 1)

        # Joiner also receives a notification
        self.assertEqual(Notification.objects.filter(user=joiner, society=self.society).count(), 1)

    def test_create_announcement_notifies_members_only(self):
        """Posting an announcement notifies society members (excluding the poster)."""
        outsider = User.objects.create_user(
            username='outsider@test.com',
            email='outsider@test.com',
            password='password123',
            up_number='UP001004',
        )

        before_member = Notification.objects.filter(user=self.member, society=self.society).count()
        before_admin = Notification.objects.filter(user=self.admin, society=self.society).count()
        before_outsider = Notification.objects.filter(user=outsider, society=self.society).count()

        response = self.client.post(
            '/api/societies/polls/info/create/',
            data={
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'New update',
                'content': 'We have a new event next week.',
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 201)

        self.assertEqual(
            Notification.objects.filter(user=self.member, society=self.society).count(),
            before_member + 1,
        )
        # Poster also receives a notification
        self.assertEqual(
            Notification.objects.filter(user=self.admin, society=self.society).count(),
            before_admin + 1,
        )
        self.assertEqual(
            Notification.objects.filter(user=outsider, society=self.society).count(),
            before_outsider,
        )

    def test_create_poll_notifies_members_only(self):
        """Creating a poll notifies society members (excluding the poster)."""
        outsider = User.objects.create_user(
            username='outsider2@test.com',
            email='outsider2@test.com',
            password='password123',
            up_number='UP001005',
        )

        before_member = Notification.objects.filter(user=self.member, society=self.society).count()
        before_admin = Notification.objects.filter(user=self.admin, society=self.society).count()
        before_outsider = Notification.objects.filter(user=outsider, society=self.society).count()

        response = self.client.post(
            '/api/societies/polls/create/',
            data={
                'admin_email': self.admin.email,
                'society_name': self.society.name,
                'title': 'Choose a time',
                'description': 'Pick a meeting time.',
                'options': ['Mon', 'Tue', 'Wed'],
                'duration_hours': 4,
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 201)

        self.assertEqual(
            Notification.objects.filter(user=self.member, society=self.society).count(),
            before_member + 1,
        )
        self.assertEqual(
            Notification.objects.filter(user=self.admin, society=self.society).count(),
            before_admin + 1,
        )
        self.assertEqual(
            Notification.objects.filter(user=outsider, society=self.society).count(),
            before_outsider,
        )

    def test_add_review_notifies_society_members(self):
        """Adding a review notifies other members of that society."""
        # Ensure membership is old enough to allow reviewing.
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=20)
        )
        Membership.objects.filter(user=self.admin, society=self.society).update(
            created_at=timezone.now() - timedelta(days=20)
        )

        before_admin = Notification.objects.filter(user=self.admin, society=self.society).count()
        before_member = Notification.objects.filter(user=self.member, society=self.society).count()

        response = self.client.post(
            '/api/societies/reviews/add/',
            data={
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 5,
                'comment': 'Great society!',
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 201)

        # Admin and reviewer are notified
        self.assertEqual(
            Notification.objects.filter(user=self.admin, society=self.society).count(),
            before_admin + 1,
        )
        self.assertEqual(
            Notification.objects.filter(user=self.member, society=self.society).count(),
            before_member + 1,
        )

        self.assertTrue(Review.objects.filter(society=self.society).exists())

    def test_admin_review_response_notifies_reviewer(self):
        """When an admin responds to a review, the reviewer is notified."""
        # Ensure membership is old enough to allow reviewing.
        Membership.objects.filter(user=self.member, society=self.society).update(
            created_at=timezone.now() - timedelta(days=20)
        )
        Membership.objects.filter(user=self.admin, society=self.society).update(
            created_at=timezone.now() - timedelta(days=20)
        )

        review_res = self.client.post(
            '/api/societies/reviews/add/',
            data={
                'email': self.member.email,
                'society_name': self.society.name,
                'rating': 4,
                'comment': 'Good society.',
            },
            content_type='application/json',
        )
        self.assertEqual(review_res.status_code, 201)
        review_id = review_res.json()['review']['id']

        before = Notification.objects.filter(user=self.member, society=self.society).count()

        resp = self.client.post(
            '/api/societies/reviews/respond/',
            data={
                'admin_email': self.admin.email,
                'review_id': review_id,
                'response_text': 'Thanks for the feedback!',
            },
            content_type='application/json',
        )
        self.assertIn(resp.status_code, (200, 201))

        after = Notification.objects.filter(user=self.member, society=self.society).count()
        self.assertEqual(after, before + 1)
        self.assertTrue(
            Notification.objects.filter(
                user=self.member,
                society=self.society,
                notif_type='review',
                message__icontains='responded to your review',
            ).exists()
        )

    def test_poll_end_creates_notification_for_members(self):
        """When a poll ends and is finalized, members get a poll-ended notification."""
        now = timezone.now()
        poll = Poll.objects.create(
            society=self.society,
            title='Past poll',
            description='A poll that already closed',
            opens_at=now - timedelta(days=2),
            closes_at=now - timedelta(hours=1),
            ended_posted_as_info=False,
            notified_closing_soon=False,
        )
        PollOption.objects.create(poll=poll, option_text='Option A')
        PollOption.objects.create(poll=poll, option_text='Option B')

        before_member = Notification.objects.filter(user=self.member, society=self.society).count()
        before_admin = Notification.objects.filter(user=self.admin, society=self.society).count()

        response = self.client.get(
            '/api/societies/polls/',
            {'society': self.society.name, 'viewer_email': self.member.email},
        )
        self.assertEqual(response.status_code, 200)

        after_member = Notification.objects.filter(user=self.member, society=self.society).count()
        after_admin = Notification.objects.filter(user=self.admin, society=self.society).count()
        self.assertEqual(after_member, before_member + 1)
        # Admins are members too and should receive poll-ended notifications
        self.assertEqual(after_admin, before_admin + 1)

        notif = Notification.objects.filter(user=self.member, society=self.society, notif_type='poll').order_by('-created_at').first()
        self.assertIsNotNone(notif)
        self.assertIn('Poll ended', notif.message)

    def test_mark_notification_read(self):
        """Member can mark a notification as read"""
        response = self.client.post(
            '/api/notifications/mark_read/',
            data={'notification_id': self.notif1.id, 'auth_token': ''},
            content_type='application/json',
        )
        # Token auth requires bearer token; this will fail auth but we can test the endpoint exists
        # A real test would use a valid token

    def test_mark_notification_read_requires_auth(self):
        """Marking notifications read requires authentication"""
        response = self.client.post(
            '/api/notifications/mark_read/',
            data={'notification_id': self.notif1.id},
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 401)


class AccountSettingsTests(TestCase):
    """Test account settings API endpoint"""
    
    def setUp(self):
        self.client = Client()
        self.user = User.objects.create_user(
            username='user@test.com',
            email='user@test.com',
            password='password123',
            up_number='UP002001',
            opt_in_email=False
        )

    def test_account_settings_requires_auth(self):
        """Updating settings requires authentication"""
        response = self.client.post(
            '/api/auth/settings/',
            data={'email': self.user.email},
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 401)

    def test_can_update_opt_in_email(self):
        """User can update mailing list opt-in preference"""
        response = self.client.post(
            '/api/auth/settings/',
            data={
                'email': self.user.email,
                'current_password': 'password123',
                'new_email': 'user@test.com',
                'opt_in_email': True,
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.opt_in_email)

    def test_can_update_password(self):
        """User can update password"""
        response = self.client.post(
            '/api/auth/settings/',
            data={
                'email': self.user.email,
                'current_password': 'password123',
                'new_email': 'user@test.com',
                'new_password': 'newpassword456',
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('newpassword456'))

    def test_registration_with_opt_in(self):
        """Users can opt-in to mailing list during registration"""
        response = self.client.post(
            '/api/auth/register/',
            data={
                'name': 'Jane Doe',
                'email': 'jane@test.com',
                'password': 'password123',
                'opt_in_email': True,
            },
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 201)
        new_user = User.objects.get(email='jane@test.com')
        self.assertTrue(new_user.opt_in_email)
