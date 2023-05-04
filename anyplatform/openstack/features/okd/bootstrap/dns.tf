resource "openstack_dns_recordset_v2" "os_bootstrap_node_a_recordset" {

  zone_id     = var.os_dns_zone.id
  name        = format("%s.", lookup(var.os_bootstrap_node, "host"))
  ttl         = 300
  type        = "A"

  # pick access ips from ports binding
  records     = [
    for binding in values(openstack_compute_interface_attach_v2.os_bootstrap_node_ports_binding): lookup(binding, "fixed_ip")
  ]
}
