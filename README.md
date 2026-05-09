# Unify-Coursework
Joshua Alcazar - up2267668 235305961
Maria - up2305949 235307556
Adefola - up2274013 237086770
Beau - up2281726 237248106
Michael - up2273239 183396154

**Dependencies Setup**
python3 -m pip install -r requirements.txt

**Server Startup**
cd backend
..\.venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000

**Flutter Startup**
cd "unify_frontend"
flutter run -d chrome

**Run Tests**
backend:
powershell -ExecutionPolicy Bypass -File .\run_backend_tests.ps1

or

cd backend
python manage.py test core.test_user_requirements core.test_admin_requirements core.test_system_requirements -v 2

frontend:
powershell -ExecutionPolicy Bypass -File .\run_frontend_tests.ps1

or

cd "unify_frontend"
flutter test test/frontend_requirements_test.dart test/widget_test.dart test/home_test.dart test/auth_navigation_test.dart test/societies_navigation_and_search_test.dart test/society_review_test.dart