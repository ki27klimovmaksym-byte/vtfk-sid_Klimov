#!/usr/bin/env bash
set -euo pipefail

IMAGE=ubuntu:24.04
OPEN=capsule-open
CLOSED=capsule-closed
HOST_PORT="${HOST_PORT:-8080}"
TOOLS="curl git procps iproute2 python3"

provision() {
  docker exec "$1" bash -c \
    "apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $TOOLS >/dev/null"
}

start_server() {
  docker exec -d "$1" python3 -m http.server 80
  for _ in $(seq 1 30); do
    if docker exec "$1" curl -fsS -o /dev/null http://localhost:80/ 2>/dev/null; then
      return 0
    fi
    sleep 0.5
  done
  echo "Сервер у $1 не піднявся" >&2
  return 1
}

docker rm -f "$OPEN" "$CLOSED" >/dev/null 2>&1 || true

echo "== Ізоляція процесів =="
docker run --rm "$IMAGE" bash -c \
  'echo "Контейнер: PID оболонки = $$, процесів = $(find /proc -maxdepth 1 -name "[0-9]*" | wc -l)"'
echo "Хост: процесів = $(find /proc -maxdepth 1 -name "[0-9]*" | wc -l)"

echo "== Контейнер БЕЗ -p =="
docker run -d --name "$CLOSED" "$IMAGE" sleep infinity >/dev/null
provision "$CLOSED"
start_server "$CLOSED"
code=0
curl -sS --max-time 3 -o /dev/null "http://localhost:$HOST_PORT/" 2>/dev/null || code=$?
if [ "$code" -eq 0 ]; then
  echo "Несподівано: localhost:$HOST_PORT відповів (порт зайнятий чимось іншим?)"
else
  echo "localhost:$HOST_PORT недоступний (curl код $code)"
fi
IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CLOSED")
curl -sS --max-time 3 -o /dev/null -w "Напряму за IP $IP: HTTP %{http_code}\n" "http://$IP/" \
  || echo "IP контейнера недосяжний з цього хоста"

echo "== Контейнер З -p $HOST_PORT:80 =="
docker run -d -p "$HOST_PORT:80" --name "$OPEN" "$IMAGE" sleep infinity >/dev/null
provision "$OPEN"
start_server "$OPEN"
curl -sS -o /dev/null -w "localhost:$HOST_PORT: HTTP %{http_code}\n" "http://localhost:$HOST_PORT/"
docker port "$OPEN"

echo "== Утиліти в $OPEN =="
docker exec "$OPEN" bash -c \
  'for t in curl git ps ip python3; do printf "%-8s" "$t"; command -v "$t"; done'

echo "Готово."
