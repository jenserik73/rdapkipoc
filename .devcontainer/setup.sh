#!/bin/bash
set -e

echo "=== Installing Python dependencies ==="
pip install --upgrade pip

pip install \
    oci \
    oracledb \
    python-dotenv \
    requests \
    PyYAML

echo "=== Setting up OCI config directory ==="
mkdir -p /home/vscode/.oci

echo "=== Setting up Oracle Wallet ==="
if [ -n "$RDAPKIPOCDB_WALLET" ]; then
    mkdir -p /home/vscode/oracle_wallet
    echo "$RDAPKIPOCDB_WALLET" | base64 -d > /home/vscode/oracle_wallet/wallet_rdapkipocdb.zip
    unzip -o /home/vscode/oracle_wallet/wallet_rdapkipocdb.zip -d /home/vscode/oracle_wallet
    echo "✓ Wallet extracted OK"
else
    echo "WARNING: RDAPKIPOCDB_WALLET not set – skipping wallet setup"
fi

echo "=== Install Docker CLI (not daemon - uses Codespaces host Docker socket) ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce-cli

echo "=== Dev container setup complete ==="
