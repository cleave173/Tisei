# Tisei

Mobile language-learning app with a built-in multi-mode translator (text / voice / camera).

- **Frontend**: Flutter (Dart), Clean Architecture, Riverpod, go_router, easy_localization
- **Backend**: Python 3.12 + FastAPI + SQLAlchemy 2 (async) + Alembic
- **DB**: PostgreSQL 16
- **Translation**: LibreTranslate (self-hosted, open-source)
- **OCR**: Google ML Kit (on-device)
- **STT**: speech_to_text on-device + faster-whisper on backend (optional)
- **i18n**: English / Russian / Kazakh

## Repo layout

```
Tisei/
├── app/                # Flutter app (`com.tisei.app`)
│   ├── lib/
│   │   ├── core/       # config, network, theme, router, errors, widgets
│   │   ├── features/   # auth, learning, translator, profile, achievements, search, onboarding
│   │   └── l10n/
│   └── assets/
│       ├── images/  icons/  translations/{en,ru,kk}.json
├── backend/            # FastAPI service
│   ├── app/
│   │   ├── api/v1/endpoints/   auth, users, languages, lessons, translator
│   │   ├── core/   config.py
│   │   ├── db/     session.py (async engine + Base)
│   │   ├── models/         # SQLAlchemy models (Step 2)
│   │   ├── schemas/        # Pydantic schemas
│   │   └── seeds/          # CSV / JSON data for Oxford 3000 etc. (Step 2)
│   ├── alembic/
│   ├── scripts/
│   ├── Dockerfile
│   └── requirements.txt
├── infra/
│   ├── docker-compose.yml
│   └── .env.example
└── README.md
```

## Quick start

### 1. Backend stack (Postgres + FastAPI + LibreTranslate)

```bash
cp infra/.env.example infra/.env
docker compose -f infra/docker-compose.yml up --build
```

- API: http://localhost:8000/docs
- LibreTranslate: http://localhost:5000
- Postgres: `localhost:5432` (user/pass/db = `tisei`)

> First LibreTranslate boot downloads language packs (1–3 minutes).

### 2. Run Alembic migrations (after Step 2 lands models)

```bash
docker compose -f infra/docker-compose.yml exec backend alembic upgrade head
```

### 3. Seed English content (after Step 2)

```bash
docker compose -f infra/docker-compose.yml exec backend python -m scripts.seed_english
```

### 4. Flutter app

```bash
cd app
flutter pub get
# Android emulator (uses 10.0.2.2 to reach host)
flutter run
# To override API URL:
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000/api/v1 \
            --dart-define=LIBRETRANSLATE_URL=http://192.168.1.50:5000
```

## Roadmap

See `progress.txt` for the step-by-step plan.
