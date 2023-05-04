/******************************************
	PROXY
 *****************************************/

variable "proxy_env" {
  type = object({
    all_proxy:    optional(string)
    http_proxy:   optional(string)
    https_proxy:  optional(string)
    HTTP_PROXY:   optional(string)
    HTTPS_PROXY:  optional(string)
    no_proxy:     optional(string)
  })
  description = "HTTP/HTTPS proxy configuration."
  default = {
    all_proxy = ""
    http_proxy = ""
    https_proxy = ""
    HTTP_PROXY = ""
    HTTPS_PROXY = ""
    no_proxy = "127.0.0.1,0.0.0.0,localhost"
  }
}

/******************************************
	CA-CERTIFICATES
 *****************************************/

variable "k8s_custom_ca_anchors" {
  type = list(string)
  description = "Custom certificate authorities to deploy on k8s nodes."
}

/******************************************
	REGISTRIES
 *****************************************/

variable "k8s_custom_registries" {
  type = list(object({
    namespace       = string
    hosts           = list(string)
    capabilities    = list(string)
    ca              = optional(string)
    skip_verify     = optional(bool)
  }))
  description = "Custom container registries to deploy on k8s nodes."
}

/******************************************
	VAULT
 *****************************************/

variable "vault_address" {
  type = string
  description = "Origin URL of the Vault server."
}

variable "vault_namespace" {
  type = string
  description = "Set the namespace to use. Available only for Vault Enterprise."
  default = ""
}

variable "vault_kv" {
  type = string
  description = "Vault KV for credentials lookup."
}

variable "vault_kv_subpath" {
  type = string
  description = "Openstack environment categorization. Can be either (horsprod|prod|infra)."

  validation {
    condition     = can(contains(tolist(["horsprod", "prod", "infra"]), var.vault_kv_subpath))
    error_message = "The meta environment specified is not a valid."
  }
}

/******************************************
	OPENSTACK PROVIDER
 *****************************************/

variable "openstack_address" {
  type = string
  description = "Openstack API endpoint."

  # https://regex101.com/r/63KMg6/1
  validation {
    condition     = can(regex("^(https|http)+://(-\\.)?([^\\s/?\\.#-]+\\.?)+(/[^\\s]*)?$", var.openstack_address))
    error_message = "Invalid URL."
  }
}

variable "openstack_region" {
  type = string
  description = "Openstack region."
}

variable "openstack_tenant_id" {
  type = string
  description = "Openstack project identifier."

  # https://regex101.com/r/HUWyiK/1
  validation {
    condition     = can(regex("^[a-z0-9]{32}$", var.openstack_tenant_id))
    error_message = "Invalid Project Id."
  }
}

variable "openstack_user_domain_name" {
  type = string
  default = "Default"
}

variable "openstack_project_domain_name" {
  type = string
  default = "Default"
}

/******************************************
	S3 PROVIDER
 *****************************************/

variable "s3_endpoint" {
  type = string
  description = "AWS/S3 API endpoint."

  # https://regex101.com/r/63KMg6/1
  validation {
    condition     = can(regex("^(https|http)+://(-\\.)?([^\\s/?\\.#-]+\\.?)+(/[^\\s]*)?$", var.s3_endpoint))
    error_message = "Invalid URL."
  }
}

variable "s3_bucket" {
  type = string
}

variable "s3_access_key" {
  type = string
}

variable "s3_secret_key" {
  type = string
}

/******************************************
	K8S PROVISIONING
 *****************************************/

variable "k8s_cluster_initialized" {
  type = bool
  description = "Kubernetes initialization state. Useful for determining if the bootstrap node can be trashed for (okd|ocp)."
  default = false
}

variable "k8s_distribution" {
  type = string
  description = "Kubernetes distribution. Can be either (okd|ocp)."

  validation {
    condition     = can(contains(tolist(["okd", "ocp"]), var.k8s_distribution))
    error_message = "Unsupported Kubernetes distribution."
  }
}

variable "k8s_hosts_json" {
  type = string
  description = "All the K8S hosts in inventory and variables assigned to them as JSON string."
}

variable "k8s_groups_json" {
  type = string
  description = "All the K8S groups in inventory and each group has the list of hosts that belong to it as JSON string."
}

/******************************************
	DNS/Zones
 *****************************************/

variable "k8s_dns_zone" {
  type = string
  description = "DNS Zone of the instances."

  # https://regexr.com/3au3g
  # https://www.ietf.org/rfc/rfc1035.txt
  validation {
    condition     = can(regex("(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]", var.k8s_dns_zone))
    error_message = "DNS Zone is not RFC 1035 compliant."
  }
}

variable "k8s_dns_domains" {
  type = list(string)
  description = "DNS Domains for systemd-resolved."
}

variable "k8s_dns_servers" {
  type = list(string)
  description = "DNS Servers for systemd-resolved."
}

/******************************************
	Network/Networks
 *****************************************/

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_network_v2
variable "k8s_network_networks" {
  type = map(object({
    description = optional(string)
    tags = optional(list(string))
  }))
  description = "Cluster networks."
}

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_subnet_v2
variable "k8s_network_subnets_binding" {
  type = map(list(object({
    name = string
    cidr = optional(string)
    ip_version = optional(number)
  })))
  description = "Cluster subnets by network."
}

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/networking_secgroup_rule_v2
variable "k8s_network_secgroups_rulesets" {
  type = map(list(object({
    description = string
    direction = string
    ethertype = string
    protocol = optional(string)
    port_range_min = optional(number)
    port_range_max = optional(number)
    remote_ip_prefix = optional(string)
  })))
  description = "Network rules as security groups."
}

variable "k8s_ntp_servers" {
  type = list(string)
  description = "NTP Servers for clock synchronization."
}

# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_loadbalancer_v2
# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_listener_v2
# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_pool_v2
# https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs/resources/lb_members_v2
variable "k8s_network_loadbalancers" {
  type = list(object({
    name:         string
    description:  optional(string)
    dns:          string
    subnet:       string
    pools:        list(object({
      name:           string
      protocol:       string
      members:        list(object({
        group:            string
        protocol_port:    number
      }))
      healthmonitor:  object({
        name:             string
        type:             string
        url_path:         optional(string)
        http_method:      optional(string)
        delay:            number
        timeout:          number
        max_retries_down: number
        max_retries:      number
      })
      listener:       string
    }))
    listeners:    list(object({
      name:         string
      description:  optional(string)
      protocol:     string
      port:         number
    }))
  }))
  description = "Kubernetes Load Balancers."
}
