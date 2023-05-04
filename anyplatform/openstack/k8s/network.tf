locals {
  # Networks
  /*
  networks = tomap({
    "CNP-HP-OCP-BACK" = {
      "description" = "K8S Backend Network"
      "tags" = tolist([
        "back",
      ])
    }
    ...
  })
  */
  networks = var.k8s_network_networks

  # Subnets
  /*
  subnets = [
    {
      "ip_version" = 4
      "name" = "CNP-HP-OCP-BACK-SUBNET"
      "network_name" = "CNP-HP-OCP-BACK"
    },
    ...
  ]
  */
  subnets = flatten([
    for network, subnets in var.k8s_network_subnets_binding: [
      for subnet in subnets:
        merge({network_name = network}, subnet)
    ]
  ])

  # Secgroups
  secgroups = var.k8s_network_secgroups_rulesets

  # Secgroup rules
  rules = flatten([
    for secgroup, rules in var.k8s_network_secgroups_rulesets: [
      for rule in rules:
        merge({secgroup_name = secgroup}, rule)
    ]
  ])

  # Network ports
  ports = flatten([
    for instance in var.k8s_hosts: [
      for network in lookup(instance, "networks"):
        {
          # <host>_<network_name>_IF
          name = format("%s_%s_IF", lookup(instance, "name"), network)
          # net
          network_name = network
          secgroups = lookup(instance, "security_groups")
          # compute
          instance_name = lookup(instance, "name")
          instance_host = lookup(instance, "host")
        }
    ]
  ])

  # Load Balancers
  lbs = {
    for lb in var.k8s_network_loadbalancers: format("%s-%s", terraform.workspace, lookup(lb, "name")) => lb
  }
  listeners = flatten([
    for lb_name,lb in local.lbs: [
      for listener in lookup(lb, "listeners"):
        {
          # used for pool binding
          name = format("%s-%s", terraform.workspace, lookup(listener, "name"))
          description = lookup(listener, "description")
          protocol = lookup(listener, "protocol")
          port = lookup(listener, "port")
          lb = lb_name
        }
    ]
  ])
  /*
  - lb: trainingk8s-apiserver
    listener: trainingk8s-apiserver
    members:
    - address: mst001.k8s.localdomain
      protocol_port: 6443
    - address: mst002.k8s.localdomain
      protocol_port: 6443
    - address: mst003.k8s.localdomain
      protocol_port: 6443
    monitor:
      delay: 30
      http_method: GET
      max_retries: 4
      max_retries_down: 3
      name: https-readyz
      timeout: 15
      type: HTTP
      url_path: /readyz
    name: trainingk8s-controlplane-apiserver-readyz
    protocol: HTTP
  ...
  */
  pools = flatten([
    for lb_name,lb in local.lbs: [
      for pool in lookup(lb, "pools"):
        {
          name = format("%s-%s", terraform.workspace, lookup(pool, "name"))
          protocol = lookup(pool, "protocol")

          # Collect all hosts that belong to the group
          members = flatten([
            for members in lookup(pool, "members"):
              [
                for host in lookup(var.k8s_hosts_groups, lookup(members, "group")):
                {
                  host = host
                  protocol_port = lookup(members, "protocol_port")
                }
              ]
              if contains(keys(var.k8s_hosts_groups), lookup(members, "group"))
          ])

          monitor = lookup(pool, "healthmonitor")

          lb = lb_name
          # linked with listener naming convention
          listener = format("%s-%s", terraform.workspace, lookup(pool, "listener"))
        }
    ]
  ])
  lb_members = flatten([
    for pool in local.pools: [
      for member in lookup(pool, "members"):
      {
        name          = format("%s-%s-%s", lookup(pool, "name"), lookup(member, "host"), lookup(member, "protocol_port"))
        pool_name     = lookup(pool, "name")
        host          = lookup(member, "host")
        protocol_port = lookup(member, "protocol_port")
      }
    ]
  ])
}

data "openstack_networking_network_v2" "k8s_networks" {

  for_each = local.networks

  name                      = each.key
}

data "openstack_networking_subnet_v2" "k8s_subnets" {

  for_each = {
    for subnet in local.subnets: lookup(subnet, "name") => subnet
  }

  name       = each.key
}

resource "openstack_networking_secgroup_v2" "k8s_secgroups" {

  for_each = local.secgroups

  name          = each.key
  delete_default_rules  = true
}

resource "openstack_networking_secgroup_rule_v2" "k8s_secgroups_rules" {

  count = length(local.rules)

  depends_on = [
    openstack_networking_secgroup_v2.k8s_secgroups
  ]

  description       = local.rules[count.index]["description"]
  direction         = local.rules[count.index]["direction"]
  ethertype         = local.rules[count.index]["ethertype"]
  protocol          = local.rules[count.index]["protocol"]
  port_range_min    = local.rules[count.index]["port_range_min"]
  port_range_max    = local.rules[count.index]["port_range_max"]
  remote_ip_prefix  = local.rules[count.index]["remote_ip_prefix"]
  security_group_id = openstack_networking_secgroup_v2.k8s_secgroups[local.rules[count.index]["secgroup_name"]].id
}

resource "openstack_networking_port_v2" "k8s_networking_ports" {

  depends_on = [
    data.openstack_networking_network_v2.k8s_networks,
    openstack_networking_secgroup_v2.k8s_secgroups
  ]

  for_each = {
    for port in local.ports: lookup(port, "name") => port
  }

  # secgroups binding
  security_group_ids = [
    for secgroup in each.value["secgroups"]: lookup(openstack_networking_secgroup_v2.k8s_secgroups, secgroup).id
  ]

  name              = each.key
  admin_state_up    = true
  dns_name          = each.value["instance_name"]
  network_id        = lookup(data.openstack_networking_network_v2.k8s_networks, each.value["network_name"]).id
}

/*
trainingk8s-mst001_PFS-OPK-MGT_IF:
  fixed_ip: 10.206.212.32
  id: 554b8edb-62e4-4185-931e-dbee8f1e7752/1640381f-bced-4fc6-a878-fb23ad38a337
  instance_id: 554b8edb-62e4-4185-931e-dbee8f1e7752
  network_id: 2ecd9005-897e-4bc1-b9d6-1912155b4647
  port_id: 1640381f-bced-4fc6-a878-fb23ad38a337
  region: CNP-HP-PFS
trainingk8s-mst002_PFS-OPK-MGT_IF:
  fixed_ip: 10.206.210.203
  id: 3ec4a6f3-4039-4250-a19b-d00386762be1/dc9b0cfc-a80d-4039-8dfe-8e2c537d616d
  instance_id: 3ec4a6f3-4039-4250-a19b-d00386762be1
  network_id: 2ecd9005-897e-4bc1-b9d6-1912155b4647
  port_id: dc9b0cfc-a80d-4039-8dfe-8e2c537d616d
  region: CNP-HP-PFS
*/
resource "openstack_compute_interface_attach_v2" "k8s_ports_binding" {

  depends_on = [
    openstack_compute_instance_v2.k8s_compute_instances,
    openstack_networking_port_v2.k8s_networking_ports
  ]

  for_each = {
    for port in local.ports: lookup(port, "name") => port
  }

  instance_id = lookup(openstack_compute_instance_v2.k8s_compute_instances, each.value["instance_host"]).id
  port_id     = lookup(openstack_networking_port_v2.k8s_networking_ports, each.key).id
}

/*
apiserver:
  admin_state_up: true
  availability_zone: ''
  description: Kubernetes API load balancer
  flavor_id: ''
  id: 8822477e-5a25-44f2-b9f0-538476ec92d8
  loadbalancer_provider: amphora
  name: trainingk8s-apiserver
  region: CNP-HP-PFS
  security_group_ids:
  - 7cc5f1eb-8c74-4549-bcb3-9f16bd61f507
  tags: null
  tenant_id: 92ef74fc30b147149ba5d9c4771eb33f
  timeouts: null
  vip_address: 10.206.208.227
  vip_network_id: 2ecd9005-897e-4bc1-b9d6-1912155b4647
  vip_port_id: 9d50a9e0-5bbc-4bfb-bd78-6f7f0bd4cb77
  vip_subnet_id: 5887e6e3-2eb5-4018-876c-111473e20a92
...
*/
resource "openstack_lb_loadbalancer_v2" "k8s_loadbalancers" {

  depends_on = [
    data.openstack_networking_subnet_v2.k8s_subnets
  ]

  for_each = local.lbs

  name          = each.key
  description   = each.value["description"]
  vip_subnet_id = lookup(data.openstack_networking_subnet_v2.k8s_subnets, each.value["subnet"]).id
}

resource "openstack_lb_listener_v2" "k8s_loadbalancers_listeners" {

  depends_on = [
    openstack_lb_loadbalancer_v2.k8s_loadbalancers
  ]

  for_each = {
    for listener in local.listeners: lookup(listener, "name") => listener
  }

  name            = each.key
  description     = each.value["description"]
  protocol        = each.value["protocol"]
  protocol_port   = each.value["port"]
  loadbalancer_id = lookup(openstack_lb_loadbalancer_v2.k8s_loadbalancers, each.value["lb"]).id
}

resource "openstack_lb_pool_v2" "k8s_loadbalancers_pools" {

  depends_on = [
    openstack_lb_listener_v2.k8s_loadbalancers_listeners
  ]

  for_each = {
    for pool in local.pools: lookup(pool, "name") => pool
  }

  name            = each.key
  protocol        = each.value["protocol"]
  lb_method       = "ROUND_ROBIN"

  listener_id = lookup(openstack_lb_listener_v2.k8s_loadbalancers_listeners, each.value["listener"]).id
}

resource "openstack_lb_member_v2" "k8s_loadbalancers_members" {

  depends_on = [
    openstack_lb_pool_v2.k8s_loadbalancers_pools,
    openstack_compute_interface_attach_v2.k8s_ports_binding
  ]

  for_each = {
    for member in local.lb_members: lookup(member, "name") => member
  }

  name          = each.value["name"]
  pool_id       = lookup(openstack_lb_pool_v2.k8s_loadbalancers_pools, each.value["pool_name"]).id
  # pick fist access ip from DNS
  address       = element(
    lookup(
      openstack_dns_recordset_v2.k8s_nodes_a_recordset,
      format("%s.", each.value["host"])
    ).records,
    0
  )
  protocol_port = each.value["protocol_port"]
}

resource "openstack_lb_monitor_v2" "k8s_loadbalancers_monitors" {

  depends_on = [
    openstack_lb_pool_v2.k8s_loadbalancers_pools
  ]

  for_each = {
    for pool in local.pools: lookup(pool, "name") => pool
  }

  pool_id = lookup(openstack_lb_pool_v2.k8s_loadbalancers_pools, each.key).id

  name              = each.value["monitor"]["name"]
  type              = each.value["monitor"]["type"]
  url_path          = try(each.value["monitor"]["url_path"], "")
  http_method       = try(each.value["monitor"]["http_method"], "")
  delay             = each.value["monitor"]["delay"]
  timeout           = each.value["monitor"]["timeout"]
  max_retries_down  = each.value["monitor"]["max_retries_down"]
  max_retries       = each.value["monitor"]["max_retries"]
}
