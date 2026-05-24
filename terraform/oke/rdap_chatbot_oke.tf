module "oke" {
  source  = "oracle-terraform-modules/oke/oci"
  version = "5.4.3"

  # general oci parameters
  tenancy_id = module.tenancy.tenancy_id
  compartment_id = module.tenancy.compartment_id
  timezone       = "Europe/Oslo"

  # networking
  create_vcn               = true
  assign_dns               = true
  lockdown_default_seclist = true
  vcn_cidrs                = ["10.0.0.0/16"]
  vcn_dns_label            = "oke"
  vcn_name                 = "oke_vcn"

  # Subnets
  subnets = {
    bastion  = { newbits = 13, netnum = 0,  display_name = "oke_bastion_sn", dns_label = "bastion",  create="always" }
    operator = { newbits = 13, netnum = 1,  display_name = "oke_operator_sn",dns_label = "operator", create="always" }
    cp       = { newbits = 13, netnum = 2,  display_name = "oke_cp_sn",      dns_label = "cp",       create="always" }
    int_lb   = { newbits = 11, netnum = 16, display_name = "oke_int_lb_sn",  dns_label = "ilb",      create="always" }
    pub_lb   = { newbits = 11, netnum = 17, display_name = "oke_pub_lb_sn",  dns_label = "plb",      create="always" }
    workers  = { newbits = 2,  netnum = 1,  display_name = "oke_worker_sn",  dns_label = "workers",  create="always" }
    pods     = { newbits = 2,  netnum = 2,  display_name = "oke_pods_sn",    dns_label = "pods",     create="always" }
  }

  # bastion
  create_bastion           = false
  bastion_allowed_cidrs    = ["0.0.0.0/0"]
  bastion_user             = "opc"

  # operator
  create_operator                = false
  operator_install_k9s           = false


  # iam
  create_iam_operator_policy   = "always"
  create_iam_resources         = true

  create_iam_tag_namespace = false // true/*false
  create_iam_defined_tags  = false // true/*false
  tag_namespace            = "oke"
  use_defined_tags         = false // true/*false

  # cluster
  create_cluster     = true
  cluster_type       = "basic"
  cluster_name       = "oke-dev"
  cni_type           = "flannel"
  kubernetes_version = "v1.34.2"
  pods_cidr          = "10.244.0.0/16"
  services_cidr      = "10.96.0.0/16"

  # Worker pool defaults
  worker_pool_size = 2
  worker_pool_mode = "node-pool"  # Node type
  worker_is_public = false  # Kubernetes worker nodes Private og Public

  # Worker defaults
  await_node_readiness     = "none"

  worker_pools = {
    np1 = {
      shape              = "VM.Standard3.Flex",
      ocpus              = 1,
      memory             = 16,
      size               = 1,
      boot_volume_size   = 50,
      kubernetes_version = "v1.34.2"
    }
  }

  # Security
  allow_node_port_access       = false
  allow_worker_internet_access = true
  allow_worker_ssh_access      = true
  control_plane_allowed_cidrs  = ["0.0.0.0/0"]
  control_plane_is_public      = true   # Kubernetes API endpoint is Public
  assign_public_ip_to_control_plane = true   # Has to be set to get a public ip for cp
  load_balancers               = "both"
  preferred_load_balancer      = "public"

  providers = {
    oci.home = oci
  }
}