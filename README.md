# Unify-Coursework
Joshua Alcazar - up2267668 235305961
Maria - up2305949 235307556
Adefola - up2274013 237086770
Beau - up2281726 237248106
Maya - up2266552  198966765
Michael - up2273239 183396154


**Server Startup***
cd backend
..\.venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000

**Flutter Startup**
cd "unify_frontend"
flutter run -d chrome

If you run the app on an Android emulator or a physical device, set the API host with `--dart-define=UNIFY_API_BASE_URL=http://<your-backend-host>:8000` so the Flutter client does not keep pointing at `127.0.0.1` on the device itself.

