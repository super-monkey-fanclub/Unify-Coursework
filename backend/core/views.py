import json

from django.contrib.auth import get_user_model
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse, HttpRequest


from .models import Society, Membership

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


@csrf_exempt
@require_http_methods(["POST"])
def join_society_view(request: HttpRequest):
	"""Create a membership for the given user and society.

	Expected JSON body: {"email": "user@example.com", "society_name": "Art Society"}
	"""
	data = _json_body(request)
	email = (data.get("email") or "").strip().lower()
	society_name = (data.get("society_name") or "").strip()

	if not email or not society_name:
		return JsonResponse({"error": "Email and society_name are required."}, status=400)

	try:
		user = User.objects.get(email=email)
	except User.DoesNotExist:
		return JsonResponse({"error": "User not found for that email."}, status=404)

	society, _ = Society.objects.get_or_create(
		name=society_name,
		defaults={"description": "", "category": "General"},
	)

	membership, created = Membership.objects.get_or_create(
		user=user,
		society=society,
		defaults={"role": "member"},
	)

	return JsonResponse(
		{
			"message": "Joined society" if created else "Already a member",
			"membership": {
				"id": membership.id,
				"user_id": membership.user_id,
				"society_id": membership.society_id,
				"role": membership.role,
			},
		},
		status=201 if created else 200,
	)


@csrf_exempt
@require_http_methods(["POST"])
def my_societies_view(request: HttpRequest):
	"""Return all societies the given user is a member of.

	Expected JSON body: {"email": "user@example.com"}
	"""
	data = _json_body(request)
	email = (data.get("email") or "").strip().lower()

	if not email:
		return JsonResponse({"error": "Email is required."}, status=400)

	try:
		user = User.objects.get(email=email)
	except User.DoesNotExist:
		return JsonResponse({"error": "User not found for that email."}, status=404)

	memberships = (
		Membership.objects
			.select_related("society")
			.filter(user=user)
			.order_by("society__name")
	)

	societies = [
		{
			"id": m.society.id,
			"name": m.society.name,
			"description": m.society.description,
			"category": m.society.category,
		}
		for m in memberships
	]

	return JsonResponse({"societies": societies}, status=200)
