locals {
  # Volumes structure
  /*
  volumes = [
    {
      "instance_name" = "mst001"
      "name" = "mst001"
      "size" = 200
    },
    ...
  ]
  */
  volumes = flatten([
    for instance in var.k8s_hosts: [
      for volume in lookup(instance, "storage"):
        {
          # <host>_<volume_name>
          name = format("%s_%s", lookup(instance, "name"), lookup(volume, "name"))
          # used by Ignition for device mapping.
          mountpoint = lookup(volume, "mountpoint")
          partlabel =  lookup(volume, "name")
          size = lookup(volume, "size")
          # fqdn
          instance_name = lookup(instance, "host")
        }
    ]
  ])
}

/*
trainingk8s-wrk005_log:
  attachment:
  - device: /dev/vde
    id: 71042cee-219f-413f-bd2b-9c39650045ec
    instance_id: 8cd19e8b-5977-4c40-a1c1-e5721402827e
  availability_zone: nova
  enable_online_resize: true
  id: 71042cee-219f-413f-bd2b-9c39650045ec
  name: trainingk8s-wrk005_log
  region: CNP-HP-PFS
  volume_type: hitachi
trainingk8s-wrk005_root:
  attachment:
  - device: /dev/vdd
    id: d075c02c-3db3-4ab9-bee7-e7e64c83e163
    instance_id: 8cd19e8b-5977-4c40-a1c1-e5721402827e
  availability_zone: nova
  enable_online_resize: true
  id: d075c02c-3db3-4ab9-bee7-e7e64c83e163
  name: trainingk8s-wrk005_root
  region: CNP-HP-PFS
  volume_type: hitachi
*/
resource "openstack_blockstorage_volume_v3" "k8s_volumes" {

  for_each = {
    for volume in local.volumes: lookup(volume, "name") => volume
  }

  name                  = each.value["name"]
  size                  = each.value["size"]
  enable_online_resize  = true

  metadata = {
    instance_host = each.value["instance_name"]
    mountpoint    = each.value["mountpoint"]
    partlabel     = each.value["partlabel"]
  }
}

/*
trainingk8s-mst001_containers:
  device: /dev/vdd
  id: 93273870-d0bc-4f8c-b678-ec50cae9ce0f/499901b7-773b-4285-93ee-8f5b4649ad86
  instance_id: 93273870-d0bc-4f8c-b678-ec50cae9ce0f
  multiattach: null
  region: CNP-HP-PFS
  timeouts: null
  vendor_options: []
  volume_id: 499901b7-773b-4285-93ee-8f5b4649ad86
trainingk8s-mst001_log:
  device: /dev/vdb
  id: 93273870-d0bc-4f8c-b678-ec50cae9ce0f/fc7efc2d-cdb4-46ab-9525-c700ed1166a8
  instance_id: 93273870-d0bc-4f8c-b678-ec50cae9ce0f
  multiattach: null
  region: CNP-HP-PFS
  timeouts: null
  vendor_options: []
  volume_id: fc7efc2d-cdb4-46ab-9525-c700ed1166a8
*/
resource "openstack_compute_volume_attach_v2" "k8s_volumes_attachments" {

  depends_on = [
    openstack_compute_instance_v2.k8s_compute_instances,
    openstack_blockstorage_volume_v3.k8s_volumes
  ]

  for_each = {
    for volume in local.volumes: lookup(volume, "name") => volume
  }

  instance_id = lookup(openstack_compute_instance_v2.k8s_compute_instances, each.value["instance_name"]).id
  volume_id   = lookup(openstack_blockstorage_volume_v3.k8s_volumes, each.value["name"]).id
}
