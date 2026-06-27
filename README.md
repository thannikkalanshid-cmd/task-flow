# Full-Stack Flutter + Django REST App

This workspace contains a full-stack project with:
- Frontend: Flutter
- Backend: Django REST Framework
- Database: PostgreSQL

## Backend
1. Create and activate a Python virtual environment.
2. Install dependencies:
   ```bash
   pip install -r backend/requirements.txt
   ```
3. Copy `backend/.env.example` to `backend/.env` and update values.
4. Run migrations:
   ```bash
   python backend/manage.py migrate
   ```
5. Create a superuser (optional):
   ```bash
   python backend/manage.py createsuperuser
   ```
6. Start the backend server:
   ```bash
   python backend/manage.py runserver 0.0.0.0:8000
   ```

## Frontend
1. Install Flutter SDK.
2. From the `frontend` directory:
   ```bash
   flutter pub get
   flutter run
   ```
3. The Android emulator uses `http://10.0.2.2:8000/api` by default. For a
   physical device, provide the computer's LAN address without editing source:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000/api
   ```
