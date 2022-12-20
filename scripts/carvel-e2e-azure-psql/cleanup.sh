#!/usr/bin/env bash

set -euo pipefail

pushd $(dirname $0)

export PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
APP_NAME=${APP_NAME:-${NAME}}
TIMEOUT="15m"
CHECK_INTERVAL="5s"

kubectl -n ${APP_NAMESPACE} delete deployments.apps ${APP_NAME} || true

SA=${PACKAGE_METADATA_NAME}
INSTALL_NAME=${PACKAGE_METADATA_NAME}

echo ">> Uninstall package"
kctrl package installed delete -n ${PACKAGE_NAMESPACE} -i ${INSTALL_NAME} --wait-timeout ${TIMEOUT} --wait-check-interval ${CHECK_INTERVAL} -y

echo ">> Remove RBAC"
ytt -f ./rbac.ytt.yml -v serviceAccount=${SA} -v namespace=${PACKAGE_NAMESPACE} | kubectl delete -f -

popd
