locals {
  # TODO: implement a better way to select controlplane related pools in order to attach the bootstrap node
  pools = {
    for pool in var.os_nodes_pools: pool.name => pool
      if contains(split("-", pool.name), "controlplane")
  }

  # bootstrap node ports
  ports = {
    for network in lookup(var.os_bootstrap_node, "networks"):
      format("%s_%s_IF", lookup(var.os_bootstrap_node, "name"), network) =>
      {
        dns_name        = lookup(var.os_bootstrap_node, "name")
        network         = network
        security_groups = [
          for secgroup in lookup(var.os_bootstrap_node, "security_groups"): secgroup
        ]
      }
  }
}

resource "openstack_networking_port_v2" "os_bootstrap_node_ports" {

  for_each = local.ports

  security_group_ids = [
    for secgroup in each.value["security_groups"]: lookup(var.os_secgroups, secgroup).id
  ]

  name              = each.key
  admin_state_up    = true
  dns_name          = each.value["dns_name"]
  network_id        = lookup(var.os_networks, each.value["network"]).id
}

resource "openstack_compute_interface_attach_v2" "os_bootstrap_node_ports_binding" {

  depends_on = [
    openstack_compute_instance_v2.os_bootstrap_node,
    openstack_networking_port_v2.os_bootstrap_node_ports
  ]

  for_each = local.ports

  instance_id = openstack_compute_instance_v2.os_bootstrap_node.id
  port_id     = lookup(openstack_networking_port_v2.os_bootstrap_node_ports, each.key).id
}

resource "openstack_lb_member_v2" "os_lb_bootstrap_member" {

  depends_on = [
    openstack_compute_interface_attach_v2.os_bootstrap_node_ports_binding
  ]

  for_each = local.pools

  pool_id       = lookup(var.os_nodes_pools, each.key).id
  name          = "bootstrap"
  # pick fist access ip from ports binding
  address       = lookup(
    element(
      values(openstack_compute_interface_attach_v2.os_bootstrap_node_ports_binding),
      0
    ),
    "fixed_ip"
  )
  protocol_port = contains(split("-", each.key), "apiserver") ? 6443 : 22623
}
