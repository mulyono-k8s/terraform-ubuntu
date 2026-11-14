
#!/usr/bin/env bash

set -Eeuo pipefail

echo "======================================"
echo " INSTALL DOCKER ENGINE ON WSL2"
echo "======================================"

# Check Ubuntu
if ! grep -qi ubuntu /etc/os-release; then
  echo "ERROR: This script requires Ubuntu."
  exit 1
fi

# Check systemd
if [ "$(ps -p 1 -o comm= | tr -d ' ')" != "systemd" ]; then
  echo "ERROR: systemd is not running."
  echo "Enable systemd in /etc/wsl.conf and restart WSL."
  exit 1
fi

echo "[1/6] Updating packages..."

sudo apt-get update

echo "[2/6] Installing prerequisites..."

sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  login

echo "[3/6] Adding Docker repository..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update

echo "[4/6] Installing Docker Engine..."

sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[5/6] Enabling Docker daemon..."

sudo systemctl enable docker
sudo systemctl restart containerd
sudo systemctl restart docker

echo "[6/6] Configuring Docker group..."

sudo groupadd -f docker

sudo usermod -aG docker "$USER"

echo "Waiting for Docker daemon..."

for i in $(seq 1 30); do
  if sudo docker info >/dev/null 2>&1; then
    break
  fi

  sleep 2
done

if ! sudo docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon failed to start."
  exit 1
fi

echo "======================================"
echo " DOCKER INSTALLATION SUCCESS"
echo "======================================"

sudo docker version
sudo systemctl status docker --no-pager
