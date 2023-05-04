#!/usr/bin/make -sf

export BASH_ENV := environment
SHELL := /bin/bash
.SHELLFLAGS = -ec

# ONESHELL special target appears anywhere in the makefile then
# all recipe lines for each target will be provided to a single invocation of the shell.
.ONESHELL:

# A phony target is one that is not really the name of a file;
# rather it is just a name for a recipe to be executed when you make an explicit request
.PHONY: clean

# Sets the default goal to be used if no targets were specified on the command line
.DEFAULT_GOAL := .terraform.lock.hcl

# Terraform init target
.terraform.lock.hcl:
	echo $${TF_DATA_DIR}
	terraform init

# Clean artifacts
clean:
	exit 0
