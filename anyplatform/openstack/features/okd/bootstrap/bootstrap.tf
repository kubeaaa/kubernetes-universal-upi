resource "openstack_compute_instance_v2" "os_bootstrap_node" {

  depends_on = [
    data.ct_config.os_ignition_config,
  ]

  name        = lookup(var.os_bootstrap_node, "name")
  image_name  = lookup(var.os_bootstrap_node, "image_name")
  flavor_name = lookup(var.os_bootstrap_node, "flavor")

  # Ignition
  user_data = lookup(data.ct_config.os_ignition_config, "rendered")

  # Network
  network_mode = "none"

  lifecycle {
    ignore_changes = [
      image_name,
      user_data
    ]
  }
}
