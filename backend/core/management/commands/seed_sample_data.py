import random
from django.core.management.base import BaseCommand
from django.utils import timezone

from django.contrib.auth import get_user_model

from core.models import Society, Membership, Review

User = get_user_model()


SOCIETY_TEMPLATES = [
    ('Art Society', 'A friendly society for drawing, painting, and creative workshops.', 'Creative', 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop'),
    ('Anime Society', 'Weekly anime screenings and socials for all fans.', 'Culture', 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop'),
    ('Gaming Society', 'Casual and competitive gaming events across many genres.', 'Technology', 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop'),
    ('Music Society', 'Jam sessions, open mics, and opportunities to perform.', 'Creative', 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop'),
    ('Photography Club', 'Photo walks, editing tips, and portfolio feedback.', 'Creative', 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&auto=format&fit=crop'),
    ('Dance Society', 'Learn routines and perform at events throughout the year.', 'Performance', 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop'),
    ('Drama Club', 'Acting workshops, productions, and backstage roles.', 'Performance', 'https://plus.unsplash.com/premium_photo-1684923604128-c48f46b0cb00?q=80&w=1471&auto=format&fit=crop'),
    ('Coding Society', 'Hack nights, project teams, and interview practice.', 'Technology', 'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=800&auto=format&fit=crop'),
    ('Robotics Club', 'Build, program, and compete with robotics projects.', 'Technology', 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop'),
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
        for tpl in SOCIETY_TEMPLATES:
            # support both (name, desc, category) and (name, desc, category, image_url)
            if len(tpl) == 4:
                name, desc, category, image_url = tpl
                defaults = {'description': desc, 'category': category, 'image_url': image_url}
            else:
                name, desc, category = tpl
                defaults = {'description': desc, 'category': category}
            s, _ = Society.objects.get_or_create(name=name, defaults=defaults)
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
