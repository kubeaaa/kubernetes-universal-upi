/******************************************
	Cluster PROVISIONING
 *****************************************/

variable "k8s_tenant" {
  type = string
  description = "Kubernetes cluster tenant/identifier/name"
  validation {
    condition     = length(var.k8s_tenant) >= 3 && length(var.k8s_tenant) <= 253
    error_message = "Invalid cluster name."
  }
}

variable "k8s_hosts" {
  type = list(object({
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
  }))
  description = "List of openstack compute hosts."
}

variable "k8s_hosts_groups" {
  type = map(list(string))
  description = "List of openstack compute hosts by group."
}

/******************************************
	S3
 *****************************************/

variable "k8s_nodes_ignition_s3_endpoint" {
  type = string
  description = "AWS/S3 API endpoint."

  # https://regex101.com/r/63KMg6/1
  validation {
    condition     = can(regex("^(https|http)+://(-\\.)?([^\\s/?\\.#-]+\\.?)+(/[^\\s]*)?$", var.k8s_nodes_ignition_s3_endpoint))
    error_message = "Invalid URL."
  }
}

variable "k8s_nodes_ignition_s3_bucket" {
  type = string
  description = "S3 Bucket to store assets required for provisioning."
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
	Compute/Images
 *****************************************/

variable "k8s_images" {
  type = list(object({
    name = string
    properties = map(string)
    image_source_url = string
    container_format = string
    disk_format = string
  }))
  description = "Known K8S images sources."
  default = [
    {
      name = "fcos"
      properties = {
        release = "36.20221030.3.0"
        source  = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/36.20221030.3.0/x86_64/fedora-coreos-36.20221030.3.0-openstack.x86_64.qcow2.xz"
      }
      image_source_url = ""
      container_format = "bare"
      disk_format = "qcow2"
    },
    {
      name = "rhcos"
      properties = {
        release = "4.11.9"
        source = "https://mirror.openshift.com/pub/openshift-v4/x86_64/dependencies/rhcos/latest/rhcos-4.11.9-x86_64-openstack.x86_64.qcow2.gz"
      }
      image_source_url = ""
      container_format = "bare"
      disk_format = "qcow2"
    }
  ]
}

/******************************************
	Compute/Key Pair
 *****************************************/

variable "k8s_pubkey" {
  type = string
  description = "Trusted ECDSA Public Key."

  # https://regex101.com/r/vwsGeS/1
  validation {
    condition     = can(regex("^ecdsa-([a-z0-9-]*)\\s+[a-zA-Z0-9+\\/=]+\\s*(\\S*)$", var.k8s_pubkey))
    error_message = "Invalid public key."
  }
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

/******************************************
	NETWORK/LOAD BALANCERS
 *****************************************/

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

/******************************************
	NETWORK/MISC
 *****************************************/

variable "k8s_proxy" {
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

variable "k8s_ntp_servers" {
  type = list(string)
  description = "NTP Servers for clock synchronization."
}

/******************************************
	BUTANE/IGNITION
 *****************************************/

variable "k8s_compute_ignition_file" {
  type = object({
    path = optional(string)
  })
  description = "Additional ignition file for Kubernetes workers. Optional."
}

variable "k8s_controlplane_ignition_file" {
  type = object({
    path = optional(string)
  })
  description = "Additional ignition file for Kubernetes masters. Optional."
}