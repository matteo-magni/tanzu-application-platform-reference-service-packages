#!/usr/bin/env bash

set -euo pipefail

TIMEOUT=${TIMEOUT:-5m}
MAX_RESTARTS=3

PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
PACKAGE_CLASS="azure-postgres"
APP_NAME=${APP_NAME:-spring-boot-postgres}

pushd $(dirname $0)

# install ASO and dependencies
./carvel-azure-install-aso.sh

# install package
NAME="${NAME:-$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | sha1sum | head -c 20)}"
LOCATION="${LOCATION:-westeurope}"
PUBLIC_IP="$(curl -sSf https://api.ipify.org)"

VALUES="$(cat <<EOF
---
name: ${NAME}
namespace: ${PACKAGE_NAMESPACE}
location: ${LOCATION}
aso_controller_namespace: azureserviceoperator-system
create_namespace: false

server:
  administrator_name: testadmin

database:
  name: testdb

firewall_rules:
  - startIpAddress: 0.0.0.0
    endIpAddress: 0.0.0.0
  - startIpAddress: ${PUBLIC_IP}
    endIpAddress: ${PUBLIC_IP}

resource_group:
  use_existing: false
  name: aso-psql-${NAME}
EOF
)"

# install package
kubectl create namespace ${PACKAGE_NAMESPACE} || true

ytt -f ../config/carvel/package-install -v refName="${PACKAGE_METADATA_NAME}" -v namespace=${PACKAGE_NAMESPACE} -v version=${PACKAGE_VERSION} -v values="${VALUES}" | kubectl apply -f -

ecvho "Waiting for stack ${NAME} to reconcile"

RESTARTS_COUNT=0
while [ $RESTARTS_COUNT -lt $MAX_RESTARTS ]; do
  kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout=${TIMEOUT} packageinstalls.packaging.carvel.dev ${PACKAGE_METADATA_NAME} && AGAIN=0 || AGAIN=1
  if [ $AGAIN -eq 0 ]; then
    RESTARTS_COUNT=$MAX_RESTARTS
  else
    let RESTARTS_COUNT=$RESTARTS_COUNT+1
    kubectl -n azureserviceoperator-system rollout restart deployments.apps azureserviceoperator-controller-manager
  fi
done

# run test
SECRET_NAME="${NAME}-bindable"
./carvel-e2e-azure-psql/test.sh ${SECRET_NAME} ${APP_NAME}

popd
