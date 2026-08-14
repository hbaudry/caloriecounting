"""Page /setup : configuration simplifiée du mode abonnement (Agent SDK)."""

SETUP_PAGE = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Compteur de Calories — Configuration</title>
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         max-width: 640px; margin: 0 auto; padding: 24px 16px; line-height: 1.55; }
  h1 { font-size: 24px; } h2 { font-size: 17px; margin-top: 28px; }
  .card { border: 1px solid rgba(128,128,128,.35); border-radius: 12px; padding: 16px 18px; margin: 14px 0; }
  .ok { color: #1a9e46; font-weight: 600; } .off { color: #c33; font-weight: 600; }
  code { background: rgba(128,128,128,.15); padding: 2px 6px; border-radius: 6px; font-size: 14px; }
  ol { padding-left: 22px; } li { margin: 6px 0; }
  input { width: 100%; box-sizing: border-box; padding: 10px 12px; font-size: 15px;
          border: 1px solid rgba(128,128,128,.45); border-radius: 8px; font-family: ui-monospace, monospace; }
  button { padding: 10px 18px; font-size: 15px; border: none; border-radius: 8px; cursor: pointer;
           background: #0a84ff; color: #fff; font-weight: 600; margin-top: 10px; }
  button.danger { background: transparent; color: #c33; border: 1px solid #c33; margin-left: 8px; }
  #msg { margin-top: 10px; font-weight: 600; }
  .muted { color: rgba(128,128,128,.95); font-size: 14px; }
</style>
</head>
<body>
<h1>🍽️ Compteur de Calories — Configuration</h1>

<div class="card">
  <div>Mode d'analyse actif : <span id="provider">…</span></div>
  <div>Jeton d'abonnement : <span id="token-status">…</span></div>
</div>

<h2>Utiliser mon abonnement Claude (Pro / Max)</h2>
<p class="muted">L'analyse des photos est alors décomptée de ton abonnement, sans crédits API.</p>
<ol>
  <li>Sur ton ordinateur (où Claude Code est connecté), exécute&nbsp;: <code>claude setup-token</code></li>
  <li>Valide dans le navigateur — un jeton <code>sk-ant-oat01-…</code> s'affiche (valable 1 an)</li>
  <li>Colle-le ci-dessous et enregistre — pris en compte immédiatement, sans redémarrage</li>
</ol>

<input id="token" type="password" placeholder="sk-ant-oat01-…" autocomplete="off">
<div>
  <button onclick="saveToken()">Enregistrer le jeton</button>
  <button class="danger" id="clear-btn" onclick="clearToken()" hidden>Supprimer le jeton</button>
</div>
<div id="msg"></div>

<p class="muted" style="margin-top:26px">Le jeton est stocké dans le volume Docker
(<code>/data/config.json</code>, jamais renvoyé par l'API). Une variable d'environnement
<code>CLAUDE_CODE_OAUTH_TOKEN</code> ou <code>ANTHROPIC_API_KEY</code> définie au lancement
du conteneur reste prioritaire. Pense à protéger l'accès à cette page si le serveur est
exposé publiquement.</p>

<script>
async function refresh() {
  const r = await fetch("api/config");
  const c = await r.json();
  document.getElementById("provider").innerHTML = c.provider
    ? '<span class="ok">' + (c.provider === "subscription" ? "abonnement Claude" : "crédits API") + "</span>"
    : '<span class="off">non configuré</span>';
  document.getElementById("token-status").innerHTML = c.token_set
    ? '<span class="ok">enregistré</span> <span class="muted">(' + c.token_source + ")</span>"
    : '<span class="off">absent</span>';
  document.getElementById("clear-btn").hidden = !(c.token_set && c.token_source === "config");
}
async function saveToken() {
  const token = document.getElementById("token").value.trim();
  const msg = document.getElementById("msg");
  const r = await fetch("api/config/token", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token }),
  });
  if (r.ok) {
    msg.innerHTML = '<span class="ok">Jeton enregistré ✓</span>';
    document.getElementById("token").value = "";
  } else {
    const detail = (await r.json()).detail || "Erreur";
    msg.innerHTML = '<span class="off">' + detail + "</span>";
  }
  refresh();
}
async function clearToken() {
  await fetch("api/config/token", { method: "DELETE" });
  document.getElementById("msg").textContent = "";
  refresh();
}
refresh();
</script>
</body>
</html>"""
