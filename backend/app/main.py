"""API d'analyse d'assiette (calories) — miroir de l'approche du projet `menu`.

Endpoints :
- GET    /health             — sonde de vie (+ mode actif)
- GET    /setup              — page web de configuration (jeton d'abonnement)
- GET    /api/config         — état de la configuration (jamais le secret)
- POST   /api/config/token   — enregistre le jeton d'abonnement (`claude setup-token`)
- DELETE /api/config/token   — supprime le jeton enregistré
- POST   /analyze            — analyse une photo d'assiette (multipart 'image')

Protection : mot de passe CALORIE_PASSWORD (Authorization: Bearer / X-API-Key /
Basic), sauf /health.
"""

import base64
import logging
import os
import secrets

import anthropic
from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

from . import config
from .analyzer import (
    AnalysisError,
    AnalysisRefusedError,
    analyze_image,
    resolve_provider,
)
from .setup_html import SETUP_PAGE

logger = logging.getLogger("calorie-api")

MAX_IMAGE_BYTES = 6 * 1024 * 1024

app = FastAPI(title="CalorieCounter API", version="1.0.0")
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


def _password_ok(request: Request, password: str) -> bool:
    candidates: list[str] = []
    if key := request.headers.get("x-api-key"):
        candidates.append(key)
    auth = request.headers.get("authorization", "")
    scheme, _, value = auth.partition(" ")
    if scheme.lower() == "bearer" and value:
        candidates.append(value.strip())
    elif scheme.lower() == "basic" and value:
        try:
            decoded = base64.b64decode(value.strip()).decode()
            candidates.append(decoded.partition(":")[2])
        except (ValueError, UnicodeDecodeError):
            pass
    return any(secrets.compare_digest(c, password) for c in candidates)


@app.middleware("http")
async def password_middleware(request: Request, call_next):
    password = os.environ.get("CALORIE_PASSWORD", "")
    if (
        not password
        or request.url.path == "/health"
        or request.method == "OPTIONS"
        or _password_ok(request, password)
    ):
        return await call_next(request)
    headers = {}
    if "text/html" in request.headers.get("accept", ""):
        headers["WWW-Authenticate"] = 'Basic realm="CalorieCounter API"'
    return JSONResponse(
        {"detail": "Mot de passe requis (Authorization: Bearer ou X-API-Key)."},
        status_code=401,
        headers=headers,
    )


@app.on_event("startup")
def startup() -> None:
    config.apply_env()
    if not os.environ.get("CALORIE_PASSWORD"):
        logger.warning("CALORIE_PASSWORD non défini : à définir avant toute exposition sur Internet.")


def _current_provider() -> str | None:
    try:
        return resolve_provider()
    except AnalysisError:
        return None


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "provider": _current_provider()}


@app.get("/setup", response_class=HTMLResponse, include_in_schema=False)
def setup_page() -> str:
    return SETUP_PAGE


class TokenPayload(BaseModel):
    token: str


@app.get("/api/config")
def get_config() -> dict:
    return {
        "provider": _current_provider(),
        "token_set": config.token_configured(),
        "token_source": config.token_source(),
    }


@app.post("/api/config/token", status_code=204)
def set_token(payload: TokenPayload) -> None:
    token = "".join(payload.token.split())
    if not token.startswith("sk-ant-oat"):
        raise HTTPException(
            status_code=422,
            detail="Jeton invalide : un jeton d'abonnement commence par sk-ant-oat "
            "(générer avec `claude setup-token`).",
        )
    config.save_token(token)
    logger.info("Jeton d'abonnement enregistré via /setup")


@app.delete("/api/config/token", status_code=204)
def delete_token() -> None:
    config.clear_token()


@app.post("/analyze")
async def analyze(image: UploadFile = File(...)):
    data = await image.read()
    if not data:
        raise HTTPException(status_code=400, detail="Image vide.")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image trop volumineuse (max 6 Mo).")

    media_type = image.content_type or "image/jpeg"
    if media_type not in ("image/jpeg", "image/png", "image/webp"):
        media_type = "image/jpeg"

    try:
        result = analyze_image(data, media_type)
    except AnalysisRefusedError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except anthropic.AuthenticationError:
        raise HTTPException(status_code=502, detail="Authentification Claude invalide côté serveur.")
    except anthropic.RateLimitError:
        raise HTTPException(status_code=429, detail="Trop de requêtes, réessayez dans un instant.")
    except anthropic.APIStatusError as exc:
        logger.exception("Erreur API Claude")
        raise HTTPException(status_code=502, detail=f"Erreur du service ({exc.status_code}).") from exc
    except AnalysisError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return JSONResponse(result)
