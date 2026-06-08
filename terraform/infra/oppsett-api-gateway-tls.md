# API Gateway + TLS-sertifikat oppsett - elcarocloud.no

## Oversikt

```
GoDaddy DNS (api.elcarocloud.no)
    └── A-record → 158.179.55.86
OCI API Gateway (rdap-chatbot-gw)
    ├── /v1/ask      → sql-executor (OCI Function)
    ├── /v1/feedback → sql-executor (OCI Function)
    └── TLS: Let's Encrypt via OCI Certificates
OCI Compute (certbot-instansen)
    └── certbot + certbot-dns-godaddy
```

---

## 1. Certbot-instans

OCI Compute-instans (`certbot`) i API Gateway-subnettet.

### Installasjon (Oracle Linux 9)

```bash
sudo dnf install -y python3-pip augeas-libs
sudo pip3 install certbot certbot-dns-godaddy
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

### OCI CLI

```bash
bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
source ~/.bashrc
```

### GoDaddy credentials

```bash
sudo mkdir -p /etc/letsencrypt/secrets
sudo tee /etc/letsencrypt/secrets/godaddy.ini << 'EOF'
dns_godaddy_key = <API_KEY>
dns_godaddy_secret = <API_SECRET>
EOF
sudo chmod 600 /etc/letsencrypt/secrets/godaddy.ini
```

GoDaddy API-nokler opprettes pa: https://developer.godaddy.com/keys (velg Production)

### Generer sertifikat

```bash
sudo /usr/local/bin/certbot certonly \
  --authenticator dns-godaddy \
  --dns-godaddy-credentials /etc/letsencrypt/secrets/godaddy.ini \
  --dns-godaddy-propagation-seconds 60 \
  -d "api.elcarocloud.no"
```

Sertifikatfiler lagres i `/etc/letsencrypt/live/api.elcarocloud.no/`.

---

## 2. Security List - apne port 443

Port 443 ma vaere apne i Security List for API Gateway-subnettet (`seclist-api-gateway`).
Legg til folgende ingress-regel i Terraform:

```hcl
ingress_security_rules {
  description = "Allow HTTPS traffic from anywhere"
  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  protocol    = "6"
  tcp_options {
    min = 443
    max = 443
  }
}
```

Kjoer `terraform apply` for at regelen skal tre i kraft.

---

## 3. IAM - Dynamic Group og Policy

Kjores fra Codespaces (ikke fra certbot-instansen).

### Dynamic Group

```bash
oci iam dynamic-group create \
  --name "certbot-dynamic-group" \
  --description "Dynamic Group for certbot-instansen" \
  --matching-rule "instance.id = '<CERTBOT_INSTANCE_OCID>'" \
  --compartment-id <TENANCY_OCID>
```

### Policy

```bash
oci iam policy create \
  --name "certbot-certificates-policy" \
  --description "Tillater certbot-instansen a administrere sertifikater" \
  --compartment-id <COMPARTMENT_OCID> \
  --statements '["allow dynamic-group certbot-dynamic-group to manage leaf-certificate-family in compartment id <COMPARTMENT_OCID>"]'
```

---

## 4. Importer sertifikat til OCI Certificates

Kjores fra certbot-instansen (krever Instance Principal).

### Forste gang (opprett)

```bash
oci certs-mgmt certificate create-by-importing-config \
  --auth instance_principal \
  --compartment-id <COMPARTMENT_OCID> \
  --name "api-elcarocloud-no" \
  --certificate-pem "$(sudo cat /etc/letsencrypt/live/api.elcarocloud.no/cert.pem)" \
  --cert-chain-pem "$(sudo cat /etc/letsencrypt/live/api.elcarocloud.no/chain.pem)" \
  --private-key-pem "$(sudo cat /etc/letsencrypt/live/api.elcarocloud.no/privkey.pem)"
```

Noter `id` fra output - dette er `CERTIFICATE_OCID`.

---

## 5. API Gateway - Terraform

Variabler som ma settes i `terraform.tfvars`:

```hcl
compartment_id    = "<COMPARTMENT_OCID>"
subnet_id         = "<PUBLIC_SUBNET_OCID>"
fn_application_id = "<FUNCTIONS_APPLICATION_OCID>"
certificate_id    = "<CERTIFICATE_OCID>"  # null forste deploy
```

### To-fase deploy

**Fase 1** - for sertifikat er klart:
- Sett `certificate_id = null` (eller kommenter ut linjen i `apigateway.tf`)
- Kjoer `terraform apply`
- Noter `gateway_hostname` fra output

**Fase 2** - etter sertifikat er importert:
- Uncomment `certificate_id = var.certificate_id` i `apigateway.tf`
- Fyll inn `certificate_id` i `terraform.tfvars`
- Kjoer `terraform apply` igjen

### DNS i GoDaddy

Opprett A-record:
- Type: `A`
- Name: `api`
- Value: `<gateway_hostname IP>`
- TTL: 600

---

## 6. Verifiser

```bash
# Test API
curl -X POST https://api.elcarocloud.no/v1/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}'

# Sjekk sertifikat
echo | openssl s_client -connect api.elcarocloud.no:443 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates
```

---

## 7. Sertifikatfornyelse (manuell)

Kjores pa certbot-instansen ca. en uke for utlop (hvert 90. dag).
Bruk scriptet `renew-cert.sh`:

```bash
chmod +x renew-cert.sh
./renew-cert.sh
```

Scriptet:
1. Fornyer sertifikatet via GoDaddy DNS
2. Importerer nytt sertifikat til OCI Certificates
3. Verifiserer at det nye sertifikatet er aktivt

---

## Ressurs-OCIDer

| Ressurs | OCID |
|---|---|
| Compartment | `ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq` |
| Tenancy | `ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a` |
| Certbot-instans | `ocid1.instance.oc19.eu-frankfurt-2.anzxiljrlgam66ycczrapys2e73ril7vheytbrkhqk3ap6msiietmrpvoz3a` |
| Certificate | `ocid1.certificate.oc19.eu-frankfurt-2.amaaaaaalgam66yamvkjdqgunpcxbjdw54wqfadcv7utxirulthahiremnda` |
| API Gateway | `ocid1.apigateway.oc19.eu-frankfurt-2.amaaaaaalgam66yaysj4a6pz4mx7pbgycpf55pd5qkldjaiq6h32eqtaho6q` |
| Dynamic Group | `ocid1.dynamicgroup.oc19..aaaaaaaahv76mt7gpvsenxlt7qwwuld5m6252kfahpxj4ivo4qzebmj2fdgq` |
