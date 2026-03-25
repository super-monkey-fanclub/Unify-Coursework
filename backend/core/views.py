import json

from django.contrib.auth import get_user_model
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse, HttpRequest


User = get_user_model()


def _json_body(request: HttpRequest) -> dict:
	try:
		return json.loads(request.body.decode("utf-8"))
	except Exception:
		return {}


@csrf_exempt
@require_http_methods(["POST"])
def register_view(request: HttpRequest):
	data = _json_body(request)

	name = (data.get("name") or "").strip()
	email = (data.get("email") or "").strip().lower()
	password = data.get("password") or ""

	if not name or not email or not password:
		return JsonResponse({"error": "All fields are required."}, status=400)

	if "@" not in email or "." not in email:
		return JsonResponse({"error": "Enter a valid email address."}, status=400)

	if User.objects.filter(email=email).exists():
		return JsonResponse({"error": "An account with that email already exists."}, status=409)

	# Use email as username so it's unique and simple.
	user = User.objects.create_user(username=email, email=email, password=password)
	user.first_name = name
	user.save()

	return JsonResponse(
		{
			"message": "Registration successful.",
			"user": {
				"id": user.id,
				"username": user.username,
				"email": user.email,
			},
		},
		status=201,
	)


@csrf_exempt
@require_http_methods(["POST"])
def login_view(request: HttpRequest):
	data = _json_body(request)

	email = (data.get("email") or "").strip().lower()
	password = data.get("password") or ""

	if not email or not password:
		return JsonResponse({"error": "Email and password are required."}, status=400)

	try:
		user = User.objects.get(email=email)
	except User.DoesNotExist:
		return JsonResponse({"error": "Invalid email or password."}, status=401)

	if not user.check_password(password):
		return JsonResponse({"error": "Invalid email or password."}, status=401)

	return JsonResponse(
		{
			"message": "Login successful.",
			"user": {
				"id": user.id,
				"username": user.username,
				"email": user.email,
			},
		},
		status=200,
	)
