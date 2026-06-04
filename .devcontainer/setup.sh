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

echo "=== Dev container setup complete ==="
