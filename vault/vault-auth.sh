#!/bin/bash

if [ -z $VAULT_ADDR ]; then
    echo "VAULT_ADDR is undefined."
    exit 1
fi

# Check if we have a valid global vault token
if vault token lookup -address=${VAULT_ADDR} &> /dev/null ; then
  echo "You already have a valid session for ${VAULT_ADDR}"
  exit 0
fi

# Not authenticated with vault

# Temporary output file
oidc_out=$(mktemp)
chmod 0600 ${oidc_out}
trap 'rm -f ${oidc_out}' EXIT INT TERM

# Local listening address
export VAULT_OIDC_ADDR="http://127.0.0.1:8250"
if timeout 1 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/8250' &> /dev/null ; then
  echo "Binding error: ${VAULT_OIDC_ADDR} already in use"
  exit 1
fi

# Start OIDC local handler
nohup vault login -method=oidc skip_browser=true > ${oidc_out} &

sleep 1

# Start OIDC client
path=$(realpath "${BASH_SOURCE:-$0}")
cwd=$(dirname $path)
python3 ${cwd}/vault-oidc-handler.py ${oidc_out}

# Print transaction
vault token lookup -address=${VAULT_ADDR}
