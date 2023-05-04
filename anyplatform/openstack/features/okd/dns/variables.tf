/******************************************
	Cluster PROVISIONING
 *****************************************/

variable "os_dns_zone" {
  type = object({
    id = string
    name = string
  })
  description = "DNS Zone of the Openshift nodes."
}
