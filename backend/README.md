# Backend d'analyse d'assiette (Claude vision)

Petit service HTTP qui reçoit une photo d'assiette et renvoie une estimation
nutritionnelle (JSON), en appelant **Claude en vision**. L'authentification reste
**côté serveur** (jamais dans l'app iOS).

Deux modes d'authentification, exactement comme le projet `menu` :

| Mode | Variable | Facturation |
|------|----------|-------------|
| **Abonnement** (recommandé) | `CLAUDE_CODE_OAUTH_TOKEN` | Décompté de votre abonnement Claude Pro/Max — **aucun crédit API** |
| **API** | `ANTHROPIC_API_KEY` | Crédits API (console.anthropic.com), facturation à l'usage |

Le mode est choisi par `CALORIE_PROVIDER` (`auto` par défaut : API si une clé est
présente, sinon abonnement).

## Mode abonnement (utiliser mon abonnement Claude)

Ce mode s'appuie sur le **Claude Agent SDK** et un jeton OAuth d'abonnement. Le
conteneur embarque Node.js et la CLI `@anthropic-ai/claude-code` (déjà dans le
`Dockerfile`).

1. Sur votre ordinateur (où Claude Code est connecté), générez un jeton :
   ```bash
   claude setup-token
   ```
   Un jeton `sk-ant-oat01-…` s'affiche (valable ~1 an).
2. Fournissez-le au serveur, au choix :
   - via la variable d'environnement `CLAUDE_CODE_OAUTH_TOKEN` (fichier `.env`), **ou**
   - via la page web **`/setup`** (collez le jeton — pris en compte immédiatement,
     stocké dans le volume `/data/config.json`, jamais renvoyé par l'API).

## Endpoints

- `GET /health` → `{"status":"ok","provider":"subscription|api|null"}` (non protégé)
- `GET /setup` → page web de configuration du jeton d'abonnement
- `GET /api/config` → état de la configuration (jamais le secret)
- `POST /api/config/token` → enregistre le jeton d'abonnement (`{"token":"sk-ant-oat01-…"}`)
- `DELETE /api/config/token` → supprime le jeton enregistré
- `POST /analyze` (multipart, champ `image`) → JSON :
  ```json
  {
    "dish_name": "Assiette de pâtes bolognaise",
    "items": [
      {"name": "Pâtes", "grams": 220, "calories": 290, "protein": 10, "carbs": 58, "fat": 2},
      {"name": "Sauce bolognaise", "grams": 120, "calories": 150, "protein": 9, "carbs": 6, "fat": 9}
    ],
    "total_calories": 440,
    "confidence": "medium",
    "notes": "Portions estimées d'après la taille de l'assiette."
  }
  ```

## Protection par mot de passe

Tout est protégé par `CALORIE_PASSWORD` **sauf `/health`**. Trois formes acceptées :

- `Authorization: Bearer <mot de passe>` — utilisé par l'app iOS
- `X-API-Key: <mot de passe>` — curl, scripts
- `Authorization: Basic <user:mot de passe>` — navigateur (`/setup`, `/docs`) ;
  l'identifiant est libre, seul le mot de passe compte.

> ⚠️ Si `CALORIE_PASSWORD` n'est pas défini, l'API **et** la page `/setup` sont
> accessibles sans mot de passe. Définissez-le impérativement avant toute
> exposition sur Internet.

## Lancer en local

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export CALORIE_PASSWORD=un-mot-de-passe
export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-...   # ou ANTHROPIC_API_KEY=sk-ant-...
uvicorn app.main:app --reload
```

> Le mode abonnement nécessite Node.js + `@anthropic-ai/claude-code`
> (`npm install -g @anthropic-ai/claude-code`) sur la machine. En Docker, c'est
> déjà installé.

## Déploiement Docker

```bash
cd backend
cp .env.example .env    # renseignez CALORIE_PASSWORD + le jeton/clé
docker compose up -d --build
```

Le service écoute sur `127.0.0.1:8000` (placez un reverse proxy TLS devant, ex.
Caddy, pour l'exposer publiquement). Le jeton d'abonnement configuré via `/setup`
persiste dans le volume `calorie-data`.

## Confidentialité

En mode backend, **la photo quitte l'appareil** : elle transite par votre serveur
puis par les serveurs d'Anthropic pour l'analyse. Sans backend configuré, l'app
reste 100 % hors-ligne (reconnaissance Vision sur l'appareil). Adaptez la politique
de confidentialité de l'app en conséquence.
