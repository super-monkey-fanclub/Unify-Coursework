import json
from django.contrib.auth.hashers import make_password, check_password
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse

from .models import UnifyUser


def _json_body(request):
    """Parse JSON body, return empty dict on failure."""
    try:
        return json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return {}


@csrf_exempt
@require_http_methods(['POST'])
def register_view(request):
    data = _json_body(request)

    name = data.get('name', '').strip()
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')

    # Basic server-side validation
    if not name or not email or not password:
        return JsonResponse({'error': 'All fields are required.'}, status=400)

    if len(name) > 50:
        return JsonResponse({'error': 'Name must be 50 characters or fewer.'}, status=400)

    if '@' not in email or '.' not in email:
        return JsonResponse({'error': 'Enter a valid email address.'}, status=400)

    if UnifyUser.objects.filter(email=email).exists():
        return JsonResponse({'error': 'An account with that email already exists.'}, status=409)

    user = UnifyUser.objects.create(
        name=name,
        email=email,
        password_hash=make_password(password),
    )

    return JsonResponse({
        'message': 'Registration successful.',
        'up_number': user.up_number,
    }, status=201)


@csrf_exempt
@require_http_methods(['POST'])
def login_view(request):
    data = _json_body(request)

    email = data.get('email', '').strip().lower()
    password = data.get('password', '')

    if not email or not password:
        return JsonResponse({'error': 'Email and password are required.'}, status=400)

    try:
        user = UnifyUser.objects.get(email=email)
    except UnifyUser.DoesNotExist:
        return JsonResponse({'error': 'Invalid email or password.'}, status=401)

    if not check_password(password, user.password_hash):
        return JsonResponse({'error': 'Invalid email or password.'}, status=401)

    return JsonResponse({
        'message': 'Login successful.',
        'user': {
            'up_number': user.up_number,
            'name': user.name,
            'email': user.email,
        }
    }, status=200)
