#!/usr/bin/python

class FilterModule(object):
    """
    For each host in hostvars, strip ansible attributes
    """

    def filters(self):
        return {
            'hostvars_to_tf': self.hostvars_to_tf
        }

    def hostvars_to_tf(self, hosts: dict) -> dict:
        blacklist = ('groups', 'omit', 'playbook_dir')
        stripped_hostvars = {}
        for host, hostvars in hosts.items():
            # copy object for alteration
            stripped = dict(hosts[host])
            # explore attributes
            for attr in hostvars.keys():
                if attr.startswith('ansible_') or attr.startswith('inventory_') or attr in blacklist:
                    # strip
                    stripped.pop(attr, None)
            stripped_hostvars[host] = stripped
        return stripped_hostvars
