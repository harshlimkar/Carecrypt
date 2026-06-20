"""
CareCrypt — FastAPI Backend
Endpoints for AI analysis, pharmacy QR verification, and audit logging.
The Flutter app works standalone with Supabase; this backend is optional
and provides server-side AI and additional security validation.

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import httpx

from config import Settings
from routers import ai_analysis, pharmacy, audit, auth

settings = Settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    print("🏥 CareCrypt Backend starting...")
    # Check Ollama availability at startup
    try:
        async with httpx.AsyncClient(timeout=3.0) as client:
            resp = await client.get(f"{settings.OLLAMA_BASE_URL}/api/tags")
            models = [m["name"] for m in resp.json().get("models", [])]
            print(f"✅ Ollama connected — models: {models}")
    except Exception:
        print("⚠️  Ollama not reachable — AI will use fallback safety scores")
    yield
    print("🔒 CareCrypt Backend shutting down...")


app = FastAPI(
    title="CareCrypt API",
    description=(
        "Enterprise healthcare cybersecurity platform backend.\n\n"
        "Features: AI drug safety analysis (Llama3), QR verification, "
        "honeypatient audit logging, pharmacy dispense management."
    ),
    version="1.0.0",
    contact={"name": "CareCrypt Security Team"},
    lifespan=lifespan,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

# ─── CORS ─────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Routers ──────────────────────────────────────────────
app.include_router(auth.router,        prefix="/api/auth",     tags=["Auth"])
app.include_router(ai_analysis.router, prefix="/api/ai",       tags=["AI Analysis"])
app.include_router(pharmacy.router,    prefix="/api/pharmacy", tags=["Pharmacy"])
app.include_router(audit.router,       prefix="/api/audit",    tags=["Audit & Security"])

# ─── Root ─────────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    return {
        "service": "CareCrypt API",
        "version": "1.0.0",
        "status": "operational",
        "tagline": "Your Health. Your Data. Your Control.",
        "endpoints": {
            "ai":       "/api/ai/analyze",
            "pharmacy": "/api/pharmacy/verify-qr",
            "audit":    "/api/audit/log",
            "docs":     "/docs",
        },
    }


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy", "service": "CareCrypt"}


# ─── Global error handler ─────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "error": str(exc)},
    )
