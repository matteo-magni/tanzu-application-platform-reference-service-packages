#!/usr/bin/env bash

set -euo pipefail

PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}

pushd $(dirname $0)/../

# install ASO and dependencies
# ./carvel-azure-install-aso.sh

# prepare values file for package
# VALUES_FILE=$(mktemp)
# trap "rm ${VALUES_FILE}" EXIT

NAME="$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | sha1sum | head -c 20)"
LOCATION="${LOCATION:-westeurope}"
PUBLIC_IP=$(curl -sSf https://api.ipify.org)

VALUES="$(cat <<EOF
---
name: ${NAME}
namespace: ${PACKAGE_NAMESPACE}
location: ${LOCATION}
aso_controller_namespace: azureserviceoperator-system
create_namespace: false

server:
  administrator_name: root

database:
  name: testdb

firewall_rules:
  - startIpAddress: ${PUBLIC_IP}
    endIpAddress: ${PUBLIC_IP}

resource_group:
  use_existing: false
  name: aso-psql-${NAME}
EOF
)"

# install package
# kubectl create namespace ${PACKAGE_NAMESPACE} || true
ytt -f config/carvel/package-install -v refName="${PACKAGE_METADATA_NAME}" -v namespace=${PACKAGE_NAMESPACE} -v version=${PACKAGE_VERSION} -v values="${VALUES}" | kubectl apply -f -

# create claim

# run test

# verify results

# clean up

popd
