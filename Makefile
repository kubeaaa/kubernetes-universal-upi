#!/usr/bin/make -sf

export BASH_ENV := environment
SHELL := /bin/bash
.SHELLFLAGS = -ec

# ONESHELL special target appears anywhere in the makefile then
# all recipe lines for each target will be provided to a single invocation of the shell.
.ONESHELL:

# A phony target is one that is not really the name of a file;
# rather it is just a name for a recipe to be executed when you make an explicit request
.PHONY: training submodules purge clean

# Sets the default goal to be used if no targets were specified on the command line
.DEFAULT_GOAL :=

# Git Submodule update
submodules:
	git pull
	git submodule update --init

# Ansible init
.requirements:
	pip install --upgrade pip
	pip install -r requirements.txt
	ansible-galaxy collection install -r ansible-requirements.yml
	@touch $@

# Environment deployment targets
training: .requirements
	# credentials resolution
	./vault/vault-auth.sh
	# K8S deployment
	time ansible-playbook -i blueprints/$@k8s/ k8s.yaml

# dry-run recipe
check: .requirements
	if [[ -z $${K8S_CLUSTER_NAME} ]]; then echo "K8S_CLUSTER_NAME is undefined." && exit 1; fi
	./vault/vault-auth.sh
	time ansible-playbook -i blueprints/$${K8S_CLUSTER_NAME}k8s/ k8s.yaml --check --diff

# destroy recipe
purge: .requirements
	if [[ -z $${K8S_CLUSTER_NAME} ]]; then echo "K8S_CLUSTER_NAME is undefined." && exit 1; fi
	./vault/vault-auth.sh
	time ansible-playbook -i blueprints/$${K8S_CLUSTER_NAME}k8s/ purge.yaml

# Clean artifacts
clean:
	rm -f .requirements
	rm -f .terraform.lock.hcl
	find . -type f -name "*.tfplan" -delete
	find anyplatform/ -type f -name ".terraform.lock.hcl" -delete
	rm -rf .terraform terraform.tfstate.d

# Clean installer manifests and configurations
clean-installer:
	rm -f .openshift_install.log
	rm -f .openshift_install_state.json
	find installer/ -type f -not -path 'installer/.gitkeep' -delete
	find installer/ -mindepth 1 -type d -delete

# Clean openshift binaries
clean-ocp-bin:
	rm -f ~/.local/bin/oc ~/.local/bin/openshift-install
