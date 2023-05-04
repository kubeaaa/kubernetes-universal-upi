locals {
  # Butane disks mapping
  /*
  mst001.k8s.localdomain:
  - device: /dev/disk/by-id/virtio-499901b7-773b-4285-9
    partitions:
    - label: containers
      number: 1
      resize: true
    wipe_table: false
  - device: /dev/disk/by-id/virtio-fc7efc2d-cdb4-46ab-9
    partitions:
    - label: log
      number: 1
      resize: true
    wipe_table: false
  - device: /dev/disk/by-id/virtio-a4180674-a3c9-4544-8
    partitions:
    - label: root
      number: 1
      resize: true
    wipe_table: false
  mst002.k8s.localdomain: [...]
  */
  k8s_butane_disks_binding = {
    for instance in var.k8s_hosts : instance["host"] => concat([
      for volume in openstack_blockstorage_volume_v3.k8s_volumes: {
        device      = format("/dev/disk/by-id/virtio-%s", substr(volume["id"], 0, 20))
        wipe_table  = false
        partitions  = [{
          number: 1
          label: trimprefix(volume["name"], format("%s_", instance["name"]))
          resize: true
        }]
      }
      if lookup(volume.metadata, "instance_host") == instance["host"]
    ],
    # BOOT device
    [{
      # The link to the block device the OS was booted from.
      device      = "/dev/vda"
      # We do not want to wipe the partition table since this is the primary device.
      wipe_table  = false
      partitions  = [
        {
          number    = 4
          label     = "root"
          size_mib  = 0 # the partition will be made as large as possible.
          resize    = true
        }
      ]
    }])
  }

  # Butane filesystems mapping
  k8s_butane_filesystems_binding = {
    for instance in var.k8s_hosts : instance["host"] => [
      for volume in openstack_blockstorage_volume_v3.k8s_volumes: {
        path            = lookup(volume.metadata, "mountpoint")
        device          = format("/dev/disk/by-partlabel/%s", lookup(volume.metadata, "partlabel"))
        format          = "xfs"
        wipe_filesystem = false
        with_mount_unit = true
      }
      if lookup(volume.metadata, "instance_host") == instance["host"]
    ]
  }

  # Butane configuration by host
  k8s_butane_configs = {
    for instance in var.k8s_hosts : instance["host"] => templatefile
    (
      format("%s/butane/%s.tftpl", path.module, lookup(instance, "image_name")),
      {
        sources       = indent(6, yamlencode({merge: [
          for group in lookup(instance, "group_names"): {source: lookup(local.k8s_butane_additional_configs, group)}
          if contains(keys(local.k8s_butane_additional_configs), group)
        ]}))
        host          = element(split(".", lookup(instance, "host")), 0)
        dns           = var.k8s_dns_servers
        domains       = var.k8s_dns_domains
        ca_anchors    = { for ca,source in var.k8s_custom_ca_anchors: basename(source) => source }
        image_mirrors = { for registry in var.k8s_custom_registries: lookup(registry, "namespace") => registry }
        ntp_pool      = var.k8s_ntp_servers
        proxy         = var.k8s_proxy
        disks         = indent(4, yamlencode({disks = local.k8s_butane_disks_binding[lookup(instance, "host")]}))
        filesystems   = indent(4, yamlencode({filesystems = local.k8s_butane_filesystems_binding[lookup(instance, "host")]}))
      }
    )
  }

  # Ignition : optional third party sources on public remote repository
  # See (ignition/config/merge) : https://coreos.github.io/butane/config-fcos-v1_4/
  # See : https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-bucket-intro.html
  k8s_butane_additional_configs = {
    cp: format(
      "%s/%s/%s",
      var.k8s_nodes_ignition_s3_endpoint,
      aws_s3_object.k8s_controlplane_ignition_file[0].bucket,
      aws_s3_object.k8s_controlplane_ignition_file[0].key
    )
    compute: format(
      "%s/%s/%s",
      var.k8s_nodes_ignition_s3_endpoint,
      aws_s3_object.k8s_compute_ignition_file[0].bucket,
      aws_s3_object.k8s_compute_ignition_file[0].key
    )
  }

  # Ignition : optional third party sources on local fs
  k8s_nodes_ignition_files = {
    cp: var.k8s_controlplane_ignition_file
    compute: var.k8s_compute_ignition_file
  }
}

data "ct_config" "k8s_ignition_configs" {

  for_each     = local.k8s_butane_configs

  content      = each.value
  strict       = false
  pretty_print = false
}

resource "aws_s3_object" "k8s_controlplane_ignition_file" {

  count = lookup(local.k8s_nodes_ignition_files.cp, "path") != null ? 1 : 0

  key = format(
    "%s/%s/%s",
    "ignition",
    var.k8s_tenant,
    basename(lookup(local.k8s_nodes_ignition_files.cp, "path"))
  )
  bucket = var.k8s_nodes_ignition_s3_bucket

  acl = "public-read"

  source = lookup(local.k8s_nodes_ignition_files.cp, "path")
  etag = filemd5(lookup(local.k8s_nodes_ignition_files.cp, "path"))
}

resource "aws_s3_object" "k8s_compute_ignition_file" {

  count = lookup(local.k8s_nodes_ignition_files.compute, "path") != null ? 1 : 0

  key = format(
    "%s/%s/%s",
    "ignition",
    var.k8s_tenant,
    basename(lookup(local.k8s_nodes_ignition_files.compute, "path"))
  )
  bucket = var.k8s_nodes_ignition_s3_bucket

  acl = "public-read"

  source = lookup(local.k8s_nodes_ignition_files.compute, "path")
  etag = filemd5(lookup(local.k8s_nodes_ignition_files.compute, "path"))
}
