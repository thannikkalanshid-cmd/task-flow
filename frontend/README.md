# Flutter Frontend

This Flutter app connects to the Django backend for registration, login, profile, and task CRUD.

## Setup

1. Install Flutter.
2. From the `frontend` directory:
   ```bash
   flutter pub get
   flutter run
   ```

## API Base URL

The Android emulator uses `http://10.0.2.2:8000/api` by default. Start
the backend with `python manage.py runserver 0.0.0.0:8000`.

For a physical device or a deployed backend, pass the reachable API URL when
running Flutter:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000/api
```

For Flutter web running on the same computer, use:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```
