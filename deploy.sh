#!/usr/bin/env bash
set -euo pipefail

APP_NAME="demo"
REPO_URL="https://github.com/vlinglandy/demo-claw.git"
BRANCH="main"
REPO_DIR="/www/wwwroot/_repos/demo-claw"
WEBROOT="/www/wwwroot/demo"
PORT="3010"
PID_FILE="$WEBROOT/demo.pid"
LOG_FILE="$WEBROOT/demo.log"
BACKUP_DIR="/www/backup/deploy/$APP_NAME"

mkdir -p "$REPO_DIR" "$WEBROOT" "$BACKUP_DIR"

if [ ! -d "$REPO_DIR/.git" ]; then
  rm -rf "$REPO_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
else
  cd "$REPO_DIR"
  git fetch origin "$BRANCH"
  git reset --hard "origin/$BRANCH"
fi

stamp="$(date +%Y%m%d-%H%M%S)"
tar -czf "$BACKUP_DIR/$stamp.tar.gz" -C "$WEBROOT" . 2>/dev/null || true

rsync -a --delete \
  --exclude '.git' \
  --exclude 'node_modules' \
  --exclude 'demo.pid' \
  --exclude 'demo.log' \
  --exclude 'deploy.sh' \
  "$REPO_DIR/" "$WEBROOT/"

cat > "$WEBROOT/start-python.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
cd /www/wwwroot/demo
exec python3 -m http.server 3010
EOS
chmod +x "$WEBROOT/start-python.sh"

if [ -f "$PID_FILE" ]; then
  old_pid="$(cat "$PID_FILE" || true)"
  if [ -n "$old_pid" ]; then
    kill "$old_pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

nohup "$WEBROOT/start-python.sh" > "$LOG_FILE" 2>&1 & echo $! > "$PID_FILE"
sleep 1

curl -fsS --max-time 8 "http://127.0.0.1:$PORT/" >/dev/null

echo "Deploy success: $APP_NAME"
echo "Commit: $(cd "$REPO_DIR" && git rev-parse --short HEAD)"
echo "URL: http://127.0.0.1:$PORT/"
echo "Backup: $BACKUP_DIR/$stamp.tar.gz"
