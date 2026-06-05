FROM python:3.12-bookworm

# System dependencies
RUN apt-get update && apt-get install -y \
    curl unzip git zip sudo gnupg lsb-release wget \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Terraform 1.5.7 (pinnet versjon fra dotfile)
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip -o tf.zip \
    && unzip tf.zip -d /usr/local/bin \
    && rm tf.zip

# Terraform provider for OCI resource discovery (pinnet versjon fra dotfile)
RUN curl -fsSL https://releases.hashicorp.com/terraform-provider-oci/8.15.0/terraform-provider-oci_8.15.0_linux_amd64.zip -o tfprovider.zip \
    && unzip tfprovider.zip -d /tmp/tfprovider \
    && mv /tmp/tfprovider/terraform-provider-oci_v8.15.0 /usr/local/bin/ \
    && ln -s /usr/local/bin/terraform-provider-oci_v8.15.0 /usr/local/bin/terraform-provider-oci \
    && rm -rf tfprovider.zip /tmp/tfprovider

# kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# fn CLI
RUN curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh

# Python dependencies
RUN pip install --upgrade pip && pip install \
    oci \
    oracledb \
    python-dotenv \
    requests \
    PyYAML

# vscode user
RUN useradd -m -s /bin/bash vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# OCI CLI (kjøres som vscode siden den installerer til $HOME)
USER vscode
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" \
    -- --accept-all-defaults \
    && echo 'export PATH="$HOME/bin:$HOME/lib/oracle-cli:$PATH"' >> /home/vscode/.bashrc \
    && echo '' >> /home/vscode/.bashrc \
    && echo '# Custom prompt' >> /home/vscode/.bashrc \
    && echo 'unset color_prompt force_color_prompt' >> /home/vscode/.bashrc \
    && echo 'PS1="\[\e[34m\]\w\[\e[33m\]\$(git branch 2>/dev/null | grep '"'"'^*'"'"' | sed '"'"'s/* / (/'"'"' | sed '"'"'s/$/)'"'"')\[\e[0m\] \$ "' >> /home/vscode/.bashrc
WORKDIR /workspaces

