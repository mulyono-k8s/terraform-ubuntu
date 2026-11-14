
#!/usr/bin/env bash

set -Eeuo pipefail

ACTION="${1:-install}"

# ======================================
# INSTALL KIND AND KUBECTL
# ======================================

install_tools() {

  KUBERNETES_VERSION="${2:-v1.34.0}"

  echo "======================================"
  echo " INSTALLING KIND AND KUBECTL"
  echo "======================================"

  sudo apt-get update

  sudo apt-get install -y curl ca-certificates

  # ======================================
  # INSTALL KIND
  # ======================================

  echo "Installing Kind..."

  KIND_VERSION="$(curl -fsSL --retry 3 \
    https://api.github.com/repos/kubernetes-sigs/kind/releases/latest \
    | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p')"

  if [ -z "$KIND_VERSION" ]; then
    echo "ERROR: Cannot determine Kind version."
    exit 1
  fi

  echo "Detected Kind version: $KIND_VERSION"

  curl -fL --retry 3 \
    "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
    -o /tmp/kind

  chmod +x /tmp/kind

  sudo install -m 0755 /tmp/kind /usr/local/bin/kind

  rm -f /tmp/kind

  # ======================================
  # INSTALL KUBECTL
  # ======================================

  echo "Installing kubectl ${KUBERNETES_VERSION}..."

  curl -fL --retry 3 \
    "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl" \
    -o /tmp/kubectl

  curl -fL --retry 3 \
    "https://dl.k8s.io/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl.sha256" \
    -o /tmp/kubectl.sha256

  echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" \
    | sha256sum --check

  chmod +x /tmp/kubectl

  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

  rm -f /tmp/kubectl /tmp/kubectl.sha256

  # ======================================
  # VERIFY INSTALLATION
  # ======================================

  echo "======================================"
  echo " TOOLS INSTALLATION SUCCESS"
  echo "======================================"

  kind version

  kubectl version --client
}

# ======================================
# CREATE KUBERNETES CLUSTER
# ======================================

create_cluster() {

  if [ "$#" -ne 5 ]; then
    echo "ERROR: Invalid create parameters."
    echo "Usage: bash install-tools.sh create <name> <image> <workers> <kubeconfig>"
    exit 1
  fi

  CLUSTER_NAME="$2"
  NODE_IMAGE="$3"
  WORKER_COUNT="$4"
  KUBECONFIG_PATH="$5"

  # Validate worker count
  if ! [[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] \
    || [ "$WORKER_COUNT" -lt 1 ] \
    || [ "$WORKER_COUNT" -gt 5 ]; then
    echo "ERROR: Worker count must be between 1 and 5."
    exit 1
  fi

  echo "======================================"
  echo " CREATING KUBERNETES CLUSTER"
  echo "======================================"

  echo "Cluster name : $CLUSTER_NAME"
  echo "Node image   : $NODE_IMAGE"
  echo "Workers      : $WORKER_COUNT"

  # ======================================
  # CHECK DOCKER
  # ======================================

  echo "Checking Docker daemon..."

  sudo systemctl start docker

  if ! sudo docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is unavailable."
    exit 1
  fi

  echo "Docker daemon is running."

  # ======================================
  # CHECK EXISTING CLUSTER
  # ======================================

  if sg docker -c "kind get clusters" \
    | grep -Fxq "$CLUSTER_NAME"; then

    echo "Cluster '$CLUSTER_NAME' already exists."

    export KUBECONFIG="$KUBECONFIG_PATH"

    if [ ! -f "$KUBECONFIG_PATH" ]; then
      echo "Exporting kubeconfig..."

      sg docker -c "kind export kubeconfig \
        --name '$CLUSTER_NAME' \
        --kubeconfig '$KUBECONFIG_PATH'"
    fi

    kubectl get nodes -o wide

    return 0
  fi

  # ======================================
  # CREATE KIND CONFIG
  # ======================================

  KIND_CONFIG="$(mktemp)"

  trap 'rm -f "$KIND_CONFIG"' EXIT

  cat > "$KIND_CONFIG" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
  - role: control-plane
EOF

  for ((i=1; i<=WORKER_COUNT; i++)); do
    cat >> "$KIND_CONFIG" <<EOF
  - role: worker
EOF
  done

  mkdir -p "$(dirname "$KUBECONFIG_PATH")"

  # ======================================
  # CREATE CLUSTER
  # ======================================

  echo "Creating cluster: $CLUSTER_NAME"

  sg docker -c "kind create cluster \
    --name '$CLUSTER_NAME' \
    --image '$NODE_IMAGE' \
    --config '$KIND_CONFIG' \
    --kubeconfig '$KUBECONFIG_PATH' \
    --wait 5m"

  # ======================================
  # VERIFY CLUSTER
  # ======================================

  export KUBECONFIG="$KUBECONFIG_PATH"

  echo "======================================"
  echo " KUBERNETES CLUSTER CREATED"
  echo "======================================"

  kubectl get nodes -o wide

  kubectl get pods -A

  echo "Cluster creation completed successfully."
}

# ======================================
# EXECUTION
# ======================================

case "$ACTION" in

  install)
    install_tools "$@"
    ;;

  create)
    create_cluster "$@"
    ;;

  *)
    echo "Usage:"
    echo "  bash install-tools.sh install [version]"
    echo "  bash install-tools.sh create <name> <image> <workers> <kubeconfig>"
    exit 1
    ;;

esac
