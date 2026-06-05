#!/bin/bash
set -e

echo "=== Creating directory structure ==="
mkdir -p $HOME/.ssh
mkdir -p $HOME/.oci
mkdir -p $HOME/.aws
mkdir -p $HOME/temp
mkdir -p $HOME/resource-discovery
mkdir -p $HOME/oracle_wallet

echo "=== Writing OCI credentials ==="
if [ -n "$TENANT_PRIVATE_KEY" ]; then
    echo "$TENANT_PRIVATE_KEY" > $HOME/.ssh/tenant-private-key.pem
    chmod 600 $HOME/.ssh/tenant-private-key.pem
    echo "✓ tenant-private-key.pem"
else
    echo "WARNING: TENANT_PRIVATE_KEY not set"
fi

if [ -n "$TENANT_PUBLIC_KEY" ]; then
    echo "$TENANT_PUBLIC_KEY" > $HOME/.ssh/tenant-public-key.pem
    chmod 644 $HOME/.ssh/tenant-public-key.pem
    echo "✓ tenant-public-key.pem"
fi

if [ -n "$TENANT_CONFIG" ]; then
    echo "$TENANT_CONFIG" > $HOME/.oci/config
    chmod 600 $HOME/.oci/config
    echo "✓ .oci/config"
else
    echo "WARNING: TENANT_CONFIG not set"
fi

echo "=== Writing SSH instance keys ==="
if [ -n "$INSTANCE_PRIVATE_KEY" ]; then
    echo "$INSTANCE_PRIVATE_KEY" > $HOME/.ssh/ssh-key.key
    chmod 600 $HOME/.ssh/ssh-key.key
fi

if [ -n "$INSTANCE_PUBLIC_KEY" ]; then
    echo "$INSTANCE_PUBLIC_KEY" > $HOME/.ssh/ssh-key.key.pub
fi

echo "=== Writing AWS credentials ==="
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    printf "[default]\naws_access_key_id=%s\naws_secret_access_key=%s\n" \
        "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" > $HOME/.aws/credentials
    chmod 600 $HOME/.aws/credentials
    echo "✓ .aws/credentials"
else
    echo "WARNING: AWS credentials not set"
fi

echo "=== Setting up Oracle Wallet ==="
if [ -n "$RDAPKIPOCDB_WALLET" ]; then
    echo "$RDAPKIPOCDB_WALLET" | base64 -d > $HOME/oracle_wallet/wallet_rdapkipocdb.zip
    unzip -o $HOME/oracle_wallet/wallet_rdapkipocdb.zip -d $HOME/oracle_wallet
    echo "✓ Wallet extracted OK"
else
    echo "WARNING: RDAPKIPOCDB_WALLET not set – skipping wallet setup"
fi

echo "=== Dev container setup complete ==="
