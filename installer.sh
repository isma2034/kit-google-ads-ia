#!/usr/bin/env bash
# Installe le serveur MCP Google Ads officiel (googleads/google-ads-mcp), en lecture seule,
# avec une clé de compte de service, pour les assistants IA présents sur la machine :
# Claude Desktop, Cursor et Gemini CLI (configurés automatiquement), Claude Code et
# Codex CLI (commande affichée).
#
# Usage : bash installer.sh CHEMIN_VERS_CLE.json [--mcc 1234567890]

set -euo pipefail

SERVER_SPEC="google-ads-mcp==0.0.6"
PYTHON_VERSION="3.12"
SERVER_NAME="google-ads"
DEST_DIR="${HOME}/.config/google-ads-mcp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { printf '\n❌ %s\n' "$1" >&2; exit 1; }
info() { printf '%s\n' "$1"; }

usage() {
  cat <<'EOF'
Usage : bash installer.sh CHEMIN_VERS_CLE.json [--mcc 1234567890]

  CHEMIN_VERS_CLE.json  la clé JSON du compte de service (étape 3 du guide)
  --mcc 1234567890      identifiant du compte administrateur (MCC), si tu passes par un MCC
EOF
}

KEY_SRC=""
MCC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --mcc)
      [[ $# -ge 2 ]] || die "--mcc attend un identifiant, par exemple --mcc 1234567890"
      MCC="$2"; shift 2 ;;
    -*) die "Option inconnue : $1 (voir --help)" ;;
    *)
      [[ -z "$KEY_SRC" ]] || die "Un seul fichier de clé attendu."
      KEY_SRC="$1"; shift ;;
  esac
done

[[ -n "$KEY_SRC" ]] || { usage; exit 1; }
[[ -f "$KEY_SRC" ]] || die "Fichier introuvable : $KEY_SRC"
command -v python3 >/dev/null 2>&1 || die "python3 est introuvable (il sert seulement à lire les fichiers JSON)."

# 1. uvx
UVX="$(command -v uvx 2>/dev/null || true)"
if [[ -z "$UVX" ]]; then
  for candidate in "$HOME/.local/bin/uvx" "/opt/homebrew/bin/uvx" "/usr/local/bin/uvx"; do
    if [[ -x "$candidate" ]]; then UVX="$candidate"; break; fi
  done
fi
[[ -n "$UVX" ]] || die "uvx est introuvable. Installe uv (étape 5 du guide) :
   curl -LsSf https://astral.sh/uv/install.sh | sh
puis ferme et rouvre le Terminal."
info "✅ uvx trouvé : $UVX"

# 2. Lecture de la clé
KEY_INFO="$(python3 -I - "$KEY_SRC" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
except (OSError, ValueError) as exc:
    sys.exit(f"Le fichier n'est pas un JSON lisible : {exc}")
if data.get("type") != "service_account":
    sys.exit("Ce fichier n'est pas une clé de compte de service (champ \"type\" différent de \"service_account\").")
email, project = data.get("client_email"), data.get("project_id")
if not email or not project:
    sys.exit("La clé ne contient pas client_email ou project_id.")
print(f"{email}\t{project}")
PY
)" || die "Clé refusée."
SA_EMAIL="${KEY_INFO%%$'\t'*}"
PROJECT_ID="${KEY_INFO#*$'\t'}"
info "✅ Clé de compte de service : $SA_EMAIL (projet $PROJECT_ID)"

# 3. MCC
if [[ -n "$MCC" ]]; then
  MCC="${MCC//-/}"
  [[ "$MCC" =~ ^[0-9]{10}$ ]] || die "L'identifiant MCC doit faire 10 chiffres (ex. 123-456-7890)."
  info "✅ Compte administrateur (MCC) : $MCC"
fi

# 4. Copie de la clé et de la configuration lecture seule
mkdir -p "$DEST_DIR"
chmod 700 "$DEST_DIR"
KEY_DEST="$DEST_DIR/cle-compte-service.json"
TOOLS_DEST="$DEST_DIR/tools_config.yaml"

if [[ -f "$KEY_DEST" ]] && ! cmp -s "$KEY_SRC" "$KEY_DEST"; then
  read -r -p "Une autre clé existe déjà dans $DEST_DIR. La remplacer ? [o/N] " answer
  [[ "$answer" =~ ^[oOyY]$ ]] || die "Installation annulée, rien n'a été modifié."
fi
if [[ ! "$KEY_SRC" -ef "$KEY_DEST" ]]; then
  cp "$KEY_SRC" "$KEY_DEST"
fi
chmod 600 "$KEY_DEST"
cp "$SCRIPT_DIR/config/tools_config.yaml" "$TOOLS_DEST"
chmod 600 "$TOOLS_DEST"
info "✅ Clé et configuration lecture seule copiées dans $DEST_DIR"

# 5. Clients au format JSON « mcpServers » : Claude Desktop, Cursor, Gemini CLI
add_to_json_client() {
  local label="$1" config="$2"
  if [[ ! -d "$(dirname "$config")" ]]; then
    info "ℹ️  $label n'est pas installé ici : ignoré."
    return 0
  fi
  if [[ -f "$config" ]]; then
    local backup
    backup="$config.sauvegarde-$(date +%Y%m%d-%H%M%S)"
    cp "$config" "$backup"
  fi
  python3 -I - "$config" "$SERVER_NAME" "$UVX" "$PYTHON_VERSION" "$SERVER_SPEC" \
    "$KEY_DEST" "$PROJECT_ID" "$TOOLS_DEST" "$MCC" "$label" <<'PY' || { info "⚠️  $label : configuration illisible, laissée telle quelle. Ajoute le serveur à la main (voir le guide)."; return 0; }
import json, os, sys
cfg_path, name, uvx, py, spec, key, project, tools, mcc, label = sys.argv[1:11]
config = {}
if os.path.exists(cfg_path) and os.path.getsize(cfg_path) > 0:
    try:
        with open(cfg_path, encoding="utf-8") as f:
            config = json.load(f)
    except (OSError, ValueError):
        sys.exit(1)
if not isinstance(config, dict) or not isinstance(config.get("mcpServers", {}), dict):
    sys.exit(1)
servers = config.setdefault("mcpServers", {})
replaced = name in servers
env = {
    "GOOGLE_APPLICATION_CREDENTIALS": key,
    "GOOGLE_CLOUD_PROJECT": project,
    "GOOGLE_ADS_MCP_TOOLS_CONFIG": tools,
}
if mcc:
    env["GOOGLE_ADS_LOGIN_CUSTOMER_ID"] = mcc
servers[name] = {
    "command": uvx,
    "args": ["--python", py, "--from", spec, "google-ads-mcp"],
    "env": env,
}
tmp = cfg_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, cfg_path)
print(("🔁 %s : entrée « %s » remplacée" if replaced else "✅ %s : serveur « %s » ajouté") % (label, name))
PY
  [[ -n "${backup:-}" ]] && info "   (ancienne configuration sauvegardée : $backup)"
  return 0
}

case "$(uname -s)" in
  Darwin) DESKTOP_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
  *)      DESKTOP_CONFIG="$HOME/.config/Claude/claude_desktop_config.json" ;;
esac
desktop_running() { ps -axo comm 2>/dev/null | grep -q "Claude.app/Contents/MacOS/Claude$"; }

# Claude Desktop réécrit son fichier de configuration quand il tourne : une modification
# faite pendant qu'il est ouvert est perdue au redémarrage. On attend qu'il soit fermé.
if [[ "$(uname -s)" == "Darwin" ]] && desktop_running; then
  info ""
  info "⚠️  Claude Desktop est ouvert. Il écraserait la configuration en se fermant."
  info "   Quitte-le complètement (Cmd+Q), puis appuie sur Entrée pour continuer."
  info "   (Ou tape « passer » pour ne pas configurer Claude Desktop.)"
  read -r desktop_answer
  if [[ "$desktop_answer" == "passer" ]]; then
    SKIP_DESKTOP=1
  elif desktop_running; then
    info "ℹ️  Claude Desktop est toujours ouvert : configuration de Claude Desktop ignorée."
    info "   Relance ce script une fois Claude Desktop fermé."
    SKIP_DESKTOP=1
  fi
fi
if [[ "${SKIP_DESKTOP:-0}" != "1" ]]; then
  add_to_json_client "Claude Desktop" "$DESKTOP_CONFIG"
fi
add_to_json_client "Cursor" "$HOME/.cursor/mcp.json"
add_to_json_client "Gemini CLI" "$HOME/.gemini/settings.json"

# 6. Clients configurés en ligne de commande : Claude Code, Codex CLI
ENV_FLAGS_CLAUDE="-e GOOGLE_APPLICATION_CREDENTIALS=\"$KEY_DEST\" \\
  -e GOOGLE_CLOUD_PROJECT=\"$PROJECT_ID\" \\
  -e GOOGLE_ADS_MCP_TOOLS_CONFIG=\"$TOOLS_DEST\""
ENV_FLAGS_CODEX="--env GOOGLE_APPLICATION_CREDENTIALS=\"$KEY_DEST\" \\
  --env GOOGLE_CLOUD_PROJECT=\"$PROJECT_ID\" \\
  --env GOOGLE_ADS_MCP_TOOLS_CONFIG=\"$TOOLS_DEST\""
if [[ -n "$MCC" ]]; then
  ENV_FLAGS_CLAUDE+=" -e GOOGLE_ADS_LOGIN_CUSTOMER_ID=$MCC"
  ENV_FLAGS_CODEX+=" --env GOOGLE_ADS_LOGIN_CUSTOMER_ID=$MCC"
fi
SERVER_CMD="\"$UVX\" --python $PYTHON_VERSION --from $SERVER_SPEC google-ads-mcp"

cat <<EOF

────────────────────────────────────────────────────────────
Si tu utilises Claude Code, lance (une seule fois) :

claude mcp add $SERVER_NAME --scope user \\
  $ENV_FLAGS_CLAUDE \\
  -- $SERVER_CMD

Si tu utilises Codex CLI (OpenAI), lance (une seule fois) :

codex mcp add $SERVER_NAME \\
  $ENV_FLAGS_CODEX \\
  -- $SERVER_CMD

ChatGPT (application ou web) ne lance pas de serveur local : il faut héberger le serveur
(voir « Aller plus loin » dans le guide).
────────────────────────────────────────────────────────────
Il te reste à faire, si ce n'est pas déjà fait :

1. Ajouter cette adresse dans Google Ads (Administration → Accès et sécurité →
   Utilisateurs → +), niveau « Lecture seule » :

     $SA_EMAIL

2. Demander l'accès Explorer pour le projet $PROJECT_ID :

     https://console.cloud.google.com/google/ads-apis/overview?project=$PROJECT_ID

3. Redémarrer complètement ton assistant (Quitter, pas seulement fermer la fenêtre), puis
   demander : « À quels comptes Google Ads ai-je accès ? »

Tu peux supprimer le fichier de clé téléchargé : une copie protégée est dans
$DEST_DIR
EOF
