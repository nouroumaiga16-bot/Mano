#!/usr/bin/env bash
# Fabrique la version web de Mano (pour tester sur iPhone) dans build/web.
# Usage : tool/build_web.sh [chemin de base, par défaut /mano/]
set -euo pipefail
cd "$(dirname "$0")/.."
BASE_HREF="${1:-/mano/}"

VERSION=$(date +%Y%m%d%H%M%S)
flutter build web --release --no-web-resources-cdn --base-href "$BASE_HREF" \
  --dart-define=APP_VERSION="$VERSION"

cd build/web
# Le service worker fourni par Flutter se désinstalle tout seul : on le retire.
rm -f flutter_service_worker.js
find . -name '*.symbols' -delete

# Liste des fichiers à garder hors ligne (sans les variantes Chrome/Skwasm,
# non utilisées par Safari ; elles seront mises en mémoire au besoin).
PRECACHE=$(find . -type f \
  ! -name offline_sw.js ! -name '.*' \
  ! -path './canvaskit/chromium/*' ! -path './canvaskit/skwasm*' \
  ! -path './canvaskit/wimp*' ! -path './canvaskit/webparagraph/*' \
  | sed 's|^\./||' | sort | python3 -c 'import json,sys; print(json.dumps(["./"] + sys.stdin.read().split()))')
python3 - "$VERSION" "$PRECACHE" <<'PY'
import sys
version, precache = sys.argv[1], sys.argv[2]
path = 'offline_sw.js'
src = open(path).read()
src = src.replace('__CACHE_VERSION__', version).replace('__PRECACHE__', precache)
open(path, 'w').write(src)
PY
echo "Version web $VERSION prête dans build/web"
