# TODO

## General

* Create PTR with delegated zone
* Use FloatingIPs for Openstack-based deployments
* Add self diagnostic playbook based on https://docs.okd.io/latest/installing/installing_bare_metal_ipi/ipi-install-troubleshooting.html#troubleshooting-the-installer-workflow
* Add identity provider to post-install
* Add alertmanager configuration to post-install
* Remove redundancy in variables files of terraform modules (explore terragrunt ?)
* Use vault for S3 ignition files
* Add/Remove nodes from openshift using oc tool before terraform destroy
* Add/Remove [master] nodes from etcd gracefully before terraform destroy (see: https://bugzilla.redhat.com/show_bug.cgi?id=2003775#c1, https://docs.openshift.com/container-platform/4.11/backup_and_restore/control_plane_backup_and_restore/replacing-unhealthy-etcd-member.html)

## Terraform

### sleep for access_ip_v4

* implement wait_loop for "compute/.access_ip_v4"
* https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
```
    Error: Error creating members: Missing input for argument [Address]

      with module.k8s.openstack_lb_members_v2.k8s_loadbalancers_members["trainingk8s-controlplane-machineconfig"],
      on k8s/network.tf line 295, in resource "openstack_lb_members_v2" "k8s_loadbalancers_members":
     295: resource "openstack_lb_members_v2" "k8s_loadbalancers_members" {
```

# Checklist
* Q/A with official methods
```
https://docs.okd.io/latest/installing/installing_platform_agnostic/installing-platform-agnostic.html#installation-load-balancing-user-infra_installing-platform-agnostic
https://docs.okd.io/latest/installing/installing_openstack/installing-openstack-installer-custom.html#installation-osp-verifying-cluster-status_installing-openstack-installer-custom
https://github.com/openshift/installer/blob/master/docs/user/openstack/install_upi.md
https://github.com/openshift/installer/tree/master/docs/user/openstack
```

# Known Issues
* bootstrap node failed : `Error: name "etcdctl" is in use: container already exists` (https://github.com/okd-project/okd/issues/1260)
