FROM python:3.12-slim

WORKDIR /app

# Node.js + CLI Claude Code : requis uniquement pour le mode abonnement
# (Claude Agent SDK avec CLAUDE_CODE_OAUTH_TOKEN)
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm \
    && npm install -g @anthropic-ai/claude-code \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV CALORIE_CONFIG_PATH=/data/config.json
VOLUME /data

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
