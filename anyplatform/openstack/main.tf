/******************************************
	TF
 *****************************************/

terraform {
  backend "local" {
    path = "./terraform.tfstate"
  }

  required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "3.10.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.49.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

/******************************************
	PROVIDERS
 *****************************************/

provider "vault" {
  address           = var.vault_address
  namespace         = var.vault_namespace
  skip_child_token  = true
}

/******************************************
	SECRETS PROVISIONING
 *****************************************/

# Read KV
data "vault_generic_secret" "secret_openstack" {
  path = "${var.vault_kv}/${var.vault_kv_subpath}/${terraform.workspace}"
}

/******************************************
	COMPUTE INVENTORY
 *****************************************/

locals {
  # Unpack inventory from Ansible
  k8s_ansible_groups = jsondecode(var.k8s_groups_json)
  k8s_ansible_hosts = jsondecode(var.k8s_hosts_json)

  # Bind data structures to the host, by role
  # name=<tenant_name>-<host>
  cp_hosts = [
    for hostname, host in local.k8s_ansible_hosts : merge(
      host,
      { host = hostname },
      { name = format("%s-%s", terraform.workspace, element(split(".", hostname), 0)) },
    ) if contains(
      lookup(host, "group_names"),
      "cp"
    )
  ]
  compute_hosts = [
    for hostname, host in local.k8s_ansible_hosts : merge(
      host,
      { host = hostname },
      { name = format("%s-%s", terraform.workspace, element(split(".", hostname), 0)) },
    ) if contains(
      lookup(host, "group_names"),
      "compute"
    )
  ]
  bootstrap_host = element([
    for hostname, host in local.k8s_ansible_hosts : merge(
      host,
      { host = hostname },
      { name = format("%s-%s", terraform.workspace, element(split(".", hostname), 0)) },
    ) if contains(
      lookup(host, "group_names"),
      "bootstrap"
    )
  ], 0)

  # all in one structure
  /*
  [
      {
        "distribution" = "okd"
        "flavor" = "hp-big4.master.k8s.impair"
        "group_names" = [
          "cp",
          "k8s",
        ]
        "host" = "mst001.k8s.localdomain"
        "image_name" = "fcos"
        "name" = "training-mst001"
        "network_subnets" = tolist([
          "PFS-OPK-MGT-SUBNET",
        ])
        "platform" = "openstack"
        "proxy_env" = {}
        "security_groups" = tolist([
          "default",
        ])
        "storage" = tolist([
          {
            "name" = "log"
            "size" = 20
          },
        ])
      },
      ...
  ]
  */
  hosts = concat(local.cp_hosts, local.compute_hosts)

  /*
  all:
  - localhost
  - bootstrap.k8s.localdomain
  - mst001.k8s.localdomain
  - mst002.k8s.localdomain
  - mst003.k8s.localdomain
  - wrk001.k8s.localdomain
  - wrk002.k8s.localdomain
  - wrk003.k8s.localdomain
  - wrk004.k8s.localdomain
  - wrk005.k8s.localdomain
  bootstrap:
  - bootstrap.k8s.localdomain
  ...
  */
  groups = local.k8s_ansible_groups

  # Ignition files
  k8s_cp_ign_file        = format("%s/../../installer/master.ign", path.module)
  k8s_compute_ign_file   = format("%s/../../installer/worker.ign", path.module)
}

/******************************************
	GENERIC PROVISIONING
 *****************************************/

module "k8s" {
  source = "./k8s"

  # TF providers
  providers = {
    openstack = openstack.opk
    aws = aws.s3
  }

  # K8S definition
  k8s_tenant                        = terraform.workspace
  k8s_hosts                         = local.hosts
  k8s_hosts_groups                  = local.groups
  # S3 repository
  k8s_nodes_ignition_s3_endpoint    = var.s3_endpoint
  k8s_nodes_ignition_s3_bucket      = var.s3_bucket
  # K8S Key Pair
  k8s_pubkey                        = data.vault_generic_secret.secret_openstack.data["id_ecdsa.pub"]
  # DNS
  k8s_dns_zone                      = var.k8s_dns_zone
  k8s_dns_domains                   = var.k8s_dns_domains
  k8s_dns_servers                   = var.k8s_dns_servers
  # K8S networking
  k8s_network_networks              = var.k8s_network_networks
  k8s_network_subnets_binding       = var.k8s_network_subnets_binding
  k8s_network_secgroups_rulesets    = var.k8s_network_secgroups_rulesets
  k8s_network_loadbalancers         = var.k8s_network_loadbalancers
  # NTP
  k8s_ntp_servers                   = var.k8s_ntp_servers
  # Proxy
  k8s_proxy                         = var.proxy_env
  # CA certs
  k8s_custom_ca_anchors             = var.k8s_custom_ca_anchors
  k8s_custom_registries             = var.k8s_custom_registries
  # Optional Ignition files
  k8s_compute_ignition_file         = fileexists(local.k8s_compute_ign_file) ? {path: local.k8s_compute_ign_file} : {path: null}
  k8s_controlplane_ignition_file    = fileexists(local.k8s_cp_ign_file) ? {path: local.k8s_cp_ign_file} : {path: null}
}

/******************************************
	FEATURES/PROVISIONING
 *****************************************/

module "okd" {

  source = "./features/okd"

  depends_on = [
    module.k8s
  ]

  # Deploy conditionally based on Feature Flag variable
  count = var.k8s_distribution == "okd" ? 1 : 0

  # TF providers
  providers = {
    openstack = openstack.opk
    aws = aws.s3
  }

  # Openshift definition
  os_cluster_initialized            = var.k8s_cluster_initialized
  os_tenant                         = terraform.workspace
  os_dns_zone                       = module.k8s.k8s_dns_zones
  os_dns_domains                    = var.k8s_dns_domains
  os_dns_servers                    = var.k8s_dns_servers
  os_nodes                          = module.k8s.k8s_instances
  os_nodes_pools                    = module.k8s.k8s_lbs_pools
  os_bootstrap_ignition_s3_endpoint = var.s3_endpoint
  os_bootstrap_ignition_s3_bucket   = var.s3_bucket
  os_bootstrap_ignition_file        = format("%s/../../installer/bootstrap.ign", path.module)
  os_bootstrap_node                 = local.bootstrap_host
  os_keypair                        = format("%s-keypair", terraform.workspace)
  os_networks                       = module.k8s.k8s_networks
  os_secgroups                      = module.k8s.k8s_secgroups
  os_ntp_servers                    = var.k8s_ntp_servers
  os_proxy                          = var.proxy_env
  os_custom_ca_anchors              = var.k8s_custom_ca_anchors
  os_custom_registries              = var.k8s_custom_registries
}
