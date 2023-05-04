locals {
  # Openshift file on S3
  os_bootstrap_ignition_s3_key = format("%s/%s/%s", "ignition", var.os_tenant, basename(var.os_bootstrap_ignition_file))
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-bucket-intro.html
  os_bootstrap_ignition_public_url = format(
    "%s/%s/%s",
    var.os_bootstrap_ignition_s3_endpoint,
    aws_s3_object.bootstrap_ignition.bucket,
    aws_s3_object.bootstrap_ignition.key
  )

  # Butane configuration for bootstrap node
  os_butane_config = templatefile(
      format("%s/butane/%s.tftpl", path.module, "bootstrap"),
      {
        bootstrap_ignition_public_url = local.os_bootstrap_ignition_public_url
        host                          = element(split(".", lookup(var.os_bootstrap_node, "host")), 0)
        dns                           = var.os_dns_servers
        domains                       = var.os_dns_domains
        ca_anchors                    = { for ca,source in var.os_custom_ca_anchors: basename(source) => source }
        image_mirrors                 = { for registry in var.os_custom_registries: lookup(registry, "namespace") => registry }
        ntp_pool                      = var.os_ntp_servers
      }
    )
}

data "ct_config" "os_ignition_config" {

  content      = local.os_butane_config
  strict       = false
  pretty_print = false
}

resource "aws_s3_object" "bootstrap_ignition" {

  bucket = var.os_bootstrap_ignition_s3_bucket
  key    = local.os_bootstrap_ignition_s3_key

  acl = "public-read"

  source = var.os_bootstrap_ignition_file
  etag = filemd5(var.os_bootstrap_ignition_file)
}
