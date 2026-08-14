"""Analyse d'une photo d'assiette via Claude (vision).

Deux modes d'authentification (comme le projet `menu`), choisis par
CALORIE_PROVIDER (défaut "auto") :

- "api"          — API Messages avec ANTHROPIC_API_KEY (crédits API,
                   sortie contrainte par schéma).
- "subscription" — Claude Agent SDK avec CLAUDE_CODE_OAUTH_TOKEN
                   (décompté de l'abonnement Claude Pro/Max ;
                   jeton obtenu via `claude setup-token`).
"""

import base64
import json
import os
import re

import anthropic
import anyio

MODEL = os.environ.get("CALORIE_MODEL", "claude-sonnet-5")
SDK_MODEL = os.environ.get("CALORIE_SDK_MODEL", "sonnet")
EFFORT = os.environ.get("CALORIE_EFFORT", "low")

SYSTEM_PROMPT = (
    "Tu es un nutritionniste expert. À partir d'une photo d'assiette, identifie "
    "chaque aliment visible, estime sa quantité en grammes, puis ses calories et "
    "macronutriments (protéines, glucides, lipides) POUR CETTE PORTION. Base-toi sur "
    "les repères visuels (taille de l'assiette, des couverts). Sois réaliste : ce sont "
    "des estimations. Réponds en français. 'confidence' vaut low, medium ou high ; "
    "'notes' contient une courte remarque utile (hypothèses de portion)."
)

USER_TEXT = (
    "Analyse cette assiette : liste chaque aliment avec sa quantité (grammes), ses "
    "calories et macros pour la portion, puis le total."
)

SCHEMA = {
    "type": "object",
    "properties": {
        "dish_name": {"type": "string"},
        "items": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "grams": {"type": "number"},
                    "calories": {"type": "number"},
                    "protein": {"type": "number"},
                    "carbs": {"type": "number"},
                    "fat": {"type": "number"},
                },
                "required": ["name", "grams", "calories", "protein", "carbs", "fat"],
                "additionalProperties": False,
            },
        },
        "total_calories": {"type": "number"},
        "confidence": {"type": "string", "enum": ["low", "medium", "high"]},
        "notes": {"type": "string"},
    },
    "required": ["dish_name", "items", "total_calories", "confidence", "notes"],
    "additionalProperties": False,
}


class AnalysisRefusedError(Exception):
    """L'analyse a été refusée par le modèle."""


class AnalysisError(Exception):
    """Erreur de configuration ou d'exécution du fournisseur."""


def resolve_provider() -> str:
    provider = os.environ.get("CALORIE_PROVIDER", "auto").lower()
    if provider in ("api", "subscription"):
        return provider
    if provider != "auto":
        raise AnalysisError(f"CALORIE_PROVIDER invalide : {provider!r} (auto, api ou subscription).")
    if os.environ.get("ANTHROPIC_API_KEY"):
        return "api"
    if os.environ.get("CLAUDE_CODE_OAUTH_TOKEN"):
        return "subscription"
    raise AnalysisError(
        "Aucune authentification configurée : définir ANTHROPIC_API_KEY (crédits API) "
        "ou CLAUDE_CODE_OAUTH_TOKEN (abonnement Claude, via `claude setup-token`)."
    )


def analyze_image(image_bytes: bytes, media_type: str) -> dict:
    if resolve_provider() == "subscription":
        return _sdk_vision(image_bytes, media_type)
    return _api_vision(image_bytes, media_type)


# ---- Mode "api" — API Messages, sortie contrainte par schéma ----

def _api_vision(image_bytes: bytes, media_type: str) -> dict:
    client = anthropic.Anthropic()
    b64 = base64.standard_b64encode(image_bytes).decode("utf-8")
    is_opus = "opus" in MODEL or "fable" in MODEL
    betas: list[str] = []
    kwargs: dict = {}
    if is_opus:
        betas.append("server-side-fallback-2026-07-01")
        kwargs["fallbacks"] = "default"

    response = client.beta.messages.create(
        model=MODEL,
        max_tokens=3000,
        betas=betas or None,
        system=SYSTEM_PROMPT,
        output_config={"format": {"type": "json_schema", "schema": SCHEMA}, "effort": EFFORT},
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}},
                    {"type": "text", "text": USER_TEXT},
                ],
            }
        ],
        **kwargs,
    )
    if response.stop_reason == "refusal":
        raise AnalysisRefusedError("L'analyse a été refusée par le modèle.")
    text = next(b.text for b in response.content if b.type == "text")
    return json.loads(text)


# ---- Mode "subscription" — Claude Agent SDK, décompté de l'abonnement ----

def _sdk_vision(image_bytes: bytes, media_type: str) -> dict:
    json_prompt = (
        f"{USER_TEXT}\n\n"
        "Réponds UNIQUEMENT avec un objet JSON valide conforme au schéma suivant, "
        "sans aucun texte autour et sans balises markdown :\n"
        f"{json.dumps(SCHEMA, ensure_ascii=False)}"
    )
    last_error: Exception | None = None
    for _ in range(2):
        text = anyio.run(_run_sdk_query, json_prompt, image_bytes, media_type)
        try:
            return json.loads(_extract_json(text))
        except (ValueError, KeyError) as exc:
            last_error = exc
    raise AnalysisError(f"Le modèle n'a pas renvoyé un JSON valide (mode abonnement) : {last_error}")


async def _run_sdk_query(prompt: str, image_bytes: bytes, media_type: str) -> str:
    try:
        from claude_agent_sdk import ClaudeAgentOptions, ResultMessage, query
    except ImportError as exc:
        raise AnalysisError(
            "Le paquet claude-agent-sdk n'est pas installé (requis pour le mode abonnement)."
        ) from exc

    if not os.environ.get("CLAUDE_CODE_OAUTH_TOKEN") and not os.environ.get("ANTHROPIC_API_KEY"):
        raise AnalysisError(
            "CLAUDE_CODE_OAUTH_TOKEN absent : générer un jeton avec `claude setup-token`."
        )

    b64 = base64.standard_b64encode(image_bytes).decode("utf-8")
    options = ClaudeAgentOptions(system_prompt=SYSTEM_PROMPT, model=SDK_MODEL, max_turns=1, allowed_tools=[])

    async def message_stream():
        # Entrée en streaming : un message utilisateur avec texte + image.
        yield {
            "type": "user",
            "message": {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": b64}},
                ],
            },
        }

    result_text: str | None = None
    fallback_chunks: list[str] = []
    try:
        async for message in query(prompt=message_stream(), options=options):
            if isinstance(message, ResultMessage):
                if message.is_error:
                    raise AnalysisError(f"Claude Agent SDK a signalé une erreur : {message.result or 'inconnue'}")
                result_text = message.result
            else:
                for block in getattr(message, "content", []) or []:
                    text = getattr(block, "text", None)
                    if text:
                        fallback_chunks.append(text)
    except AnalysisError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise AnalysisError(f"Échec de l'analyse via le Claude Agent SDK : {exc}") from exc

    text = result_text or "".join(fallback_chunks)
    if not text:
        raise AnalysisError("Le Claude Agent SDK n'a renvoyé aucun contenu.")
    return text


def _extract_json(text: str) -> str:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end <= start:
        raise ValueError("aucun objet JSON dans la réponse")
    return text[start : end + 1]
