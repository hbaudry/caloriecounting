"""Configuration persistée (jeton d'abonnement Claude) dans /data/config.json.

Permet de configurer le jeton d'abonnement (Claude Agent SDK) depuis la page
/setup sans variable d'environnement ni redémarrage. Une variable
d'environnement explicite garde la priorité.

Miroir du mécanisme du projet `menu`.
"""

import json
import os
import stat

CONFIG_PATH = os.environ.get("CALORIE_CONFIG_PATH", "/data/config.json")
TOKEN_ENV = "CLAUDE_CODE_OAUTH_TOKEN"

_env_from_config = False


def _load() -> dict:
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {}


def _write(data: dict) -> None:
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f)
    os.chmod(CONFIG_PATH, stat.S_IRUSR | stat.S_IWUSR)  # secret : propriétaire seul


def apply_env() -> None:
    """Charge le jeton stocké dans l'environnement au démarrage (sans écraser une
    variable déjà définie)."""
    global _env_from_config
    if os.environ.get(TOKEN_ENV):
        return
    token = _load().get("claude_code_oauth_token")
    if token:
        os.environ[TOKEN_ENV] = token
        _env_from_config = True


def token_configured() -> bool:
    return bool(os.environ.get(TOKEN_ENV))


def token_source() -> str | None:
    if not token_configured():
        return None
    return "config" if _env_from_config else "environnement"


def save_token(token: str) -> None:
    global _env_from_config
    data = _load()
    data["claude_code_oauth_token"] = token
    _write(data)
    os.environ[TOKEN_ENV] = token
    _env_from_config = True


def clear_token() -> None:
    global _env_from_config
    data = _load()
    data.pop("claude_code_oauth_token", None)
    _write(data)
    if _env_from_config:
        os.environ.pop(TOKEN_ENV, None)
        _env_from_config = False
