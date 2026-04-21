# Professional Video Editor — Complete Project

> **Stack:** Flutter · Native Engine (GLES 3.0) · OpenGL/Metal · Firebase/AWS · Whisper · YOLOv8 · RMBG · Real-ESRGAN · PostgreSQL · RevenueCat  
> **Timeline:** 18 months · 5 phases · 10M+ user scale

---

## Project Structure

```
video_editor_platform/
├── flutter_app/               # Mobile app (iOS + Android)
├── video_engine/              # C++ GPU render engine (stub — integrate via FFI)
├── ai_modules/                # 5 Python FastAPI AI microservices
│   ├── whisper_service/       # Auto-captions (port 8001)
│   ├── rmbg_service/          # Background removal (port 8002)
│   ├── yolo_service/          # Object tracking (port 8003)
│   ├── beats_service/         # Beat detection (port 8004)
│   ├── esrgan_service/        # 4K upscaling (port 8005)
│   ├── docker-compose.yml
│   └── nginx.conf             # AI gateway (port 8000)
├── backend/
│   ├── functions/             # AWS Lambda functions
│   │   ├── auth/              # Firebase auth + JWT
│   │   ├── projects/          # Project CRUD + S3 sync
│   │   ├── templates/         # Template marketplace
│   │   ├── subscriptions/     # RevenueCat webhook
│   │   └── analytics/         # Usage tracking
│   ├── db/migrations/         # PostgreSQL schema
│   └── serverless.yml         # AWS deployment config
└── admin_panel/               # React/Next.js admin (port 3001)
    ├── pages/
    │   ├── login/             # 4-step secure login
    │   ├── dashboard/         # Analytics + stats
    │   ├── templates/         # Template management
    │   └── users/             # User management
    └── lib/admin_auth.ts      # TOTP + OTP + IP auth
```

---

## Phase 1 — MVP Setup (Months 1–3)

### Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

**Firebase setup:**
1. Create project at console.firebase.google.com
2. Add iOS + Android apps, download `google-services.json` / `GoogleService-Info.plist`
3. Enable Email/Password + Google Sign-In providers
4. Place config files in `android/app/` and `ios/Runner/`

**Environment variables** (`.env` or `--dart-define`):
```
API_BASE_URL=https://api.yourapp.com
AI_SERVICE_URL=http://your-ai-server:8000/ai
```

---

## Phase 2 — Backend (AWS Lambda)

### Prerequisites
```bash
npm install -g serverless
npm install
```

### Database Migration
```bash
psql $DATABASE_URL -f backend/db/migrations/001_initial_schema.sql
```

### AWS SSM Parameters (set these first)
```bash
aws ssm put-parameter --name /video-editor/prod/jwt-secret --value "your-secret-256-bit" --type SecureString
aws ssm put-parameter --name /video-editor/prod/database-url --value "postgres://..." --type SecureString
aws ssm put-parameter --name /video-editor/prod/firebase-project-id --value "your-project" --type String
# ... (see serverless.yml for full list)
```

### Deploy Backend
```bash
cd backend
serverless deploy --stage prod
```

---

## Phase 3 — AI Microservices

### Download ONNX Models
```bash
cd ai_modules/models

# Whisper — downloaded automatically by the service on first run

# RMBG (BRIA-RMBG-1.4)
# Download from: https://huggingface.co/briaai/RMBG-1.4
wget https://huggingface.co/briaai/RMBG-1.4/resolve/main/onnx/model.onnx -O rmbg.onnx

# YOLOv8n
pip install ultralytics
python -c "from ultralytics import YOLO; YOLO('yolov8n.pt').export(format='onnx')"
cp yolov8n.onnx models/

# Real-ESRGAN x4
# Download from: https://github.com/xinntao/Real-ESRGAN/releases
wget https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip
```

### Start All AI Services
```bash
cd ai_modules
docker-compose up -d
# All 5 services + nginx gateway available at localhost:8000
```

### Individual service (dev)
```bash
cd ai_modules/whisper_service
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
```

### Requirements per service
```
openai-whisper==20231117
fastapi==0.109.0
uvicorn[standard]==0.27.0
torch==2.1.2
python-multipart==0.0.6

# rmbg_service/requirements.txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
onnxruntime==1.17.0   # or onnxruntime-gpu
opencv-python==4.9.0.80
Pillow==10.2.0
numpy==1.26.3

# yolo_service/requirements.txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
onnxruntime==1.17.0
opencv-python==4.9.0.80
numpy==1.26.3

# beats_service/requirements.txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
librosa==0.10.1
onnxruntime==1.17.0
numpy==1.26.3
soundfile==0.12.1

# esrgan_service/requirements.txt
fastapi==0.109.0
uvicorn[standard]==0.27.0
onnxruntime-gpu==1.17.0
opencv-python==4.9.0.80
numpy==1.26.3
```

---

## Phase 4 — Admin Panel

```bash
cd admin_panel
npm install
npm run dev   # runs on localhost:3001
```

**Hidden admin URL format:** `/mgmt-{random-16-char}/login`  
Generate your hidden path:
```bash
node -e "console.log('mgmt-' + require('crypto').randomBytes(8).toString('hex'))"
```

Set `NEXT_PUBLIC_ADMIN_PATH=mgmt-yourpath` in `.env.local`

**Admin environment variables:**
```env
DATABASE_URL=postgres://...
ADMIN_JWT_SECRET=your-admin-jwt-secret-256bit
TOTP_ENCRYPTION_KEY=your-32-byte-hex-key
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=your-sendgrid-key
SMTP_FROM=admin@yourapp.com
```

**Create first super admin:**
```bash
node -e "
const bcrypt = require('bcryptjs');
const hash = bcrypt.hashSync('YourSecurePassword123!', 12);
console.log('INSERT INTO admins (email, password_hash, role) VALUES (\'admin@yourapp.com\', \'' + hash + '\', \'super_admin\');');
"
```

---

## RevenueCat Setup

1. Create app at app.revenuecat.com
2. Add products in App Store Connect / Google Play:
   - `video_editor_pro_monthly` — $4.99/month
   - `video_editor_premium_monthly` — $9.99/month
3. Set webhook URL: `https://api.yourapp.com/webhooks/revenuecat`
4. Copy webhook secret to AWS SSM

---

## Key Architecture Decisions

| Decision | Choice | Reason |
|---|---|---|
| State management | BLoC | Predictable, testable, undo/redo built-in |
| Video processing | Native GLES 3.0 Engine | Hardware accelerated, zero external dependency |
| AI runtime | ONNX Runtime | iOS CoreML + Android NNAPI hardware acceleration |
| Auth | Firebase + JWT | Social login + custom claims for plan gating |
| Storage | Hive (local) + S3 (cloud) | Offline-first with cloud sync |
| Subscriptions | RevenueCat | Unified iOS + Android IAP, webhook-based |
| Database | PostgreSQL (RDS) | Relational data, full-text search, JSONB |
| API | AWS Lambda | Auto-scale, zero cost at idle |
| CDN | CloudFront | 100+ edge locations, sub-50ms globally |
| Admin auth | 4-step (pwd + TOTP + OTP + IP) | Maximum security for admin panel |

---

## API Endpoints Summary

| Service | Base URL | Auth |
|---|---|---|
| Auth | `POST /auth/firebase` | Public |
| Projects | `GET/POST/PUT/DELETE /projects` | JWT |
| Templates | `GET /templates?q=&category=` | Optional JWT |
| Subscriptions | `GET /subscription` | JWT |
| RevenueCat webhook | `POST /webhooks/revenuecat` | Signature |
| Whisper | `POST /ai/captions/transcribe` | JWT |
| RMBG | `POST /ai/rmbg/remove-bg/image` | JWT |
| YOLO | `POST /ai/tracking/track/video` | JWT |
| Beats | `POST /ai/beats/detect` | JWT |
| ESRGAN | `POST /ai/upscale/upscale/image` | JWT |

---

## Performance Targets

| Metric | Target |
|---|---|
| App cold start | < 3 seconds |
| Timeline scrub | 60fps |
| 1080p 1-min export | < 30 seconds |
| Whisper accuracy | 95%+ |
| RMBG latency (image) | < 2 seconds |
| CDN asset delivery | < 50ms |
| API p99 latency | < 500ms |
