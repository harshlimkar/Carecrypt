# CareCrypt — Deployment Guide

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Flutter | ≥ 3.22 | Run `flutter upgrade` |
| Android SDK | API 33+ | Target & compile SDK |
| Java | 17 | Required by Gradle |
| Python | 3.11+ | For backend (optional) |
| Ollama | Latest | For AI drug analysis |

---

## 1. Supabase Setup

### 1.1 Create Project
1. Go to [supabase.com](https://supabase.com) → New Project
2. Note your **Project URL** and **Anon Key**

### 1.2 Apply Schema
```sql
-- Run in Supabase SQL Editor:
\i database/schema.sql
\i database/seed.sql
```

### 1.2a Apply Database Migrations (Required for v3.0 / Security Enhancements)
```sql
-- One-time QR token validation, access logs, and lab reports schema enhancements.
-- Run the full contents of: database/complete_migration_v3.sql
-- in Supabase SQL Editor
```
> This modifies `lab_reports` to support local PostgreSQL encrypted storage,
> creates the `access_logs` and `qr_tokens` tables, and sets up the
> `use_qr_token()` atomic database function.

### 1.3 Enable Row Level Security
All tables have RLS enabled by default in `schema.sql`.


---

## 2. Firebase Setup

### 2.1 Create Firebase Project
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app with package name: `com.carecrypt.app`
3. Download `google-services.json` → place in `android/app/`

### 2.2 Enable Cloud Messaging
Firebase Console → Project Settings → Cloud Messaging → Enable

---

## 3. Ollama Setup (AI — Optional)

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull Llama3 model (~4GB)
ollama pull llama3

# Start server (runs on port 11434)
ollama serve
```

> The Flutter app works without Ollama — it falls back to cached safety scores.

---

## 4. Environment Configuration

Copy `.env.example` to `.env` in the project root:

```bash
cp .env.example .env
```

Fill in your values:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3
FIREBASE_PROJECT_ID=your-firebase-project
```

---

## 5. Flutter Build

```bash
cd carecrypt

# Install dependencies
flutter pub get

# Debug APK (fast, for testing)
flutter build apk --debug

# Release APK (requires signing keystore)
flutter build apk --release

# Install on connected Android device
flutter install
```

### APK Location
```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## 6. Python Backend (Optional)

```bash
cd backend

# Create virtual environment
python -m venv venv
venv\Scripts\activate     # Windows
source venv/bin/activate  # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Start server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: `http://localhost:8000/docs`

---

## 7. Android Permissions

The following are already configured in `AndroidManifest.xml`:
- `NFC` — For doctor/nurse NFC sessions
- `BIOMETRIC` / `USE_FINGERPRINT` — For biometric auth
- `CAMERA` — For QR scanning
- `INTERNET` — For Supabase & Firebase
- `POST_NOTIFICATIONS` — For FCM alerts (Android 13+)

---

## 8. Production Checklist

- [ ] Replace all `.env` values with production secrets
- [ ] Enable Firebase App Check
- [ ] Set Supabase RLS policies reviewed by security team
- [ ] Configure SSL certificate pinning in `network_security_config.xml`
- [ ] Enable ProGuard for release builds
- [ ] Set up honeypatient IDs in `database/seed.sql`
- [ ] Configure FCM topic for security alerts
- [ ] Review and restrict `ALLOWED_ORIGINS` in backend `config.py`

---

## 9. Role Accounts (Dev/Test)

Seed data creates these test accounts (see `database/seed.sql`):

| Role | Email | Password |
|------|-------|---------|
| Patient | patient@carecrypt.dev | Test@123 |
| Doctor | doctor@carecrypt.dev | Test@123 |
| Lab Tech | lab@carecrypt.dev | Test@123 |
| Pharmacist | pharma@carecrypt.dev | Test@123 |
| Nurse | nurse@carecrypt.dev | Test@123 |

> ⚠️ Change all passwords before production deployment.

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│              Flutter App (Android)           │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ Patient  │  │  Doctor  │  │   Nurse   │  │
│  │  Portal  │  │  Portal  │  │   Portal  │  │
│  └──────────┘  └──────────┘  └───────────┘  │
│  ┌──────────┐  ┌──────────────────────────┐  │
│  │   Lab    │  │    Pharmacist Portal     │  │
│  │  Portal  │  │  (QR Scan + Dispense)    │  │
│  └──────────┘  └──────────────────────────┘  │
└───────────────────────┬─────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌──────────────┐ ┌─────────────┐ ┌──────────┐
│   Supabase   │ │  FastAPI    │ │  Ollama  │
│  (Postgres + │ │  Backend    │ │  Llama3  │
│  Realtime +  │ │  (optional) │ │   (AI)   │
│    Auth)     │ └─────────────┘ └──────────┘
└──────────────┘
```
