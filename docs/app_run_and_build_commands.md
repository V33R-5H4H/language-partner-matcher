# Application Build & Run Commands Reference Guide

> **Project:** Language Partner Matcher  
> **Scope:** Complete reference for executing and compiling the **Flutter Mobile/Web Client** (`test1/`) and the **FastAPI Backend Stack** (`backend/`) across local development, Android emulators, physical phones, and AWS Cloud.

---

## 📱 1. Flutter Client (`test1/`)

Always execute Flutter commands from the `test1` project folder:
```powershell
cd c:\V33R\Programming\College\Sem_7\Project\test1.0\test1
```

### A. Run Commands (Development & Debugging)

| Target / Environment | Command | Description |
| :--- | :--- | :--- |
| **List Connected Devices** | `flutter devices` | Displays all attached physical USB devices, emulators, and browsers with their device IDs. |
| **Run Default Device** | `flutter run` | Automatically picks the active connected phone or emulator. |
| **Run on Android Emulator** | `flutter run -d emulator-5554` | Launches on the running Android Studio emulator. |
| **Run Pointing to AWS Backend** | `flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://13.235.12.217:8000` | Overrides API endpoint to target the live AWS EC2 App Server. |
| **Run in Chrome (Web)** | `flutter run -d chrome --dart-define=API_BASE_URL=http://13.235.12.217:8000` | Launches the Flutter Web application in Google Chrome. |
| **Run on Windows Desktop** | `flutter run -d windows` | Builds and launches native Windows desktop client. |

> [!TIP]
> **Interactive Keyboard Shortcuts in `flutter run`:**
> - `r` : **Hot Reload** (Updates widgets and UI in <1 second without losing state).
> - `R` : **Hot Restart** (Resets app state and restarts from `main()`).
> - `p` : Toggle debug painting overlay.
> - `q` : Detach and terminate the running session.

---

### B. Build Commands (Production Releases)

#### 1. Universal Release APK (Recommended for Testing & Sharing)
Builds a single `.apk` compatible with all Android CPU architectures (ARMv7, ARM64, x86_64):
```bash
flutter build apk --release --dart-define=API_BASE_URL=http://13.235.12.217:8000
```
- **Output File:** `test1/build/app/outputs/flutter-apk/app-release.apk`
- **Install Directly via ADB to USB Phone:**
  ```powershell
  adb install -r build\app\outputs\flutter-apk\app-release.apk
  ```

#### 2. Split-per-ABI APKs (Optimized ~20-25 MB size per phone architecture)
Separates the output into distinct APKs to minimize download size on real devices:
```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=http://13.235.12.217:8000
```
- **Output Directory:** `test1/build/app/outputs/flutter-apk/`
  - `app-arm64-v8a-release.apk` (Recommended for modern Android smartphones)
  - `app-armeabi-v7a-release.apk` (For older 32-bit Android phones)
  - `app-x86_64-release.apk` (For x86_64 PC emulators)

#### 3. Android App Bundle (AAB for Google Play Store)
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=http://13.235.12.217:8000
```
- **Output File:** `test1/build/app/outputs/bundle/release/app-release.aab`

#### 4. Web Production Bundle
Generates minified CanvasKit and HTML/JS static assets (with `--base-href /web/` for EC2 hosting):
```bash
flutter build web --release --base-href /web/ --dart-define=API_BASE_URL=http://13.235.12.217:8000
```
- **Output Directory:** `test1/build/web/`

---

### C. Build Maintenance & Troubleshooting

If you encounter Gradle locking, cached dependency errors, or stale build artifacts:
```bash
flutter clean
flutter pub get
```

---

## 🖥️ 2. FastAPI Backend Stack (`backend/`)

### A. AWS App Server (Decoupled Production Stack)

Run inside `~/test/language-partner-matcher/backend` on your EC2 App Server (`ubuntu@13.235.12.217`):

| Action | Command | Purpose |
| :--- | :--- | :--- |
| **Pull Updates** | `git pull` | Fetches latest backend code from `main`. |
| **Build & Launch** | `docker compose -f docker-compose.decoupled.yml up -d --build` | Builds and launches stateless backend connected to RDS & Redis. |
| **Stream Live Logs** | `docker compose -f docker-compose.decoupled.yml logs -f` | Inspects real-time Uvicorn output and error logs. |
| **Restart Backend** | `docker compose -f docker-compose.decoupled.yml restart` | Reloads modified `.env` configuration. |
| **Stop Stack** | `docker compose -f docker-compose.decoupled.yml down` | Gracefully stops the container. |
| **Health Check** | `curl http://localhost:8000/api/v1/health` | Verifies DB and Redis connectivity. |

---

### B. Local Host Machine (Development & Testing)

Run inside `c:\V33R\Programming\College\Sem_7\Project\test1.0\backend`:

#### Option 1: Full Local Docker Stack (Postgres + Redis + FastAPI)
```bash
docker-compose up --build -d
docker-compose logs -f fastapi_backend
```

#### Option 2: Python Virtual Environment (Local Uvicorn with Hot-Reload)
```powershell
.\venv\Scripts\activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

#### Option 3: Run Backend Test Suite
```powershell
pytest tests/test_health.py -v
```
