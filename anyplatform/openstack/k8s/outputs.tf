output "k8s_opk_images" {
  value = openstack_images_image_v2.opk_images
  description = "Provisioned K8S images on Openstack."
}

output "k8s_instances" {
  value = openstack_compute_instance_v2.k8s_compute_instances
  description = "Provisioned Compute instances on Openstack."
}

output "k8s_networks" {
  value = data.openstack_networking_network_v2.k8s_networks
  description = "Discovered Networks on Openstack."
}

output "k8s_subnets" {
  value = data.openstack_networking_subnet_v2.k8s_subnets
  description = "Discovered Subnets on Openstack."
}

output "k8s_ports" {
  value = openstack_networking_port_v2.k8s_networking_ports
  description = "Provisioned Interfaces for Compute instances on Openstack."
}

output "k8s_secgroups" {
  value = openstack_networking_secgroup_v2.k8s_secgroups
  description = "Provisioned Security groups on Openstack."
}

output "k8s_volumes" {
  value = openstack_blockstorage_volume_v3.k8s_volumes
  description = "Provisioned Volumes on Openstack."
}

output "k8s_dns_zones" {
  value = data.openstack_dns_zone_v2.k8s_zones
  description = "Discovered DNS Zones on Openstack."
}

output "k8s_nodes_a_recordset" {
  value = openstack_dns_recordset_v2.k8s_nodes_a_recordset
  description = "Provisioned DNS/A Records on Openstack."
}

output "k8s_keypair" {
  value = openstack_compute_keypair_v2.k8s_keypair
  description = "Provisioned SSH Key pair on Openstack."
}

output "k8s_ignition_configs" {
  value =  data.ct_config.k8s_ignition_configs
  description = "Generated Ignition configurations for Compute instances on Openstack."
}

output "k8s_lbs" {
  value = openstack_lb_loadbalancer_v2.k8s_loadbalancers
  description = "Provisioned Load Balancers on Openstack."
}

output "k8s_lbs_pools" {
  value = openstack_lb_pool_v2.k8s_loadbalancers_pools
  description = "Provisioned LBs Pools on Openstack."
}
