locals {
  # DNS A recordset structure
  # For each host, collect all IPs on all interfaces
  /*
  mst001.k8s.localdomain.:
    records:
    - 10.206.212.32
    zone_name: trainingk8s.k8s.localdomain.
  ...
  */
  dns_a_recordset = merge({
    for host in var.k8s_hosts:
      format("%s.", lookup(host, "host")) => {
        zone_name = var.k8s_dns_zone
        records = [
          for ifattach in openstack_compute_interface_attach_v2.k8s_ports_binding: ifattach["fixed_ip"]
          if ifattach["instance_id"] == lookup(openstack_compute_instance_v2.k8s_compute_instances, lookup(host, "host")).id
        ]
      }
  }, {
    for lb_name,lb in local.lbs:
      lookup(lb, "dns") => {
        zone_name = var.k8s_dns_zone
        records = [
          lookup(openstack_lb_loadbalancer_v2.k8s_loadbalancers, lb_name).vip_address
        ]
      }
  })
}

# Delegated Zone
data "openstack_dns_zone_v2" "k8s_zones" {
  name = var.k8s_dns_zone
}

/*
mst1.k8s.localdomain.:
  id: d2747b7f-eef8-4bc1-926a-8fc1b3ab5069/ba009194-9edb-471c-908e-94d3f113e839
  name: mst1.k8s.localdomain.
  records:
  - 10.206.211.174
  region: CNP-HP-PFS
  ttl: 300
  type: A
...
*/
resource "openstack_dns_recordset_v2" "k8s_nodes_a_recordset" {

  for_each = local.dns_a_recordset

  zone_id     = data.openstack_dns_zone_v2.k8s_zones.id
  name        = each.key
  ttl         = 300
  type        = "A"
  records     = each.value["records"]
}
