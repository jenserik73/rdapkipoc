# Diverse kommandoer

## Bruke Bastion som SSH forwarder og logge inn med proxycommand
ssh -i ~/.ssh/ssh-key.key \
  -o ProxyCommand="ssh -i ~/.ssh/ssh-key.key -W %h:%p -p 22 ocid1.bastionsession.oc19.eu-frankfurt-2.amaaaaaalgam66yaigwwdgq4w5ovacztr52ekal7wymkhlfkmgl5wanfql6q@host.bastion.eu-frankfurt-2.oci.oraclecloud.eu" \
  opc@10.0.4.35

