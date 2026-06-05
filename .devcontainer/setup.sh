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
    mkdir -p $HOME/oracle_wallet
    echo "$RDAPKIPOCDB_WALLET" | base64 -d > $HOME/oracle_wallet/wallet_rdapkipocdb.zip
    unzip -o $HOME/oracle_wallet/wallet_rdapkipocdb.zip -d $HOME/oracle_wallet
    echo "✓ Wallet extracted OK"

    echo "=== Creating slim wallet for OCI Vault ==="
    cd $HOME/oracle_wallet
    zip wallet_rdapkipocdb_slim.zip ewallet.pem tnsnames.ora sqlnet.ora
    echo "✓ wallet_rdapkipocdb_slim.zip created"
    echo "   Size: $(du -sh wallet_rdapkipocdb_slim.zip | cut -f1)"
    echo "   Base64 size: $(base64 wallet_rdapkipocdb_slim.zip | wc -c) bytes"
    echo ""
    echo "--- Base64 encoded slim wallet (copy to OCI Vault secret) ---"
    base64 wallet_rdapkipocdb_slim.zip
    echo "--- End of base64 wallet ---"
    cd $HOME
else
    echo "WARNING: RDAPKIPOCDB_WALLET not set – skipping wallet setup"
fi

echo "=== Setting up terminal prompt ==="
{
    echo ''
    echo '# Custom prompt'
    echo 'unset color_prompt force_color_prompt'
    echo 'PS1="\[\e[34m\]\w\[\e[33m\]\$(git branch 2>/dev/null | grep '"'"'^*'"'"' | sed '"'"'s/* / (/'"'"' | sed '"'"'s/$/)'"'"')\[\e[0m\] \$ "'
} >> ~/.bashrc
echo "✓ PS1 prompt set"

echo "=== Dev container setup complete ==="
