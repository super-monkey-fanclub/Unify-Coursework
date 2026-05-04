import random
from django.core.management.base import BaseCommand
from django.utils import timezone

from django.contrib.auth import get_user_model

from core.models import Society, Membership, Review

User = get_user_model()


SOCIETY_TEMPLATES = [
    ('Art Society', 'A friendly society for drawing, painting, and creative workshops.', 'Creative'),
    ('Anime Society', 'Weekly anime screenings and socials for all fans.', 'Culture'),
    ('Gaming Society', 'Casual and competitive gaming events across many genres.', 'Technology'),
    ('Music Society', 'Jam sessions, open mics, and opportunities to perform.', 'Creative'),
    ('Photography Club', 'Photo walks, editing tips, and portfolio feedback.', 'Creative'),
    ('Dance Society', 'Learn routines and perform at events throughout the year.', 'Performance'),
    ('Drama Club', 'Acting workshops, productions, and backstage roles.', 'Performance'),
    ('Coding Society', 'Hack nights, project teams, and interview practice.', 'Technology'),
    ('Robotics Club', 'Build, program, and compete with robotics projects.', 'Technology'),
]

SAMPLE_COMMENTS = [
    'Great society — very welcoming!',
    'Had lots of fun at the last event.',
    'Helpful members and good resources.',
    'A friendly community and well organised.',
    'Could use more beginner sessions, but overall great.',
    'Fantastic events and socials.',
    'I learnt a lot from their workshops.',
    'Good mixture of social and practical activities.',
]

SAMPLE_NAMES = [
    ('Alice', 'Johnson'),
    ('Ben', 'Marshall'),
    ('Chloe', 'Smith'),
    ('Daniel', 'Brown'),
    ('Evelyn', 'Clark'),
    ('Frank', 'Green'),
    ('Grace', 'Evans'),
    ('Hannah', 'Lewis'),
    ('Ian', 'Walker'),
    ('Julia', 'Hall'),
    ('Kyle', 'Young'),
    ('Liam', 'King'),
    ('Maya', 'Wright'),
    ('Noah', 'Scott'),
    ('Olivia', 'Adams'),
    ('Peter', 'Baker'),
    ('Quinn', 'Turner'),
    ('Riley', 'Carter'),
    ('Sophie', 'Ward'),
    ('Toby', 'Hughes'),
]


class Command(BaseCommand):
    help = 'Seed sample users, memberships and reviews for development/testing.'

    def add_arguments(self, parser):
        parser.add_argument('--users', type=int, default=12, help='Number of users to create')
        parser.add_argument('--reviews', type=int, default=30, help='Number of reviews to create')

    def handle(self, *args, **options):
        users_count = options['users']
        reviews_count = options['reviews']

        self.stdout.write('Seeding societies...')
        societies = []
        for name, desc, category in SOCIETY_TEMPLATES:
            s, _ = Society.objects.get_or_create(name=name, defaults={'description': desc, 'category': category})
            societies.append(s)

        self.stdout.write(f'Ensuring {users_count} users...')
        created_users = []
        for i in range(users_count):
            username = f'user{i+1}'
            # produce a six-digit UP number and corresponding email in the form up<6digits>@gmail.com
            num = str(1000 + i).zfill(6)
            email = f'up{num}@gmail.com'
            up = f'UP{num}'
            user, created = User.objects.get_or_create(email=email, defaults={'username': username, 'up_number': up})
            # assign a realistic name and mark as filler by appending '*'
            name_idx = i % len(SAMPLE_NAMES)
            first, _ = SAMPLE_NAMES[name_idx]
            user.first_name = f"{first}*"
            user.last_name = ''
            if created:
                user.set_password('password')
            user.save()
            created_users.append(user)

        # create memberships
        self.stdout.write('Creating memberships...')
        for user in created_users:
            # assign each user to 2-4 random societies
            picks = random.sample(societies, k=min(len(societies), random.randint(2, 4)))
            for s in picks:
                Membership.objects.get_or_create(user=user, society=s, defaults={'role': 'member'})

        # make first user admin of first few societies
        admin_user = created_users[0]
        for s in societies[:3]:
            m, _ = Membership.objects.get_or_create(user=admin_user, society=s, defaults={'role': 'admin'})
            if m.role != 'admin':
                m.role = 'admin'
                m.save(update_fields=['role'])

        # create reviews
        self.stdout.write(f'Creating up to {reviews_count} reviews...')
        created = 0
        attempts = 0
        while created < reviews_count and attempts < reviews_count * 4:
            attempts += 1
            user = random.choice(created_users)
            society = random.choice(societies)
            # ensure user is member
            if not Membership.objects.filter(user=user, society=society).exists():
                continue
            rating = random.randint(3, 5)
            comment = random.choice(SAMPLE_COMMENTS)
            try:
                Review.objects.create(user=user, society=society, rating=rating, comment=comment)
                created += 1
            except Exception:
                # skip duplicates or validation errors
                continue

        self.stdout.write(self.style.SUCCESS(f'Seeding complete: {len(created_users)} users, {len(societies)} societies, {created} reviews.'))
