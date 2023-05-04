locals {
  # Inventory Images
  images = toset(distinct([
    for instance in var.k8s_hosts: lookup(instance, "image_name")
  ]))
  # Attended Images
  opk_images = matchkeys(
    var.k8s_images, [for img in var.k8s_images: lookup(img, "name")], local.images
  )
  # ssh key pair name
  key_pair = format("%s-keypair", var.k8s_tenant)
}

/******************************************
	COMPUTE/IMAGES
 *****************************************/

resource "openstack_images_image_v2" "opk_images" {

  for_each = {
    for img in local.opk_images: lookup(img, "name") => img
  }

  name             = each.key
  image_source_url = each.value["image_source_url"]
  container_format = each.value["container_format"]
  disk_format      = each.value["disk_format"]
  verify_checksum  = true

  properties       = each.value["properties"]
}

/******************************************
	COMPUTE/INSTANCES
 *****************************************/

resource "openstack_compute_instance_v2" "k8s_compute_instances" {

  depends_on = [
    data.ct_config.k8s_ignition_configs,
    openstack_compute_keypair_v2.k8s_keypair,
    openstack_images_image_v2.opk_images,
  ]

  for_each = {
    for instance in var.k8s_hosts: lookup(instance, "host") => instance
  }

  name        = each.value["name"]
  image_name  = each.value["image_name"]
  flavor_name = each.value["flavor"]

  key_pair    = local.key_pair

  # Ignition
  user_data = lookup(data.ct_config.k8s_ignition_configs, each.value["host"]).rendered

  network_mode = "none"

  lifecycle {
    ignore_changes = [
      image_name,
      user_data
    ]
  }
}

/******************************************
	COMPUTE/KEY PAIRS
 *****************************************/

resource "openstack_compute_keypair_v2" "k8s_keypair" {

  name       = local.key_pair
  public_key = var.k8s_pubkey
}

/******************************************
	COMPUTE/SERVER GROUPS
 *****************************************/
# TODO: To Implement
