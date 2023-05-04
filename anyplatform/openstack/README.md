# OPK module for Terraform

> Deploy Openstack Resources for K8S.

# Table of contents

[[_TOC_]]

## Description

This module handles :
* Openstack provider configuration
* Unmarshalling of Ansible variables/structures
* Toggle features on demand

## Prototypes

### Butane install ansible

```yaml
systemd:
  units:
    # Installing ansible as a layered package with rpm-ostree
    - name: rpm-ostree-install-ansible.service
      enabled: true
      contents: |
        [Unit]
        Description=Layer ansible with rpm-ostree
        Wants=network-online.target
        After=network-online.target
        # We run before `zincati.service` to avoid conflicting rpm-ostree
        # transactions.
        Before=zincati.service
        ConditionPathExists=!/var/lib/%N.stamp
        # `StartLimitIntervalSec=` to configure the checking interval and
        # `StartLimitBurst=` to configure how many starts per interval are allowed.
        StartLimitIntervalSec=60
        StartLimitBurst=5

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        Restart=on-failure
        RestartSec=10s
        # `--allow-inactive` ensures that rpm-ostree does not return an error
        # if the package is already installed. This is useful if the package is
        # added to the root image in a future Fedora CoreOS release as it will
        # prevent the service from failing.
        ExecStart=/usr/bin/rpm-ostree install --apply-live --allow-inactive ansible-core
        ExecStart=/bin/touch /var/lib/%N.stamp

        [Install]
        WantedBy=multi-user.target
```

### PTR Records

```hcl
locals {
  # DNS PTR recordset structure
  /*
  105.208.206.10.in-addr.arpa.:
  - wrk003.k8s.localdomain.
  123.210.206.10.in-addr.arpa.:
  - wrk005.k8s.localdomain.
  ...
  */
  dns_ptr_recordset = transpose({
    for host in var.k8s_hosts:
      format("%s.", lookup(host, "host")) => [
        for ifattach in openstack_compute_interface_attach_v2.k8s_ports_binding:
        join(".",
          reverse(split(".", ifattach["fixed_ip"])),
          ["in-addr.arpa."]
        )
        if ifattach["instance_id"] == lookup(openstack_compute_instance_v2.k8s_compute_instances, lookup(host, "host")).id
      ]
  })
}

# Reverse Zones
data "openstack_dns_zone_v2" "k8s_reverse_zone" {
  name = var.k8s_reverse_dns_zone
}

resource "openstack_dns_recordset_v2" "k8s_nodes_ptr_recordset" {

  for_each = local.dns_ptr_recordset

  zone_id     = data.openstack_dns_zone_v2.k8s_reverse_zone.id
  name        = each.key
  ttl         = 300
  type        = "PTR"
  records     = each.value
}

output "k8s_nodes_ptr_recordset" {
  value = openstack_dns_recordset_v2.k8s_nodes_ptr_recordset
  description = "Provisioned DNS/PTR Records on Openstack."
}
```

### terraform-provider-ct

* [terraform-provider-ct/examples](https://github.com/poseidon/terraform-provider-ct/tree/main/examples)
* [providers/poseidon/ct](https://registry.terraform.io/providers/poseidon/ct/latest/docs)

`fedora-coreos.tf`
```hcl
# Butane Config for Fedora CoreOS
data "ct_config" "fedora-coreos-config" {
  content = templatefile("${path.module}/content/fcos.yaml", {
    message = "Hello World!"
  })
  strict       = true
  pretty_print = true

  snippets = [
    file("${path.module}/content/fcos-snippet.yaml"),
  ]
}

# Render as Ignition
resource "local_file" "fedora-coreos" {
  content  = data.ct_config.fedora-coreos-config.rendered
  filename = "${path.module}/output/fedora-coreos.ign"
}
```

`fcos.yaml`
````yaml
---
variant: fcos
version: 1.4.0
storage:
  filesystems:
    - path: /
      device: /dev/disk/by-label/ROOT
      format: ext4
  files:
    - path: /etc/motd
      mode: 0644
      contents:
        inline: |
          ${message}
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - ssh-key foo
````