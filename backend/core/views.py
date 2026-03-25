import json

from django.contrib.auth import get_user_model
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django.http import JsonResponse, HttpRequest


from .models import Society, Membership, Review

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


@csrf_exempt
@require_http_methods(["GET"])
def society_reviews_view(request: HttpRequest):
	"""Return all reviews for a given society.

	Query parameter: ?society=Society+Name
	"""
	society_name = (request.GET.get("society") or "").strip()
	if not society_name:
		return JsonResponse({"error": "society query parameter is required."}, status=400)

	try:
		society = Society.objects.get(name=society_name)
	except Society.DoesNotExist:
		return JsonResponse({"error": "Society not found."}, status=404)

	reviews = (
		Review.objects
			.filter(society=society)
			.select_related("user")
			.order_by("-created_at")
	)

	data = [
		{
			"author": r.user.email,
			"rating": r.rating,
			"comment": r.comment,
		}
		for r in reviews
	]

	return JsonResponse({"reviews": data}, status=200)


@csrf_exempt
@require_http_methods(["POST"])
def add_review_view(request: HttpRequest):
	"""Create or update a review for a society by a member.

	Expected JSON body:
	{"email": "user@example.com", "society_name": "Art Society", "rating": 5, "comment": "Great!"}
	"""
	data = _json_body(request)
	email = (data.get("email") or "").strip().lower()
	society_name = (data.get("society_name") or "").strip()
	rating = data.get("rating")
	comment = (data.get("comment") or "").strip()

	if not email or not society_name or rating is None:
		return JsonResponse({"error": "email, society_name and rating are required."}, status=400)

	try:
		rating = int(rating)
	except (TypeError, ValueError):
		return JsonResponse({"error": "rating must be an integer."}, status=400)

	if rating < 1 or rating > 5:
		return JsonResponse({"error": "rating must be between 1 and 5."}, status=400)

	try:
		user = User.objects.get(email=email)
	except User.DoesNotExist:
		return JsonResponse({"error": "User not found for that email."}, status=404)

	try:
		society = Society.objects.get(name=society_name)
	except Society.DoesNotExist:
		return JsonResponse({"error": "Society not found."}, status=404)

	# Only allow members of the society to review it.
	if not Membership.objects.filter(user=user, society=society).exists():
		return JsonResponse({"error": "Only members of this society can leave a review."}, status=403)

	review, created = Review.objects.update_or_create(
		user=user,
		society=society,
		defaults={"rating": rating, "comment": comment},
	)

	return JsonResponse(
		{
			"message": "Review created" if created else "Review updated",
			"review": {
				"author": review.user.email,
				"rating": review.rating,
				"comment": review.comment,
			},
		},
		status=201 if created else 200,
	)
