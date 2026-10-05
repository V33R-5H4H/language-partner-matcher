# 📦 Migration Guide: Setting Up a Dedicated Clean Repository

This guide explains how to extract and isolate the **Language Partner Matcher** (`backend` + Flutter `frontend`) into its own standalone Git repository without affecting any functionality or carrying over history from other projects.

---

## 1. Target Clean Project Structure

In your new dedicated repository, rename `test1` to `frontend` (or `app`) so the structure is clean and professional:

```
language-partner-matcher/           <-- Root of the new Git repository
├── backend/                        <-- FastAPI + WebSocket backend + Coturn TURN
│   ├── app/
│   │   ├── api/
│   │   ├── core/
│   │   ├── models/
│   │   └── main.py
│   ├── coturn/
│   │   ├── Dockerfile
│   │   └── turnserver.conf
│   ├── deploy/
│   │   └── aws/
│   │       ├── deploy.sh
│   │       └── AWS_DEPLOYMENT_GUIDE.md
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── requirements.txt
│   └── .env.example
│
├── frontend/                       <-- Flutter multi-platform application (formerly test1)
│   ├── android/
│   ├── web/
│   ├── windows/
│   ├── lib/
│   │   ├── core/
│   │   ├── data/
│   │   ├── services/
│   │   ├── views/
│   │   └── main.dart
│   ├── assets/
│   │   └── icons/
│   └── pubspec.yaml
│
├── docs/                           <-- Architecture docs, diagrams & plans
├── .gitignore                      <-- Universal root .gitignore
└── README.md                       <-- Project overview
```

---

## 2. Step-by-Step Migration Instructions

### Step 2.1: Create the New Project Folder
Open **PowerShell** and create a new directory for your standalone repository (outside the old multi-project workspace):

```powershell
# 1. Create a new directory (e.g. in your Projects folder)
New-Item -ItemType Directory -Path "C:\V33R\Programming\Projects\language-partner-matcher"
cd "C:\V33R\Programming\Projects\language-partner-matcher"
```

---

### Step 2.2: Copy Project Directories
Copy `backend`, `test1` (renamed as `frontend`), and `docs` into the new project:

```powershell
$SOURCE = "C:\V33R\Programming\College\Sem_7\Project\test1.0"
$DEST = "C:\V33R\Programming\Projects\language-partner-matcher"

# Copy backend
Copy-Item -Path "$SOURCE\backend" -Destination "$DEST\backend" -Recurse

# Copy frontend (rename test1 -> frontend)
Copy-Item -Path "$SOURCE\test1" -Destination "$DEST\frontend" -Recurse

# Copy docs (if present)
if (Test-Path "$SOURCE\docs") {
    Copy-Item -Path "$SOURCE\docs" -Destination "$DEST\docs" -Recurse
}
```

---

### Step 2.3: Clean Temporary Build Artifacts in the New Directory
Remove local build caches, SQLite database files, and virtual environments before committing:

```powershell
cd "C:\V33R\Programming\Projects\language-partner-matcher"

# Remove Flutter ephemeral build folders
Remove-Item -Recurse -Force "frontend\build" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\.dart_tool" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "frontend\windows\flutter\ephemeral" -ErrorAction SilentlyContinue

# Remove Python pycache & venv
Get-ChildItem -Path "backend" -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force
Remove-Item -Recurse -Force "backend\.venv" -ErrorAction SilentlyContinue
```

---

### Step 2.4: Create the Universal `.gitignore`
Create a clean `.gitignore` at the root of your new repository:

```powershell
@'
# ==========================================
# Root .gitignore - Language Partner Matcher
# ==========================================

# Environment variables & secrets
.env
.env.prod
.env.local
*.pem
*.key

# Python & FastAPI
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/
ENV/
*.sqlite3
*.db

# Docker volumes
postgres_data/
redis_data/

# Flutter & Dart
.dart_tool/
.packages
.pub-cache/
.pub/
build/
*.lock.bak

# Android
**/android/.gradle/
**/android/captures/
**/android/gradle/
**/android/local.properties
**/android/**/GeneratedPluginRegistrant.java
**/android/**/*.apk
**/android/**/*.aab

# Windows desktop
**/windows/flutter/ephemeral/
**/windows/**/*.vcxproj.user

# IDEs & System
.idea/
.vscode/
*.swp
*.DS_Store
Thumbs.db
'@ | Out-File -Encoding utf8 .gitignore
```

---

### Step 2.5: Initialize Git and Push to GitHub

1. Create a **new empty repository** on GitHub (e.g. `https://github.com/your-username/language-partner-matcher.git`). Do NOT check "Initialize with README".
2. In PowerShell inside your new folder:

```powershell
cd "C:\V33R\Programming\Projects\language-partner-matcher"

# 1. Initialize git
git init

# 2. Stage all clean files
git add .

# 3. Create initial commit
git commit -m "feat: initial commit for Language Partner Matcher (FastAPI + Flutter WebRTC)"

# 4. Set default branch to main
git branch -M main

# 5. Link to your new GitHub repository
git remote add origin https://github.com/YOUR-USERNAME/language-partner-matcher.git

# 6. Push code to GitHub
git push -u origin main
```

---

## 3. Verifying Functionality in the New Repository

1. **Verify Backend**:
   ```powershell
   cd "C:\V33R\Programming\Projects\language-partner-matcher\backend"
   docker compose up -d --build
   ```
   Open `http://localhost:8000/docs` to verify the Swagger UI.

2. **Verify Frontend**:
   ```powershell
   cd "C:\V33R\Programming\Projects\language-partner-matcher\frontend"
   flutter pub get
   flutter run -d chrome
   ```

---

## 4. Summary of Why No Functionality is Affected

| Aspect | Status | Why It Remains 100% Intact |
| :--- | :--- | :--- |
| **Backend Imports** | ✅ Unaffected | All Python backend imports use package-relative paths (`from app.core...`, `from app.models...`). |
| **Docker Compose** | ✅ Unaffected | Dockerfile contexts are relative to the `backend/` folder. |
| **Flutter Project** | ✅ Unaffected | Renaming the parent folder from `test1` to `frontend` does not change `pubspec.yaml` (name remains `test1`) or Gradle build configurations (`source = "../.."`). |
| **Icons & Assets** | ✅ Unaffected | `pubspec.yaml` declares `assets/icons/`, which is copied directly with the Flutter app. |
| **Coturn & WebRTC** | ✅ Unaffected | Dynamic token endpoints and ICE server configs are self-contained in the `backend/` services. |
