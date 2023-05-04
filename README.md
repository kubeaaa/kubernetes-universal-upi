# Universal K8S Deployment

> Deploy Kubernetes clusters by distribution on any platform.

> SPDX-License-Identifier: Apache-2.0

# Authors

* [AUTHORS.MD](AUTHORS.MD)

# Requirements

## Tooling

* GNU/Make 4.3+
* wget
* Ansible 6.5+
* Terraform 1.3.4+
* Vault CLI 1.10.2+
* Python 3.9+

# Abstract

This repository enable deploying `Openshift` clusters (either `OKD` or `OCP`) with the combination of both `Ansible` and `Terraform`.
The goal is to have the simplicity of the `IPI` installer, with the customization of the `UPI` mode.

Another aspect is to keep a fine grain control over the deployment process.

# Usage

Pull the latest git submodules and Python requirements (for Ansible)

```bash
make submodules .requirements
```

## Cluster configuration

Create a new `inventory` in `blueprints` directory with the `tenant` as name (ex : `trainingk8s`).

## Openshift : determine recommended OS stream by platform

```bash
openshift-install coreos print-stream-json | jq '.architectures.x86_64.artifacts.openstack'
```

## Proxy configuration

Edit `blueprints/<tenant>/group_vars/all.yaml` with a suitable `no_proxy` value.

> For Openshift deployments, the field must include the values of the `networking.machineNetwork[].cidr`,
> `networking.clusterNetwork[].cidr` and `networking.serviceNetwork[]`

## Cluster deployment

In order to deploy a `Cluster`, use the associate `make` goal as follows :

```bash
make $K8S_CONTEXT  # Where $K8S_CONTEXT is a cluster name
```

*Example :*

```bash
make training
```

> Note : For Openshift based deployments,
> you are required to run the deployment twice in order to destroy the temporary `boostrap` node.

*Check mode / dry-run :*
```
K8S_CLUSTER_NAME="training" make check
```

*Destroy mode / purge :*
```
K8S_CLUSTER_NAME="training" make purge
```

*Enable Debugging :*
```
# https://docs.ansible.com/ansible/latest/reference_appendices/config.html#default-verbosity
# https://docs.ansible.com/ansible/latest/reference_appendices/config.html#enable-task-debugger
# https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html
# https://www.terraform.io/internals/debugging
ANSIBLE_VERBOSITY=3 TF_LOG=DEBUG make training
```

### Fine-grain deployment examples 

*Run post-install only, without CSR approuval loop :*
```
./vault/vault-auth.sh
time ansible-playbook -i blueprints/${K8S_CLUSTER_NAME}k8s/ k8s.yaml -t post-dist-k8s --skip-tags "approve-csr"
```

## Cluster interactions

### Openshift

```bash
source kube.sh
kubectl get node
```

# Ansible

The topics assume basic knowledge of how Ansible playbooks work. If you want to learn more about Ansible playbooks, see these resources:

* [Learning Ansible basics - Red Hat](https://www.redhat.com/en/topics/automation/learning-ansible-tutorial)
* [How to Build Ansible Inventory](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)
* [github.com/confluentinc/cp-ansible](https://github.com/confluentinc/cp-ansible/tree/master)
* [Sample Ansible setup](https://docs.ansible.com/ansible/latest/user_guide/sample_setup.html)

# CoreOS/Butane

> Butane (formerly the Fedora CoreOS Config Transpiler) is a tool that consumes a Butane Config and produces an
> Ignition Config, which is a JSON document that can be given to a Fedora CoreOS machine when it first boots.

## rpm-ostree

* [Adding OS extensions to the host system](https://docs.fedoraproject.org/en-US/fedora-coreos/os-extensions/)
* [Adding Layered Packages](https://docs.fedoraproject.org/en-US/iot/add-layered/)

# Security

## SSH

Generate a new SSH key pair : 
* [Generating an ecdsa key pair](https://access.redhat.com/documentation/en-us/red_hat_update_infrastructure/4/html/installing_red_hat_update_infrastructure/assembly_generating-a-cryptographic-key-pair_installing-red-hat-update-infrastructure#proc_generating-an-ecdsa-key-pair_assembly_generating-a-cryptographic-key-pair)

The Openstack tenant credentials registered in vault must have the following fields:
* `id_ecdsa` i.e. Private key
* `id_ecdsa.pub` i.e. Public key

## CoreOS Autologin

* The `coreos.autologin` kernel command-line parameter is not currently supported in FCOS.

The snippet below will not work because `core` has a built-in password. Use SSH instead, ore refer to [Access Recovery](https://github.com/coreos/fedora-coreos-docs/blob/main/modules/ROOT/pages/access-recovery.adoc)

```yaml
systemd:
  units:
    - name: getty@tty1.service
      dropins:
        - name: autologin.conf
          contents: |
            [Service]
            TTYVTDisallocate=no
            ExecStart=
            ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear --autologin core - $TERM
```

## Security Groups Matrix

* [okd/Network connectivity requirements](https://docs.okd.io/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-network-connectivity-user-infra_installing-platform-agnostic)

# Network

## DNS

### A

You must provide both an `authoritative zone` (for `A` records).

### PTRs

* [opk/How To Manage PTR Records](https://docs.openstack.org/designate/latest/user/manage-ptr-records.html)
* [RFC 2317](https://tools.ietf.org/html/rfc2317) 

```hcl
# RF2317 variable
variable "os_reverse_dns_zone" {
  type = string
  description = "Reverse DNS Zone of the Openshift nodes."

  # regexr.com/73cai
  # https://www.ietf.org/rfc/rfc2317.txt
  validation {
    condition     = can(regex("(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.in-addr\\.arpa\\.", var.os_reverse_dns_zone))
    error_message = "DNS Zone is not RFC 2317 compliant."
  }
}
```

### About systemd-resolve

`systemd-resolve` is configured without stub listener, statically.

* [archlinux/Setting DNS servers](https://wiki.archlinux.org/title/systemd-resolved#Setting_DNS_servers)
* [Prevent NetworkManager from adding dns-servers to /etc/resolv.conf file](https://access.redhat.com/solutions/3490661)

See `/etc/nsswitch.conf` and `/etc/systemd/resolved.conf`:

* [nss-resolve, libnss_resolve.so.2 — Hostname resolution via systemd-resolved.service](https://www.freedesktop.org/software/systemd/man/nss-resolve.html)
* [authselect(8)](https://www.mankier.com/8/authselect)

* [/etc/systemd/resolved.conf](https://www.freedesktop.org/software/systemd/man/resolved.conf.html)
* [systemd-resolved.service, systemd-resolved — Network Name Resolution manager](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html)

* See [hostname(1)](https://www.mankier.com/1/hostname)
* See [hosts(5)](https://www.mankier.com/5/hosts)

Openshift deployments do not support `systemd-resolved stub mode`, see :
* [Manual DNS Configuration and FCOS DNS Fix](https://github.com/okd-project/okd/blob/master/Guides/UPI/baremetal/manual-dns-and-fcos-dns-fix.md)

### Troubleshooting

```bash
resolvectl status
systemd-resolve --status
nslookup <fqdn|ipv4>

# List PTR record for specific zone
dig 251.210.206.10.in-addr.arpa PTR

# Perform a reverse DNS lookup on an IP address (PTR record):
dig @<dns> -x <ip> +short  # dig @localhost -x <ip> +short
```

## NTP

* TODO: provide NTP from DHCP.

* [fcos/TZ](https://docs.fedoraproject.org/en-US/fedora-coreos/time-zone/)
* [ocp/Configuring chrony time service](https://docs.openshift.com/container-platform/latest/installing/install_config/installing-customizing.html#installation-special-config-chrony_installing-customizing)

Sample output :
```bash
[core@wrk001 ~]$ timedatectl
               Local time: Wed 2022-11-23 15:48:08 CET
           Universal time: Wed 2022-11-23 14:48:08 UTC
                 RTC time: Wed 2022-11-23 14:48:08
                Time zone: Europe/Paris (CET, +0100)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

### Troubleshooting

```bash
timedatectl
systemctl status chronyd
sudo chronyc tracking
sudo chronyc sources -v
sudo chronyc sourcestats
sudo chronyc activity
```

## Proxy

* [fcos/proxy](https://docs.fedoraproject.org/en-US/fedora-coreos/proxy/)

> Zincati polls for OS updates, and rpm-ostree is used to apply OS and layered package updates both therefore
> requiring internet access. The optional anonymized countme service also requires access if enabled.

`containerd` and `podman` are not proxied.

## Compute configuration

* [systemd.network — Network configuration](https://www.freedesktop.org/software/systemd/man/systemd.network.html)

## Requirements

* [kubernetes / ports-and-protocols](https://kubernetes.io/docs/reference/ports-and-protocols/)

## Misc

Network computation :

```bash
ipcalc -S 23 10.206.24.0/21
```

Troubleshooting using `netcat` :

```bash
nc -vz <host> <port> # TCP
nc -vzu <host> <port> # UDP
```

With `ansible` :

```bash
ansible -i <inventory> all -m ping -v
```

# Storage

> Openstack does not guarantee the /dev/v{XX} mounting path of the provisioned volumes.

FCOS documentation :

* [fcos/Configuring Storage](https://docs.fedoraproject.org/en-US/fedora-coreos/storage/)
* [fcos/_disk_layout](https://docs.fedoraproject.org/en-US/fedora-coreos/storage/#_disk_layout)

## Troubleshooting

```bash
# Block devices
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS,PARTLABEL
# Device info
udevadm info --query=all --name="/dev/vda"
```

# Kernel Tuning

* [fcos/sysctl](https://docs.fedoraproject.org/en-US/fedora-coreos/sysctl/)

# containerd

* [containerd/containerd/getting-started.md](https://github.com/containerd/containerd/blob/main/docs/getting-started.md)
* [containerd/cri/config.md](https://github.com/containerd/containerd/blob/main/docs/cri/config.md)

> Note that the [plugins."io.containerd.grpc.v1.cri"] section is specific to CRI, and not recognized by other containerd clients such as ctr, nerdctl, and Docker/Moby.

# Podman

```
podman run --rm quay.io/podman/hello
```

# Openshift

* [Installing a cluster on any platform](https://docs.openshift.com/container-platform/4.11/installing/installing_platform_agnostic/installing-platform-agnostic.html)

## Console

Get `kubeconfig` context :

```bash
export KUBECONFIG=installer/auth/kubeconfig
oc whoami --show-console
```

## Bootstrap process

```bash
ssh core@bootstrap
journalctl -b -f -u release-image.service -u bootkube.service
```

## Cluster status

Verifying cluster status on Openstack : [status_installing-openstack-installer-custom](https://docs.okd.io/latest/installing/installing_openstack/installing-openstack-installer-custom.html#installation-osp-verifying-cluster-status_installing-openstack-installer-custom)

```bash
oc get csr
oc get nodes
oc get clusterversion
oc get clusteroperator
oc get pods -A
```

## ClusterOperator / machine-config

```bash
oc get co machine-config -o yaml
```

## Cluster capabilities

> Cluster administrators can use cluster capabilities to enable or disable optional components prior to installation.

* [OKD/Cluster capabilities](https://docs.okd.io/latest/installing/cluster-capabilities.html#explanation_of_capabilities_cluster-capabilities)
* [OKD/Enabling cluster capabilities](https://docs.okd.io/latest/post_installation_configuration/enabling-cluster-capabilities.html)

## Adding hosts

* [Adding compute machines to bare metal](https://docs.openshift.com/container-platform/4.11/machine_management/user_infra/adding-bare-metal-compute-user-infra.html#adding-bare-metal-compute-user-infra)

## Troubleshooting

* [Issues with etcdctl starting on bootstrap node](https://github.com/openshift/installer/issues/5858)
* [error creating container storage: the container name "etcdctl" is already in use on bootstrap](https://github.com/okd-project/okd/issues/1260)
* [machine-config operator does not initialize](https://github.com/okd-project/okd/issues/963)

### Read the logs !

```bash
journalctl --since "1 hour ago"
```

# Container Network Interface

## Cilium

### Commands reference

* [cilium-agent.md](https://github.com/cilium/cilium/blob/master/Documentation/cmdref/cilium-agent.md)

### Openshift

* [cilium/Installation on OpenShift OKD](https://docs.cilium.io/en/v1.12/gettingstarted/k8s-install-openshift-okd/)
* [isovalent@rh/Cilium](https://catalog.redhat.com/software/operators/detail/60423ec2c00b1279ffe35a68#deploy-instructions)
* [OpenShift UPI Terraform module for Cilium](https://github.com/cilium/openshift-terraform-upi)
* [conf/cilium-conf-commands.sh](https://github.com/openshift/release/blob/master/ci-operator/step-registry/cilium/conf/cilium-conf-commands.sh)
* [cilium-olm/ClusterServiceVersion manifest](https://github.com/cilium/cilium-olm/issues/45)

### kubeproxy-free

* [kubeproxy-free](https://docs.cilium.io/en/stable/gettingstarted/kubeproxy-free/)
* [cluster-network-operator#configuring-kube-proxy](https://github.com/openshift/cluster-network-operator#configuring-kube-proxy)
* [network-operator-openshift-io-v1](https://docs.openshift.com/container-platform/4.11/rest_api/operator_apis/network-operator-openshift-io-v1.html)

### Connectivity test

* [Deploy the connectivity test](https://docs.cilium.io/en/v1.12/gettingstarted/k8s-install-openshift-okd/#deploy-the-connectivity-test)

### Check status

```
kubectl exec -i $(oc get pod -n cilium | grep -v -E '(operator|olm)' | grep Running | head -n 1) -c cilium-agent -n cilium -- cilium status --verbose
```

#### Host Routing is Legacy

`Cilium` with Openshift is using Legacy host routing because of the `endpointRoutes` requirement.

```
level=info msg="BPF host routing is currently not supported with enable-endpoint-routes. Falling back to legacy host routing (enable-host-legacy-routing=true)." subsys=daemon
```

See : [Cilium runnning in Legacy mode instead of BPF](https://github.com/cilium/cilium/issues/18120)

### Bootstrap node debug

```
journalctl -b -f -u release-image.service -u bootkube.service

sudo -s
export KUBECONFIG=/opt/openshift/auth/kubeconfig
/usr/bin/oc get pods -A
```

# Misc

## Vault CLI

Fetch a field in `secret` "KV" store.
```
$ vault kv get -mount=secret -field=password openstack/horsprod/tenant/act-devel01k8s
```

# References

* [Fedora CoreOS Documentation](https://docs.fedoraproject.org/en-US/fedora-coreos/)
* [coreos/butane](https://coreos.github.io/butane/getting-started/)
* [Migrating from CoreOS Container Linux (CL) to Fedora CoreOS (FCOS)](https://github.com/coreos/fedora-coreos-docs/blob/main/modules/ROOT/pages/migrate-cl.adoc)
* [OCP/Node Tuning Operator](https://github.com/openshift/cluster-node-tuning-operator)
* [Mattias Geniar - Auto-restart a crashed service in systemd](https://ma.ttias.be/auto-restart-crashed-service-systemd/)
* [How do I disable or enable the IPv6 protocol in Red Hat Enterprise Linux?](https://access.redhat.com/solutions/8709)
* [okd/Troubleshooting the installer workflow](https://docs.okd.io/latest/installing/installing_bare_metal_ipi/ipi-install-troubleshooting.html#troubleshooting-the-installer-workflow)
* [opk/Basic Load Balancing Cookbook](https://docs.openstack.org/octavia/queens/user/guides/basic-cookbook.html)
* [okd4-terraform-openstack/modules/compute/main.tf](https://github.com/okd-project/okd/blob/master/Guides/UPI/okd4-terraform-openstack/modules/compute/main.tf)
* [okd4-terraform-openstack/scripts/deploy.sh](https://github.com/okd-project/okd/blob/master/Guides/UPI/okd4-terraform-openstack/scripts/deploy.sh)
* [How to manage Linux container registries](https://www.redhat.com/sysadmin/manage-container-registries)
* [containers/containers-registries.conf.5.md](https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md)
* [Creating a mirror registry with mirror registry for Red Hat OpenShift](https://docs.okd.io/latest/installing/disconnected_install/installing-mirroring-creating-registry.html)
* [openshift/customization](https://github.com/openshift/installer/blob/master/docs/user/customization.md)
* [openshift/Post-installation machine configuration tasks](https://docs.openshift.com/container-platform/4.11/post_installation_configuration/machine-configuration-tasks.html)
* [Installing OpenShift on OpenStack User-Provisioned Infrastructure](https://github.com/openshift/installer/blob/master/docs/user/openstack/install_upi.md)
* [Monitor Node Health](https://kubernetes.io/docs/tasks/debug/debug-cluster/monitor-node-health/)
* [OCP/Deploying installer-provisioned clusters on bare metal](https://docs.openshift.com/container-platform/4.11/installing/installing_bare_metal_ipi/ipi-install-installation-workflow.html)
