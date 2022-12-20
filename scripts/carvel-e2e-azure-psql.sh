#!/usr/bin/env bash

set -euo pipefail

TIMEOUT=${TIMEOUT:-10m}
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

kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout=${TIMEOUT} packageinstalls.packaging.carvel.dev ${PACKAGE_METADATA_NAME}

if [ $? != 0 ]; then
  # try one more time to make sure the package installation did not fail because of ASO
  kubectl -n azureserviceoperator-system rollout restart deployments.apps azureserviceoperator-controller-manager
  kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout=${TIMEOUT} packageinstalls.packaging.carvel.dev ${PACKAGE_METADATA_NAME}
fi

# run test
SECRET_NAME="${NAME}-bindable"
./carvel-e2e-azure-psql/test.sh ${SECRET_NAME} ${APP_NAME}

popd
