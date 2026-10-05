# Deployment resources

This project is configured for a two-service deployment:

- Backend: FastAPI app in `backend/`
- Frontend: Next.js app in `frontend/`

## Local development

### Backend
```powershell
cd backend
$env:PYTHONPATH = "."
py -m uvicorn app.main:app --reload --port 8000
```

### Frontend
```powershell
cd frontend
npm install
npm run dev
```

## Docker deployment

From the project root:

```powershell
docker compose up --build
```

Then access:

- Frontend: http://localhost:3000
- Backend: http://localhost:8000/health

## Environment files

Copy the examples before deployment:

```powershell
copy backend\.env.example backend\.env
copy frontend\.env.example frontend\.env.local
```

## Deployment notes

- Keep secrets only in backend environment variables.
- Do not expose API keys in `NEXT_PUBLIC_*` variables.
- Use HTTPS and set `SESSION_COOKIE_SECURE=true` behind TLS.
- Configure `FRONTEND_ORIGINS` in the backend to include the deployed frontend origin.
- Ensure the backend can reach legal sources and any configured database/LLM endpoints.

## Suggested production setup

- Backend: Render / Railway / Fly.io / Docker container
- Frontend: Vercel / Netlify / Docker container
- Database: PostgreSQL if `DATABASE_URL` is enabled for saved report history
