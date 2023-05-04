/******************************************
	Cluster PROVISIONING
 *****************************************/

variable "os_cluster_initialized" {
  type = bool
  description = "Openshift initialization state. Useful for determining if the bootstrap node can be trashed."
}

variable "os_tenant" {
  type = string
  description = "Openshift cluster tenant/identifier/name"
  validation {
    condition     = length(var.os_tenant) >= 3 && length(var.os_tenant) <= 253
    error_message = "Invalid cluster name."
  }
}

variable "os_dns_zone" {
  type = object({
    id = string
    name = string
  })
  description = "DNS Zone of the Openshift nodes."
}

variable "os_dns_domains" {
  type = list(string)
  description = "DNS Domains for systemd-resolved."
}

variable "os_dns_servers" {
  type = list(string)
  description = "DNS Servers for systemd-resolved."
}

variable "os_nodes" {
  type = map(object({
    id            = string
    name          = string
    access_ip_v4  = optional(string)
  }))
  description = "Map of openshift control plane and compute nodes."
}

variable "os_nodes_pools" {
  type = map(object({
    id            = string
    name          = string
  }))
  description = "Map of openshift load-balancers pools."
}

variable "os_bootstrap_ignition_s3_endpoint" {
  type = string
  description = "AWS/S3 API endpoint."

  # https://regex101.com/r/63KMg6/1
  validation {
    condition     = can(regex("^(https|http)+://(-\\.)?([^\\s/?\\.#-]+\\.?)+(/[^\\s]*)?$", var.os_bootstrap_ignition_s3_endpoint))
    error_message = "Invalid URL."
  }
}

variable "os_bootstrap_ignition_s3_bucket" {
  type = string
  description = "S3 Bucket to store 'bootstrap.ign' generated by openshift-install binary."
}

variable "os_bootstrap_ignition_file" {
  type = string
  description = "Path to 'bootstrap.ign' generated by openshift-install binary."

  validation {
    condition     = can(fileexists(var.os_bootstrap_ignition_file))
    error_message = "Ignition file not found for bootstrap node."
  }
}

variable "os_bootstrap_node" {
  type = object({
    distribution = string
    flavor = optional(string, "t4.large")
    group_names = list(string)
    host = string
    image_name = string
    name = string
    networks = list(string)
    platform = string
    proxy_env = object({
      http_proxy = string
      https_proxy = string
    })
    security_groups = list(string)
    storage = list(object({
      name = string
      mountpoint = string
      size = number
    }))
  })
  description = <<EOF
  Openshift bootstrap node. The bootstrap node is necessary to create the persistent control plane that is managed by
  the control plane nodes. After the initial minimum cluster with at least three control plane and two worker nodes is
  operational, you can remove the bootstrap node and convert it to a worker node if required.
  EOF
  validation {
    condition     = can(startswith(var.os_bootstrap_node.host, "bootstrap"))
    error_message = "Invalid bootstrap node not provided."
  }
}

variable "os_keypair" {
  type = string
  description = "Openshift unique name of the keypair used by instances."
}

variable "os_custom_ca_anchors" {
  type = list(string)
  description = "Custom certificate authorities to deploy on Openshift nodes."
}

variable "os_custom_registries" {
  type = list(object({
    namespace       = string
    hosts           = list(string)
    capabilities    = list(string)
    ca              = optional(string)
    skip_verify     = optional(bool)
  }))
  description = "Custom container registries to deploy on Openshift nodes."
}

variable "os_proxy" {
  type = object({
    all_proxy:    optional(string)
    http_proxy:   optional(string)
    https_proxy:  optional(string)
    HTTP_PROXY:   optional(string)
    HTTPS_PROXY:  optional(string)
    no_proxy:     optional(string)
  })
  description = "HTTP/HTTPS proxy configuration."
}

variable "os_ntp_servers" {
  type = list(string)
  description = "NTP Servers for clock synchronization."
}

variable "os_networks" {
  type = map(object({
    id = string
    name = string
  }))
  description = "Networks for Openshift."
}

variable "os_secgroups" {
  type = map(object({
    id = string
    name = string
  }))
  description = "Network Security Groups for Openshift."
}