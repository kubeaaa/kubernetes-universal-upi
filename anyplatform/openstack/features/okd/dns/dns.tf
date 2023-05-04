resource "openstack_dns_recordset_v2" "os_zones_api-int_record" {

  zone_id     = var.os_dns_zone.id
  name        = format("%s.%s", "api-int", var.os_dns_zone.name)
  ttl         = 300
  type        = "CNAME"
  records     = [ format("%s.%s", "api", var.os_dns_zone.name) ]
}
