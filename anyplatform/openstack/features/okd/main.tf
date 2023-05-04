terraform {
  required_providers {
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
	FEATURES/PROVISIONING
 *****************************************/

module "bootstrap" {

  source = "./bootstrap"

  # setup bootstrap node if the cluster is not already up-and-running.
  count = var.os_cluster_initialized == false ? 1 : 0

  # TF providers
  providers = {
    openstack = openstack
    aws = aws
  }

  # Openshift definition
  os_tenant                         = var.os_tenant
  os_dns_zone                       = var.os_dns_zone
  os_dns_domains                    = var.os_dns_domains
  os_dns_servers                    = var.os_dns_servers
  os_nodes                          = var.os_nodes
  os_nodes_pools                    = var.os_nodes_pools
  os_bootstrap_ignition_s3_endpoint = var.os_bootstrap_ignition_s3_endpoint
  os_bootstrap_ignition_s3_bucket   = var.os_bootstrap_ignition_s3_bucket
  os_bootstrap_ignition_file        = var.os_bootstrap_ignition_file
  os_bootstrap_node                 = var.os_bootstrap_node
  os_keypair                        = var.os_keypair
  os_networks                       = var.os_networks
  os_secgroups                      = var.os_secgroups
  os_ntp_servers                    = var.os_ntp_servers
  os_proxy                          = var.os_proxy
  os_custom_ca_anchors              = var.os_custom_ca_anchors
  os_custom_registries              = var.os_custom_registries
}

module "dns" {

  source = "./dns"

  # TF providers
  providers = {
    openstack = openstack
  }

  # Openshift definition
  os_dns_zone                       = var.os_dns_zone
}
